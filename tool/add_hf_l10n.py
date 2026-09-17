#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""注入「短波传播 / 电离层」相关文案（6 语言）。

背景：新增短波传播数据（hamqsl.com），面板要显示逐波段条件与 SFI/K/A 等指标，
无线电建议也要根据电离层状态调整。这里集中注入这批文案。

约定与 tool/add_beacon_rf_l10n.py 一致：按锚点键插入，六语言同批写；
**不带占位符**的键不写 `@key` 元数据（生成器会自动推断为纯字符串），
带占位符的（hfTipBandGood / hfTipBandPoor）必须写元数据，否则代码生成会报错。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 纯字符串键（无占位符）
DATA = {
    'hfTitle': {
        'zh': '短波传播', 'zh_TW': '短波傳播', 'en': 'HF propagation',
        'ja': 'HF 伝搬', 'id': 'Propagasi HF', 'es': 'Propagación HF',
    },
    'hfBand': {
        'zh': '波段', 'zh_TW': '波段', 'en': 'Band',
        'ja': 'バンド', 'id': 'Band', 'es': 'Banda',
    },
    'hfDay': {
        'zh': '日间', 'zh_TW': '日間', 'en': 'Day',
        'ja': '昼', 'id': 'Siang', 'es': 'Día',
    },
    'hfNight': {
        'zh': '夜间', 'zh_TW': '夜間', 'en': 'Night',
        'ja': '夜', 'id': 'Malam', 'es': 'Noche',
    },
    'hfSfi': {
        'zh': '太阳通量', 'zh_TW': '太陽通量', 'en': 'Solar flux',
        'ja': '太陽フラックス', 'id': 'Fluks surya', 'es': 'Flujo solar',
    },
    'hfKp': {
        'zh': '地磁 Kp', 'zh_TW': '地磁 Kp', 'en': 'Kp index',
        'ja': 'Kp 指数', 'id': 'Indeks Kp', 'es': 'Índice Kp',
    },
    'hfAIndex': {
        'zh': 'A 指数', 'zh_TW': 'A 指數', 'en': 'A index',
        'ja': 'A 指数', 'id': 'Indeks A', 'es': 'Índice A',
    },
    'hfSunspots': {
        'zh': '太阳黑子', 'zh_TW': '太陽黑子', 'en': 'Sunspots',
        'ja': '黒点数', 'id': 'Bintik matahari', 'es': 'Manchas solares',
    },
    'hfXray': {
        'zh': 'X 射线', 'zh_TW': 'X 射線', 'en': 'X-ray',
        'ja': 'X 線', 'id': 'Sinar-X', 'es': 'Rayos X',
    },
    'hfSolarWind': {
        'zh': '太阳风速', 'zh_TW': '太陽風速', 'en': 'Solar wind',
        'ja': '太陽風', 'id': 'Angin surya', 'es': 'Viento solar',
    },
    'hfGeomag': {
        'zh': '地磁', 'zh_TW': '地磁', 'en': 'Geomag',
        'ja': '地磁気', 'id': 'Geomag', 'es': 'Geomag',
    },
    'hfNoise': {
        'zh': '底噪', 'zh_TW': '底噪', 'en': 'Noise',
        'ja': 'ノイズ', 'id': 'Derau', 'es': 'Ruido',
    },
    'hfMuf': {
        'zh': '最高可用频率', 'zh_TW': '最高可用頻率', 'en': 'MUF',
        'ja': 'MUF', 'id': 'MUF', 'es': 'MUF',
    },
    'hfNoData': {
        'zh': '暂无短波传播数据：联网后自动获取',
        'zh_TW': '暫無短波傳播資料：連網後自動取得',
        'en': 'No HF data yet — it loads automatically when online',
        'ja': 'HF 伝搬データがありません（オンライン時に自動取得します）',
        'id': 'Belum ada data HF — dimuat otomatis saat daring',
        'es': 'Aún no hay datos de HF: se cargan al conectarse',
    },
    'hfUnavailable': {
        'zh': '短波传播服务暂时不可用',
        'zh_TW': '短波傳播服務暫時無法使用',
        'en': 'HF propagation service is unavailable',
        'ja': 'HF 伝搬サービスを利用できません',
        'id': 'Layanan propagasi HF tidak tersedia',
        'es': 'El servicio de propagación HF no está disponible',
    },
    'hfQGood': {
        'zh': '好', 'zh_TW': '好', 'en': 'Good', 'ja': '良好',
        'id': 'Bagus', 'es': 'Buena',
    },
    'hfQFair': {
        'zh': '一般', 'zh_TW': '一般', 'en': 'Fair', 'ja': '普通',
        'id': 'Sedang', 'es': 'Regular',
    },
    'hfQPoor': {
        'zh': '差', 'zh_TW': '差', 'en': 'Poor', 'ja': '不良',
        'id': 'Buruk', 'es': 'Mala',
    },
    'hfQClosed': {
        'zh': '关闭', 'zh_TW': '關閉', 'en': 'Closed', 'ja': 'クローズ',
        'id': 'Tutup', 'es': 'Cerrada',
    },
    'hfPowered': {
        'zh': '传播数据由 hamqsl.com（N0NBH）提供 · 全球平均，非本地实测',
        'zh_TW': '傳播資料由 hamqsl.com（N0NBH）提供 · 全球平均，非本地實測',
        'en': 'Propagation data by hamqsl.com (N0NBH) · global average, not local measurement',
        'ja': '伝搬データ: hamqsl.com（N0NBH）· 全球平均であり現地実測ではありません',
        'id': 'Data propagasi oleh hamqsl.com (N0NBH) · rata-rata global, bukan pengukuran lokal',
        'es': 'Datos de propagación de hamqsl.com (N0NBH) · promedio global, no medición local',
    },
    # ── 建议文案 ──
    'hfTipStorm': {
        'zh': '地磁暴（Kp≥5）：极区短波路径衰减明显，跨极地 DX 基本中断；改走低纬度路径或转本地 VHF/UHF',
        'zh_TW': '地磁暴（Kp≥5）：極區短波路徑衰減明顯，跨極地 DX 幾乎中斷；改走低緯度路徑或轉本地 VHF/UHF',
        'en': 'Geomagnetic storm (Kp≥5): polar HF paths fade badly and trans-polar DX is largely gone — try lower-latitude paths or local VHF/UHF',
        'ja': '地磁気嵐（Kp≥5）：極域の HF 伝搬は大きく減衰し、極横断 DX はほぼ途絶えます。低緯度経路かローカル VHF/UHF へ',
        'id': 'Badai geomagnetik (Kp≥5): jalur HF kutub meredup parah dan DX lintas kutub hampir hilang — coba jalur lintang rendah atau VHF/UHF lokal',
        'es': 'Tormenta geomagnética (Kp≥5): las rutas HF polares se atenúan mucho y el DX transpolar casi desaparece; pruebe rutas de menor latitud o VHF/UHF local',
    },
    'hfTipGeomagActive': {
        'zh': '地磁较活跃：短波高纬度路径不如平时稳定，DX 通联建议留出更多呼叫时间',
        'zh_TW': '地磁較活躍：短波高緯度路徑不如平時穩定，DX 通聯建議留出更多呼叫時間',
        'en': 'Geomagnetic field is unsettled: high-latitude HF paths are less stable than usual — allow more calling time for DX',
        'ja': '地磁気がやや乱れています：高緯度の HF 伝搬は普段より不安定です。DX は呼び出し時間を多めに',
        'id': 'Medan geomagnetik tidak tenang: jalur HF lintang tinggi kurang stabil — beri waktu panggil lebih lama untuk DX',
        'es': 'Campo geomagnético inquieto: las rutas HF de alta latitud son menos estables; dé más tiempo de llamada al DX',
    },
    'hfTipLowSfi': {
        'zh': '太阳活动偏低（SFI<100）：白天高波段（15m/12m/10m）机会少，优先 40m/30m/20m',
        'zh_TW': '太陽活動偏低（SFI<100）：白天高頻段（15m/12m/10m）機會少，優先 40m/30m/20m',
        'en': 'Low solar activity (SFI<100): little daytime life on 15/12/10m — favour 40/30/20m',
        'ja': '太陽活動が低調（SFI<100）：昼間の 15/12/10m は期待薄。40/30/20m を優先',
        'id': 'Aktivitas surya rendah (SFI<100): 15/12/10m siang kurang hidup — utamakan 40/30/20m',
        'es': 'Actividad solar baja (SFI<100): poca vida diurna en 15/12/10m; prefiera 40/30/20m',
    },
    'hfTipHighSfi': {
        'zh': '太阳活动活跃（SFI≥150）：白天高波段（15m/12m/10m）有机会远距离 DX',
        'zh_TW': '太陽活動活躍（SFI≥150）：白天高頻段（15m/12m/10m）有機會遠距離 DX',
        'en': 'Solar activity is high (SFI≥150): daytime 15/12/10m should open for long-distance DX',
        'ja': '太陽活動が活発（SFI≥150）：昼間の 15/12/10m で遠距離 DX の見込み',
        'id': 'Aktivitas surya tinggi (SFI≥150): 15/12/10m siang berpeluang DX jarak jauh',
        'es': 'Actividad solar alta (SFI≥150): 15/12/10m diurnas deberían abrir para DX de larga distancia',
    },
    'hfTipHighNoise': {
        'zh': '底噪偏高：弱信号接收困难，建议收窄带宽、降低前置增益，必要时用窄带模式',
        'zh_TW': '底噪偏高：弱信號接收困難，建議收窄頻寬、降低前置增益，必要時用窄帶模式',
        'en': 'High noise floor: weak signals are hard to copy — narrow the bandwidth, reduce RF gain, use narrow modes if needed',
        'ja': 'ノイズフロアが高い：弱い信号は取りにくいです。帯域を狭め、RF ゲインを下げ、必要なら狭帯域モードで',
        'id': 'Derau tinggi: sinyal lemah sulit disalin — persempit bandwidth, turunkan gain RF, pakai mode sempit bila perlu',
        'es': 'Ruido de fondo alto: las señales débiles cuestan; reduzca el ancho de banda y la ganancia de RF, use modos estrechos si hace falta',
    },
}

# 带占位符的键（需要 @key 元数据）
DATA_PARAM = {
    'hfTipBandGood': {
        'zh': '{b} 传播条件好：本时段优先用这一段呼叫',
        'zh_TW': '{b} 傳播條件好：本時段優先使用這一段呼叫',
        'en': '{b} is open: favour this band for calling right now',
        'ja': '{b} の伝搬が良好：今はこのバンドを優先',
        'id': '{b} terbuka: utamakan band ini untuk memanggil',
        'es': '{b} está abierta: prefiera esta banda para llamar',
    },
    'hfTipBandPoor': {
        'zh': '{b} 条件偏差：换到其它波段，或等日落/日出灰线再试',
        'zh_TW': '{b} 條件偏差：換到其他波段，或等日落/日出灰線再試',
        'en': '{b} is poor: try another band, or wait for the sunrise/sunset gray line',
        'ja': '{b} の伝搬が不良：別のバンドへ、または日の出・日の入りのグレーライン待ち',
        'id': '{b} buruk: coba band lain, atau tunggu garis kelabu fajar/senja',
        'es': '{b} está mala: pruebe otra banda o espere la línea gris de amanecer/atardecer',
    },
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"weatherPowered"'


def main():
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        text = io.open(path, encoding='utf-8').read()
        lines = text.split('\n')

        # 先删掉旧版本（可重复执行）
        allkeys = list(DATA) + list(DATA_PARAM)
        out = []
        skip = None
        for ln in lines:
            st = ln.strip()
            if skip is not None:
                # 跳过紧跟的 @key 元数据块（到该键的闭合大括号）
                if st == '},' or st == '}':
                    skip = None
                continue
            if any(st.startswith('"%s"' % k) for k in allkeys):
                if st.endswith(': {'):
                    skip = True
                continue
            out.append(ln)
        lines = out

        idx = None
        for i, ln in enumerate(lines):
            if ln.strip().startswith(ANCHOR):
                idx = i
                break
        assert idx is not None, 'anchor not found in %s' % path

        block = []
        for k, v in DATA.items():
            block.append('  "%s": %s,' % (k, json.dumps(v[lang], ensure_ascii=False)))
        for k, v in DATA_PARAM.items():
            block.append('  "%s": %s,' % (k, json.dumps(v[lang], ensure_ascii=False)))
            block.append('  "@%s": {' % k)
            block.append('    "placeholders": {')
            block.append('      "b": {')
            block.append('        "type": "String"')
            block.append('      }')
            block.append('    }')
            block.append('  },')
        # 插在锚点键所在行之后
        lines[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))

        d = json.loads(io.open(path, encoding='utf-8').read())
        n = len([k for k in d if not k.startswith('@')])
        print('%s ok, %d keys (+%d)' % (path, n, len(allkeys)))


if __name__ == '__main__':
    main()
