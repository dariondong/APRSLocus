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

        // ── 碰撞 / 摔倒检测（issue #26）──
        //
        // 判据是**两段式**的，单看任何一段都不够：
        //   ① **冲击**：线性加速度瞬时模超过 [IMPACT_G] g。车祸与摔倒都会给出一个
        //      尖峰（线性加速度已去掉重力，所以「急刹」这类持续加速度不会被误判成尖峰）；
        //   ② **随后静止**：冲击之后连续 [STILL_MS] 毫秒没有明显运动。
        //
        // 为什么必须要求「随后静止」：只报冲击的话，**过减速带、手机掉桌上、甩一甩**
        // 全都算 —— 那样的提醒每天会响好几次，用户第一件事就是把它关掉，等于没做。
        // 而「人在动」时（走路/骑行/开车）几乎不可能同时满足「12 秒没有任何运动」，
        // 于是误报被压到很低，代价是**轻微碰撞（人还能动）不会报** —— 这是刻意的：
        // 这个功能的定位是「人已经动不了了」，而不是「发生过撞击」。
        //
        // ⚠ 它是启发式的，不是工程级碰撞检测：阈值固定、不看行车方向、不融合 GPS。
        // 界面上必须如实这么说（见生命守护页的说明卡）。
        private const val IMPACT_G = 3.2

        /** 冲击之后的观察窗口：这么久没有明显运动才算「人没动」。 */
        private const val STILL_MS = 12000L

        /** 认为是「明显运动」的线性加速度（g）——超过它就撤销这次候选。 */
        private const val MOVE_G = 1.2

        /** 两次告警之间的最小间隔。 */
        private const val CRASH_COOLDOWN_MS = 180000L

        /** 启动后的宽限期：刚启动时把设备拿起来/放下也会产生尖峰。 */
        private const val START_GRACE_MS = 20000L
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

    // ── 碰撞 / 摔倒（issue #26）──
    private var wantMotion = true          // 上层是否要「在不在动 / 航向」（与计步分开）
    private var startedAtMs = 0L
    private var impactAtMs = 0L            // 最近一次冲击的时间；0 = 没有候选
    private var impactPeakG = 0.0          // 那次冲击的峰值（供上层显示/排查）
    private var lastCrashMs = 0L           // 上次告警时间（冷却用）
    private var crashSeq = 0               // 事件序号：Dart 侧靠它发现「又发生了一次」
    private var pitch = 0.0
    private var roll = 0.0

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
     * 碰撞/摔倒的两段式判据（见 [IMPACT_G] 的说明）。
     *
     * 这里用的是**瞬时**线性加速度模，不是那个指数平均的 [accelEnergy] ——
     * 平均会把尖峰抹平，而尖峰正是要抓的东西。
     */
    private fun checkImpact(mag: Double) {
        val now = System.currentTimeMillis()
        val g = mag / 9.80665
        if (impactAtMs == 0L) {
            // 冷却期内不再起新候选：一次事故之后短时间内会连续出现多个尖峰
            if (g >= IMPACT_G && now - lastCrashMs > CRASH_COOLDOWN_MS &&
                now - startedAtMs > START_GRACE_MS
            ) {
                impactAtMs = now
                impactPeakG = g
            }
            return
        }
        if (g >= MOVE_G) {
            // 人还在动（掉桌上的手机被捡起来 / 过减速带后继续开）→ 撤销候选
            impactAtMs = 0L
            impactPeakG = 0.0
            return
        }
        if (now - impactAtMs >= STILL_MS) {
            // 冲击之后连续静止 → 判定一次事件
            crashSeq++
            lastCrashMs = now
            impactAtMs = 0L
        }
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
                checkImpact(sqrt(e))
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
        )
    }

    private fun norm360(deg: Double): Double {
        var d = deg % 360.0
        if (d < 0) d += 360.0
        return d
    }
}
