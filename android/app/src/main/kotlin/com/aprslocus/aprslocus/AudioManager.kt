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
                    val n = rec.read(buf, 0, buf.size)
                    if (n > 0) {
                        emitPcm(if (n == buf.size) buf.copyOf() else buf.copyOf(n))
                    } else if (n < 0) {
                        emitError("AudioRecord.read 返回 $n")
                        break
                    }
                }
            } catch (e: Exception) {
                if (running.get()) emitError("采集异常：${e.message}")
            } finally {
                running.set(false)
                emitState("captureClosed")
            }
        }.also { it.name = "afsk-audio-rx"; it.start() }
        return true
    }

    fun stopCapture() {
        running.set(false)
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

    // ─── 播放 ───

    fun play(data: ByteArray, sampleRate: Int): Boolean {
        if (data.isEmpty()) return true
        stopPlayback()
        try {
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
                    emitState("playDone")
                }
            }.also { it.name = "afsk-audio-tx"; it.start() }
            return true
        } catch (e: Exception) {
            emitError("播放失败：${e.message}")
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
    }

    fun dispose() {
        stopCapture()
        stopPlayback()
        events = null
    }
}
