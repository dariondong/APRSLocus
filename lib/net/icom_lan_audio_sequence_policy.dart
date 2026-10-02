/// 音频序号策略（对应 mod 的 `session/Ic705AudioSequencePolicy.kt`）。
///
/// 这些常量是**实测调出来的**，不要凭感觉改：
///   * IC-705 每秒约 100 个音频包，4 个包的窗口正好吸收普通 Wi-Fi 抖动；
///   * 12 kHz LPCM 下大/小交替包是 171/69 个样本（20 ms 一对）——
///     48 kHz 抓包里的 682/278 直接搬过来会多塞 4 倍静音。
library;

/// 序号环的一半：超过它就算"迟到"，不再等待。
const int kIcomLanAudioHalfSequenceSpace = 0x8000;

/// 重排窗口（包数）。
const int kIcomLanAudioMaxReorderPackets = 4;

/// 12 kHz 下大包的样本数（偶数序号）。
const int kIcomLanAudioLargeRxPacketSamples = 171;

/// 12 kHz 下小包的样本数（奇数序号）。
const int kIcomLanAudioSmallRxPacketSamples = 69;

/// 允许补齐（填静音）的最大丢包数。
const int kIcomLanAudioMaxConcealedPackets = 2;

int incrementIcomLanAudioSequence(int sequence) => (sequence + 1) & 0xffff;

/// 从 [from] 到 [to] 的前向距离（环形）。
int icomLanAudioSequenceDistance(int from, int to) => (to - from) & 0xffff;

/// 按序号奇偶给出该包应有的样本数（观测不到真实大小时用）。
int icomLanSamplesPerReceivePacket(int sequence) =>
    sequence & 1 == 0
        ? kIcomLanAudioLargeRxPacketSamples
        : kIcomLanAudioSmallRxPacketSamples;
