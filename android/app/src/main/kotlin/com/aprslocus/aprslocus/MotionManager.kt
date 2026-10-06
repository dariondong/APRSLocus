package com.aprslocus.aprslocus

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sqrt

/**
 * 运动传感器桥（加速度计 + 指南针），供「轨迹打点更准」使用。
 *
 * 负责三件事，每一件都对应一个真实的定位缺陷：
 *
 *  1. **指南针（航向）**：GPS 在低速/静止时给出的 course 是垃圾（多普勒解算不出
 *     方向会输出 0 或不更新）。步行、推车、慢速骑行时屏幕上的航向会乱指。
 *     这里用旋转矢量（TYPE_ROTATION_VECTOR）拿磁北航向；没有该传感器时退回
 *     「加速度计 + 磁力计」的经典组合。
 *
 *  2. **加速度计（是否真的在动）**：GPS 在静止时会飘（±30m 常见），只看 GPS 速度
 *     容易把「站着不动」判成移动，轨迹画成一团毛线球。加速度计能直接回答
 *     「设备有没有在动」：把重力低通滤掉后，取线性加速度的 RMS，超过阈值即认为
 *     真的在动。它与 GPS 速度互补（隧道里 GPS 没有速度但人还在走，反之 GPS 抖动
 *     但设备是静止的）。
 *
 *  3. **不给上层加负担**：常驻监听、缓存最近结果，Dart 侧按需 `sample` 拉取，
 *     不做持续的事件推送；停止时显式注销监听（否则会一直唤醒传感器耗电）。
 *
 * 采样率用 SENSOR_DELAY_UI（约 15Hz）：判「在不在动」与拿航向都够用，
 * 又比 SENSOR_DELAY_GAME 省电。
 */
class MotionManager(context: Context) : SensorEventListener {

    companion object {
        const val CHANNEL = "com.aprslocus/motion"

        /** 线性加速度 RMS 超过它才认为「真的在动」（m/s²）。 */
        private const val MOVE_THRESHOLD = 0.35

        /** 重力低通系数：越小越「粘」，用来把重力从加速度计读数里分离出去。 */
        private const val GRAVITY_ALPHA = 0.15f

        /** 线性加速度能量的指数平均系数。 */
        private const val ENERGY_ALPHA = 0.2

        // ── 碰撞 / 摔倒检测（issue #26；判据见下方 issue #32 的修正）──
        //
        // 判据分两种事件，**碰撞的要求比摔倒更高**：
        //   * **摔倒**：① 先有一段**失重/自由落体**（总加速度模 ≤ [FREEFALL_G] 持续
        //     ≥ [FREEFALL_MIN_MS]）② 落地冲击瞬时模 ≥ 基准阈值；③ 随后静止。
        //   * **碰撞**：没有失重可依据，就要求冲击 ≥ 基准 × [CRASH_BAR_MULT]；③ 同样。
        //   ③ **随后静止**：冲击之后连续 [STILL_MS] 毫秒没有明显运动。
        //
        // 为什么「碰撞」要更狠（v2.0.29 修的误报）：原来只要求「冲击 + 静止」，
        // 而**把手机放在桌上稍微使劲**恰好同时满足 —— 一个 3~8g 的尖峰，接着一动不动。
        // 阈值调高救不了（放手机的尖峰本可高过任何合理的撞击阈值），这是判据问题。
        // 区分开之后：放手机不会失重、尖峰也不够高 → 不报；真摔倒有失重佐证（阈值不翻倍），
        // 真车祸峰值动辄 20g 以上 → 照样报。
        //
        // 为什么要有「随后静止」：只报冲击的话，**过减速带、手机掉桌上、甩一甩**全都算，
        // 那样的提醒每天响好几次，用户第一件事就是关掉它。而「人在动」时几乎不可能同时
        // 满足「12 秒没有任何运动」，误报因此很低；代价是**轻微碰撞（人还能动）不报** ——
        // 这是刻意的：定位是「人已经动不了了」，不是「发生过撞击」。
        //
        // ⚠ 它是启发式的，不是工程级碰撞检测：阈值可调、不融合 GPS，判据只基于
        // 加速度计。界面上必须如实这么说（见生命守护页的说明卡）。
        //
        // 冲击阈值做成了**三档灵敏度**（issue #32 的「优化算法」）：固定阈值无法同时
        // 适配「手机放裤兜里踩单车」与「固定在车把上」——前者的正常颠簸就能越过
        // 3.2g。用户换档即改这里的取用值（见 [impactThresholdG]），不必发版。
        private const val SENS_GENTLE = 2.2
        private const val SENS_STANDARD = 3.0
        private const val SENS_FIRM = 4.0

        // ── 摔倒判定（issue #32 的「优化算法」）──
        // 单纯一个尖峰分不出「碰撞」和「摔倒」，但两者物理上不同：
        //   * 摔倒（人/手机离手落地）几乎总是先有一段**自由落体**（总加速度模接近 0，
        //     即「失重」），再是落地冲击；
        //   * 车祸撞击不会有那段失重。
        // 所以 [g] ≤ [FREEFALL_G] 持续 [FREEFALL_MIN_MS] 就记一次「自由落体」，
        // 随后的冲击按**摔倒**解读；否则按**碰撞**。
        //
        // ⚠ 判失重必须用**含重力的总加速度**，不能用去掉重力的线性加速度 —— 后者在
        // 静止时恒为 0，会把「放着不动」误判成「一直在自由落体」，于是每次冲击都被
        // 当成摔倒、且失重闸门常开。见 [checkImpact] 的入参。
        private const val FREEFALL_G = 0.35
        private const val FREEFALL_MIN_MS = 80L

        /** 自由落体之后多久内的冲击仍算作「摔倒」。 */
        private const val FREEFALL_WATCH_MS = 2000L

        /** 冲击之后的观察窗口：这么久没有明显运动才算「人没动」。 */
        private const val STILL_MS = 12000L

        // ── 为什么「碰撞」要比灵敏度阈值再高一截（issue #32 的误报修正）──
        // 原来的判据是「冲击尖峰 + 之后静止」，而**把手机放在桌上稍微使劲**恰好同时
        // 满足两段：一下 3~8g 的尖峰，机器接着就一动不动 —— 于是每次放手机都可能报。
        // 单靠调阈值救不了（放手机的尖峰本来就可能超过任何还算合理的撞击阈值）。
        //
        // 现在把两种事件分开要求：
        //   * **摔倒**：先有失重（自由落体）再冲击 —— 放手机绝不会失重，所以这条不误伤；
        //   * **碰撞**：没有失重可依赖，就要求冲击**明显更狠** —— 阈值再乘 [CRASH_BAR_MULT]。
        // 真实车祸的峰值动辄 20g 以上，翻倍照样抓得到；而轻放手机的 3~8g 会被挡掉。
        private const val CRASH_BAR_MULT = 2.0

        /** 认为是「明显运动」的线性加速度（g）——超过它就撤销这次候选。 */
        private const val MOVE_G = 1.2

        /** 两次告警之间的最小间隔。 */
        private const val CRASH_COOLDOWN_MS = 180000L

        /** 启动后的宽限期：刚启动时把设备拿起来/放下也会产生尖峰。 */
        private const val START_GRACE_MS = 20000L

        // ── 持久化键（issue #32）──
        // 把事件序号与上次告警时间落盘：原先只存在内存里，**杀进程重开就归零**，
        // 于是①「重启后冷却被清空，马上误报一次」；②事件序号回 0，Dart 侧靠序号
        // 发现新事件的判据也可能错乱。落盘后重启也能接上。
        private const val PREF = "aprslocus.motion"
        private const val PREF_SENS = "sensitivity"
        private const val PREF_SEQ = "crashSeq"
        private const val PREF_LAST_MS = "lastCrashMs"
        private const val PREF_KIND = "lastKind"
    }

    private val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    /** 权限检查要 Context（SensorManager 上拿不到）。存 applicationContext，
     *  免得把 Activity 一直持有。 */
    private val appContext = context.applicationContext

    private val accel: Sensor? = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val rotation: Sensor? = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private val mag: Sensor? = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

    /**
     * 计步传感器（issue #22-2）。
     *
     * TYPE_STEP_COUNTER 返回的是**开机以来的累计步数**（硬件/协处理器自己数，
     * 比用加速度计积分猜步数准得多、也省电），所以上层必须自己减基线：
     * 这里只如实上报原始值，「今天走了多少」由 Dart 侧按天算（见 AppState.stepsToday）。
     *
     * 为什么不用 TYPE_STEP_DETECTOR：那是一次一个事件的「检测到一步」，
     * 应用被杀死/重启期间就断了，累计值没法补；而计数器是硬件累加的，重启也连续。
     *
     * Android 10（API 29）起读取它需要 ACTIVITY_RECOGNITION 运行时权限；没有权限时
     * 系统**不派发事件**（不抛异常），所以这里的 [steps] 会一直是 -1，
     * 上层据此显示「未授权」而不是显示 0 —— 0 步与「读不到」是两件事。
     */
    private val stepCounter: Sensor? = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

    private var registered = false

    // ── 缓存的状态 ──
    private val gravity = FloatArray(3)
    private var accelEnergy = 0.0          // 线性加速度平方的指数平均
    private var heading = -1.0             // 磁北航向（度）；<0 不可用
    private var steps = -1L                // 开机以来累计步数；<0 表示读不到（无传感器/无权限）

    // ── 碰撞 / 摔倒（issue #26 / #32）──
    private var wantMotion = true          // 上层是否要「在不在动 / 航向」（与计步分开）
    private var startedAtMs = 0L
    private var impactAtMs = 0L            // 最近一次冲击的时间；0 = 没有候选
    private var impactPeakG = 0.0          // 那次冲击的峰值（供上层显示/排查）
    private var impactKind = ""            // 候选来自自由落体 → "fall"，否则 "crash"
    private var lastCrashMs = 0L           // 上次告警时间（冷却用，已落盘）
    private var crashSeq = 0               // 事件序号：Dart 侧靠它发现「又发生了一次」（已落盘）
    private var lastKind = ""              // 最近一次判定的类型（fall / crash）
    // 自由落体探测：处于自由落体的起始时间；0 = 当前不在自由落体。
    private var freefallStartMs = 0L
    private var lastFreefallEndMs = 0L     // 最近一次自由落体结束时间（判「冲击是否紧跟着摔倒」）
    private var sensitivity = "standard"   // gentle / standard / firm
    private var pitch = 0.0
    private var roll = 0.0

    private val prefs = context.applicationContext
        .getSharedPreferences(PREF, Context.MODE_PRIVATE)

    init {
        // 从磁盘接回事件序号与上次告警时间（见 [PREF] 的说明）。
        sensitivity = prefs.getString(PREF_SENS, "standard") ?: "standard"
        crashSeq = prefs.getInt(PREF_SEQ, 0)
        lastCrashMs = prefs.getLong(PREF_LAST_MS, 0L)
        lastKind = prefs.getString(PREF_KIND, "") ?: ""
    }

    /** 当前灵敏度对应的冲击阈值（g）。 */
    private val impactThresholdG: Double
        get() = when (sensitivity) {
            "gentle" -> SENS_GENTLE
            "firm" -> SENS_FIRM
            else -> SENS_STANDARD
        }

    private val rotationMatrix = FloatArray(9)
    private val orientation = FloatArray(3)
    private val accelVec = FloatArray(3)
    private val magVec = FloatArray(3)
    private var hasAccel = false
    private var hasMag = false

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // [motion] = 要不要监听加速度计/指南针（即「传感器辅助」）。
            // 计步器**始终**注册：步数与「在不在动」是两件事，用户把传感器辅助
            // 关掉时不该连步数一起没了（issue #23 的一半原因就是这个）。
            "start" -> result.success(start(call.argument<Boolean>("motion") ?: true))
            "stop" -> {
                stop()
                result.success(null)
            }
            "sample" -> result.success(snapshot())
            // issue #32：设置碰撞/摔倒灵敏度（gentle / standard / firm）。
            "setSensitivity" -> {
                setSensitivity(call.argument<String>("value") ?: "standard")
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * 注册监听。
     *
     * [includeMotion] = 是否要「在不在动 / 航向」（加速度计 / 旋转矢量 / 磁力计）。
     * 计步器与它无关，**始终**注册 —— 关掉传感器辅助的用户同样会看步数（issue #23）。
     *
     * 返回值：只要**有一个**目标传感器注册成功就算 true；一个都没有返回 false
     * （上层按「无传感器」处理）。注意注册成功 ≠ 有数据：计步器要等硬件事件
     * （见 [stepsPermission] 与 Dart 侧的「等待数据」状态）。
     */
    fun start(includeMotion: Boolean = true): Boolean {
        if (registered && wantMotion == includeMotion) return true
        if (registered) stop()
        wantMotion = includeMotion
        startedAtMs = System.currentTimeMillis()
        var ok = false
        if (includeMotion) {
            rotation?.let { ok = sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) || ok }
            accel?.let { ok = sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) || ok }
            mag?.let { ok = sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) || ok }
        }
        // 计步器：SENSOR_DELAY_NORMAL 就够（它本身是低频的硬件计数），
        // 注册失败（旧系统无权限模型、个别 ROM 限制）不影响其它传感器。
        try {
            stepCounter?.let {
                sm.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
                ok = true
            }
        } catch (_: Exception) {
        }
        registered = ok
        return ok
    }

    /**
     * 有没有 ACTIVITY_RECOGNITION 权限（读计步器需要，Android 10 起）。
     *
     * 为什么必须把它单独报给上层：**没有权限时系统只是「不派发事件」，不会报错** ——
     * 于是 `steps` 与「传感器坏了 / 还没走过路」看起来完全一样，上层只能猜。
     * 之前正是猜错了：把「还没收到第一个事件」当成「没授权」，用户明明授权了却
     * 一直看到「请授权」（issue #23）。
     */
    private fun stepsPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        return try {
            appContext.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
                PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) {
            false
        }
    }

    /** 授权后调用：把它当成「重新注册一次」，否则要等下一个硬件事件才更新。 */
    fun refreshStepsRegistration() {
        stepCounter?.let {
            try {
                sm.unregisterListener(this, it)
                sm.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            } catch (_: Exception) {
            }
        }
    }

    /**
     * 碰撞/摔倒的判据（见 [IMPACT_G] / [FREEFALL_G] / [CRASH_BAR_MULT] 的说明）。
     *
     * 两个入参是有意分开的：
     *   * [linear] = **去重力**的线性加速度模（m/s²）：判「冲击」与「人还在动」；
     *   * [total]  = **含重力**的总加速度模（m/s²）：判「失重/自由落体」。
     * 判失重只能用 [total] —— [linear] 在静止时恒为 0，会把「放着不动」当成一直在失重。
     *
     * issue #32 的区分：
     *   * **灵敏度**：基准阈值取 [impactThresholdG]，用户可换档；
     *   * **摔倒 vs 碰撞**：冲击前若有失重（≤[FREEFALL_G] 持续 ≥[FREEFALL_MIN_MS]），
     *     按「摔倒」且用基准阈值；否则按「碰撞」，要求冲击 ≥ 基准 × [CRASH_BAR_MULT]
     *     （放手机的尖峰不大，且没有失重，于是被这条挡掉）。
     */
    private fun checkImpact(linear: Double, total: Double) {
        val now = System.currentTimeMillis()
        val lg = linear / 9.80665
        val tg = total / 9.80665

        // ① 自由落体（失重）探测：用**总**加速度，正常静止≈1g，只有真失重才趋近 0。
        if (tg <= FREEFALL_G) {
            if (freefallStartMs == 0L) freefallStartMs = now
        } else {
            if (freefallStartMs != 0L) {
                // 自由落体段结束：够长才作数，随后一段时间内出现的冲击按「摔倒」看。
                if (now - freefallStartMs >= FREEFALL_MIN_MS) lastFreefallEndMs = now
                freefallStartMs = 0L
            }
        }

        if (impactAtMs == 0L) {
            // 冷却期内不再起新候选：一次事故之后短时间内会连续出现多个尖峰
            val fallWindow = lastFreefallEndMs != 0L &&
                now - lastFreefallEndMs <= FREEFALL_WATCH_MS
            // 摔倒由失重佐证，用基准阈值；碰撞无佐证，要明显更狠才认（防「放手机」误报）。
            val bar = if (fallWindow) impactThresholdG else impactThresholdG * CRASH_BAR_MULT
            if (lg >= bar && now - lastCrashMs > CRASH_COOLDOWN_MS &&
                now - startedAtMs > START_GRACE_MS
            ) {
                impactAtMs = now
                impactPeakG = lg
                impactKind = if (fallWindow) "fall" else "crash"
            }
            return
        }
        if (lg >= MOVE_G) {
            // 人还在动（掉桌上的手机被捡起来 / 过减速带后继续开）→ 撤销候选
            impactAtMs = 0L
            impactPeakG = 0.0
            impactKind = ""
            return
        }
        if (now - impactAtMs >= STILL_MS) {
            // 冲击之后连续静止 → 判定一次事件
            crashSeq++
            lastCrashMs = now
            lastKind = if (impactKind.isNotEmpty()) impactKind else "crash"
            impactAtMs = 0L
            impactKind = ""
            // 落盘：事件序号与冷却时间都要能跨进程重启接上（见 [PREF]）。
            prefs.edit()
                .putInt(PREF_SEQ, crashSeq)
                .putLong(PREF_LAST_MS, lastCrashMs)
                .putString(PREF_KIND, lastKind)
                .apply()
        }
    }

    /** 设置碰撞/摔倒检测灵敏度（gentle / standard / firm），立即落盘。 */
    fun setSensitivity(value: String) {
        val v = if (value in setOf("gentle", "standard", "firm")) value else "standard"
        if (v == sensitivity) return
        sensitivity = v
        prefs.edit().putString(PREF_SENS, v).apply()
    }

    fun stop() {
        if (!registered) return
        try {
            sm.unregisterListener(this)
        } catch (_: Exception) {
        }
        registered = false
        accelEnergy = 0.0
        hasAccel = false
        hasMag = false
        heading = -1.0
        impactAtMs = 0L
        impactPeakG = 0.0
        impactKind = ""
        freefallStartMs = 0L
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> {
                try {
                    SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                    SensorManager.getOrientation(rotationMatrix, orientation)
                    heading = norm360(Math.toDegrees(orientation[0].toDouble()))
                    pitch = Math.toDegrees(orientation[1].toDouble())
                    roll = Math.toDegrees(orientation[2].toDouble())
                } catch (_: Exception) {
                }
            }

            Sensor.TYPE_ACCELEROMETER -> {
                val v = event.values
                gravity[0] += GRAVITY_ALPHA * (v[0] - gravity[0])
                gravity[1] += GRAVITY_ALPHA * (v[1] - gravity[1])
                gravity[2] += GRAVITY_ALPHA * (v[2] - gravity[2])
                val lx = (v[0] - gravity[0]).toDouble()
                val ly = (v[1] - gravity[1]).toDouble()
                val lz = (v[2] - gravity[2]).toDouble()
                val e = lx * lx + ly * ly + lz * lz
                accelEnergy = accelEnergy * (1 - ENERGY_ALPHA) + e * ENERGY_ALPHA
                accelVec[0] = v[0]
                accelVec[1] = v[1]
                accelVec[2] = v[2]
                hasAccel = true
                // 冲击/移动用去重力的线性模；失重（自由落体）判据用含重力的总模。
                checkImpact(sqrt(e), sqrt((v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).toDouble()))
            }

            Sensor.TYPE_STEP_COUNTER -> {
                // 硬件累计值（Float，但精度到整数步）：直接取整上报，不做平滑 ——
                // 平滑会让「今天走了多少」随时间漂。
                if (event.values.isNotEmpty()) steps = event.values[0].toLong()
            }

            Sensor.TYPE_MAGNETIC_FIELD -> {
                val v = event.values
                magVec[0] = v[0]
                magVec[1] = v[1]
                magVec[2] = v[2]
                hasMag = true
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 不需要处理：航向用原始值，精度问题由「低速才采用」这条策略兜住
    }

    /** 生成一次快照。没有旋转矢量时用「加速度计 + 磁力计」现算航向。 */
    private fun snapshot(): Map<String, Any?> {
        if (rotation == null && hasAccel && hasMag) {
            try {
                if (SensorManager.getRotationMatrix(rotationMatrix, null, accelVec, magVec)) {
                    SensorManager.getOrientation(rotationMatrix, orientation)
                    heading = norm360(Math.toDegrees(orientation[0].toDouble()))
                    pitch = Math.toDegrees(orientation[1].toDouble())
                    roll = Math.toDegrees(orientation[2].toDouble())
                }
            } catch (_: Exception) {
            }
        }
        val rms = sqrt(accelEnergy)
        return mapOf(
            "available" to (accel != null || rotation != null || mag != null),
            "moving" to (rms > MOVE_THRESHOLD),
            "hasCompass" to (rotation != null || (hasAccel && hasMag)),
            "heading" to heading,
            "pitch" to pitch,
            "roll" to roll,
            "accel" to rms,
            // 计步（issue #22-2）：-1 = 没有传感器或没有 ACTIVITY_RECOGNITION 权限。
            // 单独给一个 hasSteps 而不是让上层拿 -1 猜 —— 「没有这个传感器」与
            // 「有但没授权」在界面上要给出不同的指引。
            "steps" to steps,
            "hasSteps" to (stepCounter != null),
            // 权限单独报（见 stepsPermission 的说明）：-1 的读数有三种原因
            // （无传感器 / 没权限 / 还没收到事件），上层要能把它们分开说。
            "stepsPermission" to stepsPermission(),
            // 碰撞/摔倒（issue #26）：crashSeq 是事件序号，impactPending 表示
            // 「检测到冲击，正在观察」——后者只用于界面显示，不触发告警。
            "crashSeq" to crashSeq,
            "hasCrashSensor" to (accel != null),
            "impactPending" to (impactAtMs != 0L),
            "impactPeakG" to (Math.round(impactPeakG * 10) / 10.0),
            // issue #32：最近一次判定是摔倒还是碰撞，以及当前灵敏度（供设置页回显）。
            "lastKind" to lastKind,
            "sensitivity" to sensitivity,
        )
    }

    private fun norm360(deg: Double): Double {
        var d = deg % 360.0
        if (d < 0) d += 360.0
        return d
    }
}
