#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""改写碰撞/摔倒说明文案（issue #32 的误报修正），arb 真源 + gen-l10n 产物一起改。

与 `add_l10n_keys.py` 的分工：那个只**加**新键（已存在的跳过），这个只**改值**
（键必须已存在，改 arb 里的 JSON 字符串与生成文件里的 getter 字面量）。两者都幂等。

为什么需要它：判据从「冲击 + 随后静止」改成了「摔倒＝失重+冲击+静止 / 碰撞＝
明显更狠的冲击+静止」，「放手机」不再触发。界面里解释算法的那几段必须跟着改，
否则说的和做的不一致 —— 而这种不一致比不说更糟。

用法：python3 tool/update_crash_l10n.py
"""
import io
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N = os.path.join(ROOT, 'lib', 'l10n')

LANG_FILE = {
    'zh': 'app_zh.arb',
    'zh_TW': 'app_zh_TW.arb',
    'en': 'app_en.arb',
    'ja': 'app_ja.arb',
    'es': 'app_es.arb',
    'id': 'app_id.arb',
}
CLASS = {
    'zh': 'AppLocalizationsZh',
    'zh_TW': 'AppLocalizationsZhTw',
    'en': 'AppLocalizationsEn',
    'ja': 'AppLocalizationsJa',
    'es': 'AppLocalizationsEs',
    'id': 'AppLocalizationsId',
}
# 语言 arb → 生成文件
GEN_FILE = {
    'zh': 'app_localizations_zh.dart',
    'zh_TW': 'app_localizations_zh.dart',
    'en': 'app_localizations_en.dart',
    'ja': 'app_localizations_ja.dart',
    'es': 'app_localizations_es.dart',
    'id': 'app_localizations_id.dart',
}

KEY_ORDER = ('crashHowItWorks', 'crashKindHint', 'crashSensHint',
             'crashAlarmBody', 'crashFallAlarmBody')

# key → (zh, zh_TW, en, ja, es, id)
LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
VALUES = {
    'crashHowItWorks': (
        '判据分两种：**摔倒**要①先有一段自由落体（失重，总加速度接近 0）②落地冲击'
        '③之后连续 12 秒几乎没有运动；**碰撞**没有失重可依据，就要求那次冲击**明显更狠**'
        '（约为灵敏度的两倍），再加「之后连续 12 秒几乎不动」。\n\n'
        '为什么要这些条件：只看一个尖峰的话，**把手机放在桌上稍微使劲、过减速带、甩一甩**'
        '全都算 —— 一天响好几次就没人再看了。区分「摔倒（有失重）」与「碰撞（无失重、要更狠）」'
        '正是为了挡掉「放手机」这类日常动作。代价是**轻微碰撞不会提醒** —— 这个功能的定位是'
        '「人已经动不了了」，不是「发生过撞击」。',
        '判據分兩種：**摔倒**要①先有一段自由落體（失重，總加速度接近 0）②落地衝擊'
        '③之後連續 12 秒幾乎沒有運動；**碰撞**沒有失重可依據，就要求那次衝擊**明顯更狠**'
        '（約為靈敏度的兩倍），再加「之後連續 12 秒幾乎不動」。\n\n'
        '為什麼要這些條件：只看一個尖峰的話，**把手機放在桌上稍微使勁、過減速帶、甩一甩**'
        '全都算 —— 一天響好幾次就沒人再看了。區分「摔倒（有失重）」與「碰撞（無失重、要更狠）」'
        '正是為了擋掉「放手機」這類日常動作。代價是**輕微碰撞不會提醒** —— 這個功能的定位是'
        '「人已經動不了了」，不是「發生過撞擊」。',
        'There are two criteria. A **fall** needs ① a free fall first (weightlessness — total '
        'acceleration near 0), ② a landing impact, and ③ ~12 s of no motion afterwards. A **crash** '
        'has no weightlessness to rely on, so it demands a **much harder** impact (about twice the '
        'sensitivity threshold) plus the same ~12 s of stillness.\n\n'
        'Why all this: on a single spike alone, **setting the phone down a bit firmly, speed bumps, '
        'a shake** all count — and an alert that fires several times a day is one nobody keeps. '
        'Splitting "fall (with weightlessness)" from "crash (no weightlessness, must be harder)" is '
        'exactly what keeps ordinary actions like setting the phone down from triggering. The cost '
        'is that **a light collision does not alert** — this feature is aimed at "the person can no '
        'longer move", not "an impact happened".',
        '判定は二通り。**転倒**は①まず自由落下（無重力 —— 総加速度がほぼ 0）②着地の衝撃'
        '③その後約 12 秒ほぼ動かない、のすべてが必要。**衝突**は無重力の裏付けが無いので、'
        '衝撃が**はっきり強い**こと（おおよそ感度の 2 倍）と、同じく約 12 秒動かないことを求めます。\n\n'
        'なぜここまでするか：尖峰ひとつだけだと**スマホを少し強く置く・段差・振る**が全部該当し、'
        '1 日に何度も鳴る通知は誰も見なくなります。「転倒（無重力あり）」と「衝突（無重力なし・'
        'より強い必要）」を分けるのは、まさに「スマホを置く」ような日常動作を弾くため。代償は'
        '**軽い衝突では通知しない**こと —— この機能は「人がもう動けない」ためのもので、'
        '「衝撃があった」ためのものではありません。',
        'Hay dos criterios. Una **caída** necesita ① una caída libre previa (ingravidez — aceleración '
        'total cercana a 0), ② un impacto de aterrizaje y ③ ~12 s sin movimiento después. Un **choque** '
        'no tiene ingravidez en que apoyarse, así que exige un impacto **mucho más fuerte** (unas dos '
        'veces el umbral de sensibilidad) y la misma quietud de ~12 s.\n\n'
        '¿Por qué tanto? Con un solo pico, **dejar el teléfono un poco fuerte, un badén, sacudirlo** '
        'cuentan todos, y una alerta que suena varias veces al día es una que nadie mira. Separar '
        '«caída (con ingravidez)» de «choque (sin ingravidez, más fuerte)» es justo lo que evita que '
        'acciones cotidianas como dejar el teléfono la disparen. El coste es que **una colisión leve '
        'no avisa** — esta función apunta a «la persona ya no puede moverse», no a «hubo un impacto».',
        'Ada dua kriteria. Sebuah **jatuh** butuh ① jatuh bebas lebih dulu (tanpa bobot — percepatan '
        'total mendekati 0), ② benturan saat mendarat, dan ③ ~12 detik tanpa gerak sesudahnya. Sebuah '
        '**tabrakan** tidak punya tanpa-bobot untuk diandalkan, jadi menuntut benturan yang **jauh '
        'lebih keras** (sekitar dua kali ambang sensitivitas) plus hening ~12 detik yang sama.\n\n'
        'Kenapa sejauh ini: dengan satu lonjakan saja, **meletakkan ponsel agak keras, polisi tidur, '
        'menggoyang** semuanya terhitung — dan peringatan yang berbunyi beberapa kali sehari adalah '
        'yang tak lagi dipedulikan. Memisahkan "jatuh (ada tanpa bobot)" dari "tabrakan (tanpa tanpa '
        'bobot, harus lebih keras)" justru mencegah tindakan sehari-hari seperti meletakkan ponsel '
        'memicunya. Konsekuensinya **tabrakan ringan tidak memberi peringatan** — fitur ini ditujukan '
        'untuk "orang sudah tidak bisa bergerak", bukan "telah terjadi benturan".',
    ),
    'crashKindHint': (
        '会区分**碰撞**与**摔倒**：摔倒几乎总是先有一段自由落体（失重，总加速度接近 0），'
        '再是落地冲击；车祸撞击没有那一段。所以判据是 —— 有失重就按「摔倒」（用灵敏度阈值）；'
        '没有失重就按「碰撞」，并要求冲击约两倍于阈值才认（这样「把手机放在桌上」这类动作'
        '不会误报）。这只是把判断说得更准，两类的处理方式完全一样（都是我没事 / 打电话 / 求助）。',
        '會區分**碰撞**與**摔倒**：摔倒幾乎總是先有一段自由落體（失重，總加速度接近 0），'
        '再是落地衝擊；車禍撞擊沒有那一段。所以判據是 —— 有失重就按「摔倒」（用靈敏度閾值）；'
        '沒有失重就按「碰撞」，並要求衝擊約兩倍於閾值才認（這樣「把手機放在桌上」這類動作'
        '不會誤報）。這只是把判斷說得更準，兩類的處理方式完全一樣（都是我沒事 / 打電話 / 求助）。',
        'It distinguishes a **crash** from a **fall**: a fall almost always starts with a free fall '
        '(weightlessness — total acceleration near 0) before the landing impact, whereas a vehicle '
        'crash does not. The rule is therefore: with weightlessness, label it a **fall** (use the '
        'sensitivity threshold); without it, label it a **crash** and require an impact about twice '
        'the threshold (so actions like setting the phone down do not false-alarm). This only makes '
        'the wording more accurate — both are handled exactly the same (I am fine / call / ask for '
        'help).',
        '**衝突**と**転倒**を区別します：転倒はほぼ必ず自由落下（無重力 —— 総加速度がほぼ 0）の後に'
        '着地衝撃が来ますが、車の衝突にはそれがありません。したがって判定は —— 無重力があれば'
        '「転倒」（感度の閾値を使用）、無ければ「衝突」とし、閾値の約 2 倍の衝撃を要求します'
        '（これにより「スマホを置く」などの動作は誤報しません）。これは判定をより正確に述べる'
        'だけで、両者の扱いはまったく同じです（大丈夫 / 電話 / 救助要請）。',
        'Distingue un **choque** de una **caída**: una caída casi siempre empieza con una caída libre '
        '(ingravidez — aceleración total cercana a 0) antes del impacto de aterrizaje, mientras que un '
        'choque de vehículo no. La regla es: con ingravidez, «caída» (usa el umbral de sensibilidad); '
        'sin ella, «choque» y exige un impacto de unas dos veces el umbral (así acciones como dejar '
        'el teléfono no se disparan). Esto solo hace más preciso el texto: ambos se tratan igual '
        '(estoy bien / llamar / pedir ayuda).',
        'Membedakan **tabrakan** dari **jatuh**: jatuh hampir selalu diawali jatuh bebas (tanpa bobot '
        '— percepatan total mendekati 0) sebelum benturan mendarat, sedangkan tabrakan kendaraan '
        'tidak. Jadi aturannya: bila ada tanpa bobot, sebut **jatuh** (pakai ambang sensitivitas); '
        'bila tidak, sebut **tabrakan** dan tuntut benturan sekitar dua kali ambang (sehingga '
        'tindakan seperti meletakkan ponsel tidak salah peringatan). Ini hanya membuat penyebutan '
        'lebih akurat — keduanya ditangani sama (saya baik-baik saja / telepon / minta bantuan).',
    ),
    'crashSensHint': (
        '灵敏度决定「多大的冲击才算数」：摔倒按此阈值，碰撞则要求约两倍。手机放裤兜里骑车，'
        '正常颠簸就用「抗颠簸」；固定在车把上同理。默认「标准」。灵敏度只影响**检测**'
        '（哪个撞击算数），不影响后续的告警动作。',
        '靈敏度決定「多大的衝擊才算數」：摔倒按此閾值，碰撞則要求約兩倍。手機放褲袋騎車，'
        '正常顛簸就用「抗顛簸」；固定在車把上同理。預設「標準」。靈敏度只影響**偵測**'
        '（哪個撞擊算數），不影響後續的告警動作。',
        'Sensitivity decides how strong an impact counts: a fall uses this threshold, a crash '
        'demands about twice it. Cycling with the phone in a pocket — use Firm; so does a bar mount. '
        'Default is Standard. Sensitivity only affects **detection** (which impact counts), not what '
        'the alarm does.',
        '感度は「どれだけ強い衝撃を数えるか」を決めます：転倒はこの閾値、衝突は約 2 倍を要求します。'
        'ポケットに入れて自転車に乗るなら「強い（firm）」、ハンドル固定も同様。既定は「標準」。'
        '感度は**検出**（どの衝撃を数えるか）だけに影響し、その後の警報動作には影響しません。',
        'La sensibilidad decide qué impacto cuenta: una caída usa este umbral, un choque exige unas '
        'dos veces más. En bici con el teléfono en el bolsillo usa Firme; igual con soporte de '
        'manillar. Por defecto, Estándar. La sensibilidad solo afecta a la **detección** (qué impacto '
        'cuenta), no a lo que hace la alerta.',
        'Sensitivitas menentukan seberapa kuat benturan yang dihitung: jatuh memakai ambang ini, '
        'tabrakan menuntut sekitar dua kalinya. Bersepeda dengan ponsel di kantong — pakai Kuat; '
        'begitu pula pemasangan di stang. Bawaan Standar. Sensitivitas hanya memengaruhi **deteksi** '
        '(benturan mana yang dihitung), bukan tindakan alarmnya.',
    ),
    'crashAlarmBody': (
        '手机检测到一次强烈的冲击，之后一直没有明显移动（约 12 秒）。\n\n'
        '如果你没事，按「我没事」即可；如果身体不适或无法行动，请立即拨打急救电话，'
        '或向附近 100 公里内的台站发出求助信息。\n\n'
        '**这是启发式判断，不是工程级碰撞检测**。',
        '手機偵測到一次強烈的衝擊，之後一直沒有明顯移動（約 12 秒）。\n\n'
        '如果你沒事，按「我沒事」即可；如果身體不適或無法行動，請立即撥打急救電話，'
        '或向附近 100 公里內的臺站發出求助訊息。\n\n'
        '**這是啟發式判斷，不是工程級碰撞偵測**。',
        'The phone detected a strong impact, and there has been no clear movement for about 12 '
        'seconds since.\n\n'
        'If you are fine, just tap "I am fine". If you feel unwell or cannot move, call emergency '
        'services now, or send a help message to stations within 100 km.\n\n'
        '**This is a heuristic judgement, not engineering-grade crash detection**.',
        'スマホが強い衝撃を検出し、その後およそ 12 秒間はっきりした動きがありません。\n\n'
        '問題なければ「大丈夫」を押してください。体調が悪い、または動けない場合は、すぐに救急へ'
        '電話するか、100km 以内の局へ救助メッセージを送ってください。\n\n'
        '**これはヒューリスティックな判定で、工学レベルの衝突検出ではありません**。',
        'El teléfono detectó un impacto fuerte y no ha habido movimiento claro durante unos 12 '
        'segundos.\n\n'
        'Si estás bien, pulsa «Estoy bien». Si te encuentras mal o no puedes moverte, llama ya a '
        'emergencias, o envía un mensaje de ayuda a las estaciones en 100 km.\n\n'
        '**Esto es un juicio heurístico, no detección de choques de nivel ingenieril**.',
        'Ponsel mendeteksi benturan keras, dan tidak ada gerakan jelas selama sekitar 12 detik '
        'sesudahnya.\n\n'
        'Jika Anda baik-baik saja, cukup ketuk "Saya baik-baik saja". Jika merasa tidak enak badan '
        'atau tidak bisa bergerak, segera hubungi layanan darurat, atau kirim pesan minta bantuan ke '
        'stasiun dalam 100 km.\n\n'
        '**Ini penilaian heuristik, bukan deteksi tabrakan sekelas rekayasa**.',
    ),
    'crashFallAlarmBody': (
        '手机先自由落体、随后一次落地冲击，再之后一直没有明显移动（约 12 秒）—— '
        '这是摔倒的典型加速度特征。\n\n'
        '如果你没事，按「我没事」即可；如果身体不适或无法行动，请立即拨打急救电话，'
        '或向附近 100 公里内的台站发出求助信息。\n\n'
        '**这是启发式判断，不是工程级检测**。',
        '手機先自由落體、隨後一次落地衝擊，再之後一直沒有明顯移動（約 12 秒）—— '
        '這是摔倒的典型加速度特徵。\n\n'
        '如果你沒事，按「我沒事」即可；如果身體不適或無法行動，請立即撥打急救電話，'
        '或向附近 100 公里內的臺站發出求助訊息。\n\n'
        '**這是啟發式判斷，不是工程級偵測**。',
        'The phone free-fell, then took a landing impact, and has shown no clear movement since for '
        'about 12 seconds — the typical acceleration signature of a fall.\n\n'
        'If you are fine, just tap "I am fine". If you feel unwell or cannot move, call emergency '
        'services now, or send a help message to stations within 100 km.\n\n'
        '**This is a heuristic judgement, not engineering-grade detection**.',
        'スマホが自由落下した後に着地の衝撃を受け、その後およそ 12 秒間はっきりした動きが'
        'ありません —— 転倒に典型的な加速度の特徴です。\n\n'
        '問題なければ「大丈夫」を押してください。体調が悪い、または動けない場合は、すぐに救急へ'
        '電話するか、100km 以内の局へ救助メッセージを送ってください。\n\n'
        '**これはヒューリスティックな判定で、工学レベルの検出ではありません**。',
        'El teléfono cayó libremente, luego recibió un impacto de aterrizaje y desde entonces no '
        'muestra movimiento claro durante unos 12 segundos — la firma de aceleración típica de una '
        'caída.\n\n'
        'Si estás bien, pulsa «Estoy bien». Si te encuentras mal o no puedes moverte, llama ya a '
        'emergencias, o envía un mensaje de ayuda a las estaciones en 100 km.\n\n'
        '**Esto es un juicio heurístico, no detección de nivel ingenieril**.',
        'Ponsel jatuh bebas, lalu menerima benturan mendarat, dan sejak itu tidak ada gerakan jelas '
        'selama sekitar 12 detik — ciri percepatan khas sebuah jatuh.\n\n'
        'Jika Anda baik-baik saja, cukup ketuk "Saya baik-baik saja". Jika merasa tidak enak badan '
        'atau tidak bisa bergerak, segera hubungi layanan darurat, atau kirim pesan minta bantuan ke '
        'stasiun dalam 100 km.\n\n'
        '**Ini penilaian heuristik, bukan deteksi sekelas rekayasa**.',
    ),
}


def read(p):
    return io.open(p, encoding='utf-8', newline='').read()


def write(p, s):
    io.open(p, 'w', encoding='utf-8', newline='').write(s)


def update_arb(text, key, value):
    # JSON 字符串可含转义引号，故按「首个非转义结束引号」匹配。
    pat = re.compile(r'("%s"\s*:\s*)("(?:[^"\\]|\\.)*")' % re.escape(key))
    lit = json.dumps(value, ensure_ascii=False)
    m = pat.search(text)
    if not m:
        return text, False
    if m.group(2) == lit:
        return text, True
    return text[:m.start(2)] + lit + text[m.end(2):], True


def update_dart(text, key, value):
    # 只改有 `=>` 的 getter（抽象类里的声明没有）。
    # 用 json.dumps 生成字面量内容，这样换行/引号都按 Dart 单引号串转义（`\n` 等），
    # 再从双引号串转成单引号串；否则多行文案会被写成**真实的换行**，Dart 直接语法错误。
    j = json.dumps(value, ensure_ascii=False)[1:-1]  # 去掉外层双引号
    j = j.replace('\\"', '"')      # 单引号串里不需要转义双引号
    lit = "'" + j.replace('$', r'\$').replace("'", r"\'") + "'"
    # 允许旧字面量跨多行（`[^'\\]` 含换行），这样即使上一次写坏了也能修回来。
    pat = re.compile(r"(?m)^(\s*String get %s => )'(?:[^'\\]|\\.)*';" % re.escape(key))
    m = pat.search(text)
    if not m:
        return text, False
    line = m.group(1) + lit + ';'
    if m.group(0) == line:
        return text, True
    return text[:m.start()] + line + text[m.end():], True


def main():
    bad = []
    for key in KEY_ORDER:
        vals = VALUES[key]
        for i, lang in enumerate(LANGS):
            arb_path = os.path.join(L10N, LANG_FILE[lang])
            t, ok = update_arb(read(arb_path), key, vals[i])
            if not ok:
                bad.append('%s@%s (arb)' % (key, lang))
                continue
            write(arb_path, t)

            gen_path = os.path.join(L10N, GEN_FILE[lang])
            g, ok2 = update_dart(read(gen_path), key, vals[i])
            if not ok2:
                bad.append('%s@%s (%s)' % (key, lang, GEN_FILE[lang]))
                continue
            write(gen_path, g)
            print('  %-22s %-6s ok' % (key, lang))
    if bad:
        print('缺失：' + ', '.join(bad))
        raise SystemExit(1)
    print('全部更新完成。')


if __name__ == '__main__':
    main()
