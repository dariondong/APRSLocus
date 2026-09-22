package com.aprslocus.aprslocus

import android.content.Context
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
    }

    private val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    private val accel: Sensor? = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val rotation: Sensor? = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private val mag: Sensor? = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

    private var registered = false

    // ── 缓存的状态 ──
    private val gravity = FloatArray(3)
    private var accelEnergy = 0.0          // 线性加速度平方的指数平均
    private var heading = -1.0             // 磁北航向（度）；<0 不可用
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
            "start" -> result.success(start())
            "stop" -> {
                stop()
                result.success(null)
            }
            "sample" -> result.success(snapshot())
            else -> result.notImplemented()
        }
    }

    /** 注册监听。没有加速度计也没有旋转矢量时返回 false（上层按「无传感器」处理）。 */
    fun start(): Boolean {
        if (registered) return true
        if (accel == null && rotation == null && mag == null) return false
        var ok = false
        rotation?.let { ok = sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) || ok }
        accel?.let { ok = sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) || ok }
        mag?.let { ok = sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) || ok }
        registered = ok
        return ok
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
        )
    }

    private fun norm360(deg: Double): Double {
        var d = deg % 360.0
        if (d < 0) d += 360.0
        return d
    }
}
