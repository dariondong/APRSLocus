package com.aprslocus.aprslocus

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager as AndroidAudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 声卡 TNC（AFSK 1200 / Bell 202）的原生音频链路。
 *
 * 设计取舍与 [TncManager] 一致：**原生侧只搬 PCM 采样，不理解 APRS** ——
 * AFSK 调制解调、HDLC 帧定界、AX.25 编解码全在 Dart 侧（lib/afsk.dart）。
 * 这样：
 *   ① 协议实现只有一份，可单元测试（test/afsk_test.dart）；
 *   ② 采样率、音调、比特率等参数改动不需要重新发版；
 *   ③ 原生侧只关心「按 sampleRate 采 16 位单声道」和「把 16 位单声道播出去」。
 *
 * 采集用 [AudioRecord]（读线程 + EventChannel 上传字节），
 * 播放用 [AudioTrack]（MODE_STREAM，写完整包后等播放头走完再释放）。
 *
 * 采集音源选择（对 AFSK 影响很大）：
 *   * 优先 UNPROCESSED（API 24+，若系统声明支持）—— 不做 AGC/降噪/自动增益，
 *     波形保真，最适合解调；
 *   * 其次 VOICE_RECOGNITION —— 系统通常只做轻量处理；
 *   * 最后 MIC —— 可能带 AGC/降噪，解调成功率下降（会在日志里说明）。
 */
class AudioManager(private val activity: Activity) {

    companion object {
        const val METHOD_CHANNEL = "com.aprslocus/audio"
        const val EVENT_CHANNEL = "com.aprslocus/audio_events"

        private const val PERM_REQUEST = 0x7A41

        private const val TAG = "APRSLocusAudio"

        /** 采集读块：1024 样本 ≈ 46ms @22050Hz */
        private const val READ_SAMPLES = 1024
    }

    private val main = Handler(Looper.getMainLooper())
    private val running = AtomicBoolean(false)

    private var record: AudioRecord? = null
    private var recordThread: Thread? = null

    private var track: AudioTrack? = null
    private var playThread: Thread? = null

    private var events: EventChannel.EventSink? = null
    private var permResult: MethodChannel.Result? = null

    private var sourceName = ""

    /**
     * 发射期间真的暂停麦克风采集（半双工）。
     *
     * 为什么要暂停：一边录音一边播放时，部分机型会把播放**路由到听筒**、
     * 或叠加 AEC/降噪，波形到了耳机口/喇叭上已经变形（频率响应被改、
     * 电平被压）—— 表现就是「本机自检全过，但电台 / Direwolf 解不出」。
     *
     * 为什么不只是「读出来丢掉」：那样 AudioRecord 仍处于 RECORDING 状态，
     * 上面那些机型行为（路由/AEC）照样生效，等于没停。所以这里真的
     * stop()/startRecording()。
     *
     * 风险控制（Stop/Start 本身可能失败，且 read() 在 stop 后可能返回
     * 负值或抛异常）：读线程在暂停期间**完全不碰 read()**，异常也只在
     * 未暂停时才当成链路故障上报 —— 否则每次发射都会被误判成
     * 「采集被系统中断」，进而触发自动重连。
     */
    private val capturePaused = AtomicBoolean(false)

    /** 发射前用户的媒体音量（-1 = 未改动，无需恢复） */
    private var savedVolume = -1

    /** 发射期间是否已申请音频焦点 */
    private var focusHeld = false

    // ─── 设备能力 ───

    fun isSupported(): Boolean {
        return try {
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE) ||
                hasPermission()
        } catch (_: Exception) {
            false
        }
    }

    private fun hasPermission(): Boolean =
        ActivityCompat.checkSelfPermission(
            activity, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

    fun requestPermissions(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        permResult = result
        ActivityCompat.requestPermissions(
            activity, arrayOf(Manifest.permission.RECORD_AUDIO), PERM_REQUEST
        )
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERM_REQUEST) return
        val ok = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        permResult?.success(ok)
        permResult = null
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        events = sink
    }

    private fun emitPcm(data: ByteArray) {
        val sink = events ?: return
        main.post { sink.success(mapOf("type" to "pcm", "data" to data)) }
    }

    private fun emitState(state: String) {
        val sink = events ?: return
        main.post { sink.success(mapOf("type" to "state", "state" to state)) }
    }

    private fun emitError(message: String) {
        val sink = events ?: return
        main.post {
            sink.success(mapOf("type" to "state", "state" to "error", "message" to message))
        }
    }

    // ─── 采集 ───

    /** 选择最适合 AFSK 的音源（尽量绕开 AGC/降噪） */
    private fun pickSource(): Int {
        val am = activity.getSystemService(Context.AUDIO_SERVICE) as? AndroidAudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val supportsUnprocessed = am?.getProperty(
                AndroidAudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED
            ) == "true"
            if (supportsUnprocessed) {
                sourceName = "UNPROCESSED"
                return MediaRecorder.AudioSource.UNPROCESSED
            }
        }
        sourceName = "VOICE_RECOGNITION"
        return MediaRecorder.AudioSource.VOICE_RECOGNITION
    }

    fun startCapture(sampleRate: Int): Boolean {
        if (!hasPermission()) {
            emitError("缺少录音权限（RECORD_AUDIO）")
            return false
        }
        if (running.get()) return true

        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf <= 0) {
            emitError("采样率 $sampleRate Hz 不受支持")
            return false
        }
        val bufBytes = maxOf(minBuf, sampleRate * 2 / 5) // 至少 ~200ms

        val source = try {
            pickSource()
        } catch (_: Exception) {
            sourceName = "MIC"
            MediaRecorder.AudioSource.MIC
        }

        val rec = try {
            AudioRecord(source, sampleRate, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, bufBytes)
        } catch (e: Exception) {
            emitError("AudioRecord 创建失败：${e.message}")
            return false
        }
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            try { rec.release() } catch (_: Exception) {}
            emitError("AudioRecord 初始化失败（可能被其它应用占用）")
            return false
        }
        record = rec
        running.set(true)
        emitState("captureStarted:$sourceName")
        recordThread = Thread {
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            val buf = ByteArray(READ_SAMPLES * 2)
            try {
                rec.startRecording()
                while (running.get()) {
                    // 发射暂停期间不碰 read()：stop() 之后 read() 会立刻返回 0，
                    // 继续读就变成忙等（吃满一个核）
                    if (capturePaused.get()) {
                        Thread.sleep(20)
                        continue
                    }
                    val n = rec.read(buf, 0, buf.size)
                    if (n > 0) {
                        emitPcm(if (n == buf.size) buf.copyOf() else buf.copyOf(n))
                    } else if (n < 0) {
                        // 负数可能是「发射暂停时 stop() 的副作用」：此时不是故障
                        if (capturePaused.get() || !running.get()) {
                            Thread.sleep(20)
                            continue
                        }
                        emitError("AudioRecord.read 返回 $n")
                        break
                    }
                }
            } catch (e: Exception) {
                // 同上：暂停/停止期间的异常属预期，不要上报成链路中断
                if (running.get() && !capturePaused.get()) {
                    emitError("采集异常：${e.message}")
                }
            } finally {
                running.set(false)
                emitState("captureClosed")
            }
        }.also { it.name = "afsk-audio-rx"; it.start() }
        return true
    }

    fun stopCapture() {
        running.set(false)
        capturePaused.set(false)
        try {
            record?.stop()
        } catch (_: Exception) {
        }
        try {
            record?.release()
        } catch (_: Exception) {
        }
        record = null
        recordThread = null
    }

    // ─── 发射期间的系统准备（音量 / 焦点 / 半双工） ───

    /**
     * 把媒体音量拉到最大并申请瞬时音频焦点。
     *
     * 声卡 TNC 靠的就是输出电平：手机媒体音量偏低时，对端（Direwolf /
     * 电台）信噪比不够，整帧都解不出；而别的应用正在放的音乐会和 FSK
     * 混在一起（混音等于加噪声，波形直接毁掉）。两者都在这里处理，
     * 播完立刻恢复用户原来的音量并归还焦点。
     */
    private fun raiseOutput() {
        val am = activity.getSystemService(Context.AUDIO_SERVICE) as? AndroidAudioManager
            ?: return
        if (savedVolume < 0) {
            try {
                val cur = am.getStreamVolume(AndroidAudioManager.STREAM_MUSIC)
                val max = am.getStreamMaxVolume(AndroidAudioManager.STREAM_MUSIC)
                if (cur < max) {
                    am.setStreamVolume(AndroidAudioManager.STREAM_MUSIC, max, 0)
                    savedVolume = cur
                    Log.i(TAG, "发射：媒体音量 $cur → $max（结束后恢复）")
                } else {
                    savedVolume = -2 // 已经是最大：无需恢复
                }
            } catch (_: Exception) {
                savedVolume = -2
            }
        }
        if (!focusHeld) {
            try {
                am.requestAudioFocus(
                    null,
                    AndroidAudioManager.STREAM_MUSIC,
                    AndroidAudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                )
                focusHeld = true
            } catch (_: Exception) {
            }
        }
    }

    /** 恢复发射前的媒体音量并归还音频焦点（幂等） */
    private fun restoreOutput() {
        val am = activity.getSystemService(Context.AUDIO_SERVICE) as? AndroidAudioManager
        if (am != null && savedVolume >= 0) {
            try {
                am.setStreamVolume(AndroidAudioManager.STREAM_MUSIC, savedVolume, 0)
            } catch (_: Exception) {
            }
        }
        savedVolume = -1
        if (am != null && focusHeld) {
            try {
                am.abandonAudioFocus(null)
            } catch (_: Exception) {
            }
        }
        focusHeld = false
    }

    /**
     * 发射开始：先把标志置上再 stop()，让读线程立刻安静下来。
     * 停不掉也不拦发射（大不了还是「边录边放」，即当前行为）。
     */
    private fun pauseCapture() {
        if (!running.get() || record == null) return
        capturePaused.set(true)
        try {
            record?.stop()
        } catch (e: Exception) {
            Log.w(TAG, "发射前暂停采集失败（忽略，继续发射）：${e.message}")
        }
    }

    /**
     * 发射结束：恢复采集。
     *
     * 恢复失败是**真故障**（接下来收不到任何东西），所以报错并关闭采集流，
     * 让上层走「采集被系统中断 → 自动重连」这条已有路径，而不是安静地
     * 变成只能发不能收。
     */
    private fun resumeCapture() {
        if (!capturePaused.getAndSet(false)) return
        if (!running.get()) return
        val rec = record ?: return
        try {
            rec.startRecording()
        } catch (e: Exception) {
            Log.e(TAG, "发射后恢复采集失败：${e.message}")
            emitError("发射后恢复采集失败：${e.message}")
            running.set(false)
            emitState("captureClosed")
        }
    }

    // ─── 播放 ───

    fun play(data: ByteArray, sampleRate: Int): Boolean {
        if (data.isEmpty()) return true
        stopPlayback()
        try {
            // 先做系统侧准备（音量/焦点/半双工），任何一步失败都不拦播放
            raiseOutput()
            pauseCapture()
            val minBuf = AudioTrack.getMinBufferSize(
                sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuf <= 0) {
                emitError("播放采样率 $sampleRate Hz 不受支持")
                return false
            }
            val size = maxOf(minBuf, data.size)
            val t = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(size)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            if (t.state != AudioTrack.STATE_INITIALIZED) {
                try { t.release() } catch (_: Exception) {}
                emitError("AudioTrack 初始化失败")
                return false
            }
            track = t
            emitState("playing")
            playThread = Thread {
                Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
                try {
                    t.play()
                    var off = 0
                    while (off < data.size) {
                        val n = t.write(data, off, data.size - off)
                        if (n <= 0) break
                        off += n
                    }
                    // 等播放头走完（写完成 ≠ 播完），再释放
                    val frames = data.size / 2
                    var guard = 0
                    while (t.playbackHeadPosition < frames && guard < 2000) {
                        Thread.sleep(10)
                        guard++
                    }
                } catch (_: Exception) {
                } finally {
                    try { t.stop() } catch (_: Exception) {}
                    try { t.release() } catch (_: Exception) {}
                    if (track === t) track = null
                    // 半双工收尾：恢复采集与音量后再告诉上层「播完了」
                    resumeCapture()
                    restoreOutput()
                    emitState("playDone")
                }
            }.also { it.name = "afsk-audio-tx"; it.start() }
            return true
        } catch (e: Exception) {
            emitError("播放失败：${e.message}")
            resumeCapture()
            restoreOutput()
            return false
        }
    }

    fun stopPlayback() {
        try {
            track?.pause()
            track?.flush()
        } catch (_: Exception) {
        }
        try {
            track?.release()
        } catch (_: Exception) {
        }
        track = null
        playThread = null
        // 用户中途停止发射 / 断开链路：同样要把采集与音量还给系统
        resumeCapture()
        restoreOutput()
    }

    fun dispose() {
        stopCapture()
        stopPlayback()
        events = null
    }
}
