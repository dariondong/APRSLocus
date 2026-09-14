#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AFSK 1200（Bell 202）+ HDLC 的**独立参考实现**（交叉验证用）

背景：AFSK 调制解调最容易出现「自己编、自己解，同一个理解错误两头都掩盖」
的情况（波形错了不会有异常，只是对方收不到）。所以这里用一份**与 Dart 侧
完全独立**的实现来互相校验：

  gen    —— 按规范生成参考录音（可注入噪声/直流/频偏/静音），
            供 test/afsk_test.dart 的「参考音频」用例解调；
  decode —— 独立的暴力解调器：一比特窗复数相关求判别量后，
            对「比特相位 × 速率比例」做穷举搜索，最终以 **FCS 校验**裁决
            （16 位校验通过几乎不可能是巧合，因此解出来的帧一定是对的）。
            用来验证 Dart 调制器生成的音频真实可解。
  verify —— gen + 让 Dart 生成音频 + decode，双向自检。

用法：
  python3 tool/afsk_reference.py gen
  python3 tool/afsk_reference.py decode FILE.wav
  python3 tool/afsk_reference.py verify

参考：Bell 202 / AX.25（APRS101 第 9 章）、Dire Wolf、KISS（KA9Q）。
"""

import math
import os
import random
import struct
import subprocess
import sys
import wave

BAUD = 1200.0
MARK = 1200.0
SPACE = 2200.0
FS = 22050
AMP = 0.55
FLAG = 0x7E

REF_WAV = os.path.join('test', 'reference', 'afsk1200_reference.wav')

# 参考录音里的两帧（第二帧故意加噪声 + 频偏）
REF_FRAMES = [
    'BG7LZQ-9>APALOC:!2230.00N/11400.00E>独立实现参考录音',
    'BG7LZQ>APALOC:>AFSK 1200 reference frame two',
]


# ─── 协议层：CRC / AX.25 / HDLC ───

def crc16_x25(data, crc=0xFFFF):
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0x8408 if crc & 1 else crc >> 1
    return crc & 0xFFFF


def fcs_ok(frame_with_fcs):
    """整帧（含 FCS）残差恒为 0xF0B8"""
    return crc16_x25(frame_with_fcs) == 0xF0B8


def append_fcs(payload):
    fcs = crc16_x25(payload) ^ 0xFFFF
    return bytes(list(payload) + [fcs & 0xFF, (fcs >> 8) & 0xFF])


def split_call(text):
    text = text.strip().upper()
    if '-' in text:
        base, _, ssid = text.rpartition('-')
        if ssid.isdigit():
            return base, max(0, min(15, int(ssid)))
    return text, 0


def ax25_address(call_ssid, last):
    call, ssid = split_call(call_ssid)
    out = [((ord(ch) & 0x7F) << 1) & 0xFF for ch in call.ljust(6)[:6]]
    out.append(0x60 | ((ssid & 0x0F) << 1) | (1 if last else 0))
    return bytes(out)


def ax25_ui(tnc2):
    """TNC2 文本 → AX.25 UI 帧（不含 FCS）"""
    src, rest = tnc2.split('>', 1)
    header, info = rest.split(':', 1)
    parts = [p.strip() for p in header.split(',') if p.strip()]
    dest, digis = parts[0], parts[1:]
    out = ax25_address(dest, last=False)
    out += ax25_address(src, last=not digis)
    for i, d in enumerate(digis):
        out += ax25_address(d, last=(i == len(digis) - 1))
    out += bytes([0x03, 0xF0]) + info.encode('utf-8')
    return out


def to_bits(data):
    """字节流 → 比特流（每字节 LSB 先发）"""
    out = []
    for byte in data:
        for i in range(8):
            out.append((byte >> i) & 1)
    return out


def bit_stuff(raw):
    out, ones = [], 0
    for bit in raw:
        out.append(bit)
        if bit:
            ones += 1
            if ones == 5:
                out.append(0)
                ones = 0
        else:
            ones = 0
    return out


def hdlc_stream(payload, pre_flags=30, tail_flags=3):
    out = to_bits([FLAG]) * pre_flags
    out += bit_stuff(to_bits(append_fcs(payload)))
    out += to_bits([FLAG]) * tail_flags
    return out


# ─── 调制：HDLC 比特 → NRZI → AFSK 采样 ───

def modulate(bits, freq_offset=0.0):
    """NRZI 编码 + 相位连续 AFSK。freq_offset 模拟电台偏频（Hz）"""
    spb = FS / BAUD
    total = int(round(len(bits) * spb))
    mark = (MARK + freq_offset) * 2 * math.pi / FS
    space = (SPACE + freq_offset) * 2 * math.pi / FS
    out = [0.0] * total
    tone, tone_bit, phase = 1, -1, 0.0
    for n in range(total):
        bi = int(n / spb)
        bit = bits[bi] if bi < len(bits) else 1
        # NRZI 变号必须每比特一次（逐采样翻转会发出噪声 —— 交叉验证发现的 bug）
        if bi != tone_bit:
            tone_bit = bi
            if bit == 0:
                tone ^= 1
        phase += mark if tone else space
        if phase >= 2 * math.pi:
            phase -= 2 * math.pi
        out[n] = math.sin(phase) * AMP
    return out


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(FS)
        w.writeframes(struct.pack('<%dh' % len(samples),
                                  *[max(-32768, min(32767, int(round(s * 32767)))) for s in samples]))
    print('wrote %s (%d 采样, %.2fs)' % (path, len(samples), len(samples) / FS))


def generate(path=REF_WAV):
    rnd = random.Random(20260914)
    signal = []
    # 起始 400ms 静音（模拟静噪/线路噪声底）
    signal += [0.0] * int(FS * 0.4)

    f1 = ax25_ui(REF_FRAMES[0])
    audio1 = modulate(hdlc_stream(f1, pre_flags=24, tail_flags=3))
    # 帧一：轻微直流偏置 + 小噪声 + 0.85 增益（模拟声卡线路输入）
    signal += [v * 0.85 + 0.04 + rnd.gauss(0, 0.015) for v in audio1]

    # 帧间 600ms 静音
    signal += [rnd.gauss(0, 0.008) for _ in range(int(FS * 0.6))]

    f2 = ax25_ui(REF_FRAMES[1])
    audio2 = modulate(hdlc_stream(f2, pre_flags=24, tail_flags=3), freq_offset=25.0)
    # 帧二：+25Hz 偏频 + 较强噪声（约 15dB SNR）+ 半幅
    signal += [v * 0.5 + rnd.gauss(0, 0.05) for v in audio2]

    signal += [rnd.gauss(0, 0.01) for _ in range(int(FS * 0.3))]
    write_wav(path, signal)
    for text in REF_FRAMES:
        print('  期望帧：%s' % text)
    return path


# ─── 独立解调：判别量 + 暴力时钟搜索 + FCS 裁决 ───

def read_wav(path):
    with wave.open(path, 'rb') as w:
        channels, width, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if width != 2:
        raise SystemExit('只支持 16 位 WAV：%s' % path)
    samples = list(struct.unpack('<%dh' % (len(raw) // 2), raw))
    if channels > 1:  # 多声道取平均
        samples = [sum(samples[i:i + channels]) // channels
                   for i in range(0, len(samples) - channels + 1, channels)]
    return rate, samples


def discriminator(samples, rate, win):
    """一比特窗复数相关：d = |corr(mark)|² − |corr(space)|²"""
    w1 = 2 * math.pi * MARK / rate
    w2 = 2 * math.pi * SPACE / rate
    cos1 = [math.cos(w1 * k) for k in range(win)]
    sin1 = [math.sin(w1 * k) for k in range(win)]
    cos2 = [math.cos(w2 * k) for k in range(win)]
    sin2 = [math.sin(w2 * k) for k in range(win)]
    n = len(samples)
    out = [0.0] * n
    for i in range(n):
        a = b = c = d = 0.0
        j = i
        for k in range(win):
            v = samples[j] if j >= 0 else 0.0
            a += v * cos1[k]
            b += v * sin1[k]
            c += v * cos2[k]
            d += v * sin2[k]
            j -= 1
        out[i] = (a * a + b * b) - (c * c + d * d)
    return out


def hdlc_extract(data_bits):
    """NRZI 解出的比特流 → 完整 AX.25 帧（FCS 校验通过才留下）"""
    frames = []
    shift = ones = byte = nbit = 0
    buf = bytearray()
    in_frame = False
    for bit in data_bits:
        shift = ((shift >> 1) | (bit << 7)) & 0xFF
        if shift == FLAG:
            if in_frame and len(buf) - 2 >= 16 and fcs_ok(bytes(buf)):
                frames.append(bytes(buf[:-2]))
            in_frame, buf, ones, byte, nbit = True, bytearray(), 0, 0, 0
            continue
        if not in_frame:
            continue
        if ones >= 6:  # 第 7 个连续 1 → 中止（6 个连续 1 是 flag，已在上面识别）
            in_frame = False
            continue
        if bit == 0 and ones == 5:
            ones = 0
            continue
        ones = ones + 1 if bit else 0
        byte = (byte >> 1) | (bit << 7)
        nbit += 1
        if nbit == 8:
            buf.append(byte)
            byte = nbit = 0
            if len(buf) > 512:
                in_frame = False
    return frames


def decode_bits_from(disc, spb, phase):
    """按固定时钟取样 → NRZI 解码"""
    bits = []
    pos = phase
    n = len(disc)
    while pos < n:
        bits.append(1 if disc[int(pos)] > 0 else 0)
        pos += spb
    data = []
    prev = None
    for tone in bits:
        if prev is None:
            prev = tone
            continue
        data.append(1 if tone == prev else 0)
        prev = tone
    return data


def tnc2_of(frame):
    """AX.25 帧 → TNC2 文本（独立实现）"""
    parts = []
    off = 0
    calls = []
    for _ in range(10):
        call = ''.join(chr((frame[off + i] >> 1) & 0x7F) for i in range(6)).strip()
        ssid = (frame[off + 6] >> 1) & 0x0F
        last = frame[off + 6] & 1
        calls.append('%s-%d' % (call, ssid) if ssid else call)
        off += 7
        if last or off + 7 > len(frame):
            break
    dest, src, digis = calls[0], calls[1], calls[2:]
    if (frame[off] & 0xEF) != 0x03:
        return None
    info = frame[off + 2:].decode('utf-8', 'replace')
    head = src + '>' + dest
    if digis:
        head += ',' + ','.join(d + '*' for d in digis)
    return head + ':' + info


def decode_file(path):
    rate, samples = read_wav(path)
    spb = rate / BAUD
    win = max(4, int(round(spb)))
    disc = discriminator(samples, rate, win)
    found = []
    for pi in range(48):
        for ri in range(9):
            scale = 1.0 + (ri - 4) * 0.0025
            for frame in hdlc_extract(decode_bits_from(disc, spb * scale, pi * spb / 48.0)):
                line = tnc2_of(frame)
                if line and line not in found:
                    found.append(line)
    return rate, found


def verify():
    """双向自检：Python 生成 → Python 解；Dart 生成 → Python 解"""
    print('== 1) Python 参考实现自检（gen → decode）==')
    generate()
    _, found = decode_file(REF_WAV)
    print('  解出 %d 帧：' % len(found))
    for line in found:
        print('   ', line)
    ok_a = found == REF_FRAMES

    print('== 2) Dart 调制器 → Python 独立解调（decode）==')
    ok_b = True
    for i, text in enumerate(REF_FRAMES):
        wav_path = '/tmp/afsk_dart_%d.wav' % i
        out = subprocess.run(['dart', 'run', 'tool/dump_afsk_wav.dart', text, wav_path],
                             capture_output=True, text=True)
        if out.returncode != 0:
            print('  dart run 失败：%s%s' % (out.stdout, out.stderr))
            ok_b = False
            break
        _, got = decode_file(wav_path)
        # Dart 发出的帧带中继时会有 *，这里参考帧无中继
        mark = '  通过' if text in got else '  失败'
        print('%s：%s → %s' % (mark, text, got))
        if text not in got:
            ok_b = False

    print('== 结论：Python 侧 %s / Dart 侧 %s ==' % ('OK' if ok_a else 'FAIL',
                                                  'OK' if ok_b else 'FAIL'))
    return 0 if (ok_a and ok_b) else 1


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]
    if cmd == 'gen':
        generate(argv[2] if len(argv) > 2 else REF_WAV)
        return 0
    if cmd == 'decode':
        if len(argv) < 3:
            raise SystemExit('用法：afsk_reference.py decode FILE.wav')
        rate, found = decode_file(argv[2])
        print('%s @ %dHz → %d 帧' % (argv[2], rate, len(found)))
        for line in found:
            print(line)
        return 0 if found else 1
    if cmd == 'verify':
        return verify()
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
