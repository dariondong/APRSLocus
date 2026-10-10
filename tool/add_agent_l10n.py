#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""注入「智能体模式（AI Agent）」相关文案（6 语言）。

背景：实验功能里新增「智能体模式」—— 用户自行配置接口 Key（OpenAI 兼容），
屏幕上出现一个 AI 聊天框；智能体可以通过工具调用帮用户改设置、发消息、
查台站。开关、聊天框、设置页、操作确认框的文案都在这里补齐。

产物与 add_icom_wlan_l10n.py 同一套路数（arb 真源 + 抽象类 + 6 个 gen-l10n 产物）。

用法：python3 tool/add_agent_l10n.py
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {l: i for i, l in enumerate(LANGS)}
CLASSES = {
    'zh': 'AppLocalizationsZh', 'zh_TW': 'AppLocalizationsZhTw',
    'en': 'AppLocalizationsEn', 'ja': 'AppLocalizationsJa',
    'es': 'AppLocalizationsEs', 'id': 'AppLocalizationsId',
}

# key → (zh, zh_TW, en, ja, es, id)
DATA = {
    'agentMode': ('智能体模式', '智慧代理模式', 'Agent mode', 'エージェントモード',
                  'Modo agente', 'Mode agen'),
    'agentModeDesc': (
        '开启后屏幕上出现一个 AI 聊天框，可以对话让它帮你改设置、发消息、查台站（需自行配置接口 Key）',
        '開啟後螢幕上出現一個 AI 聊天框，可對話讓它幫你改設定、發訊息、查台站（需自行設定介面 Key）',
        'Shows an AI chat box that can change settings, send messages and look up stations (bring your own API key)',
        'AI チャットボックスを表示します。設定変更・メッセージ送信・局検索を会話で行えます（API キーはご自身で用意）',
        'Muestra un chat de IA que puede cambiar ajustes, enviar mensajes y buscar estaciones (con tu propia clave de API)',
        'Menampilkan kotak obrolan AI untuk mengubah setelan, mengirim pesan, dan mencari stasiun (bawa kunci API sendiri)'),
    'agentSettings': ('智能体设置', '智慧代理設定', 'Agent settings', 'エージェント設定',
                      'Ajustes del agente', 'Setelan agen'),
    'agentSettingsDesc': (
        '接口地址 / Key / 模型，以及允许智能体执行哪些操作',
        '介面網址 / Key / 模型，以及允許智慧代理執行哪些操作',
        'API base URL / key / model, and which actions the agent may perform',
        'API のベース URL / キー / モデルと、エージェントに許可する操作',
        'URL base / clave / modelo de la API y qué acciones puede realizar el agente',
        'URL dasar / kunci / model API dan tindakan yang diizinkan untuk agen'),
    'agentEnabled': ('启用智能体', '啟用智慧代理', 'Enable agent', 'エージェントを有効化',
                     'Activar agente', 'Aktifkan agen'),
    'agentBaseUrl': ('接口地址 (Base URL)', '介面網址 (Base URL)', 'API base URL', 'API ベース URL',
                     'URL base de la API', 'URL dasar API'),
    'agentApiKey': ('接口 Key (API Key)', '介面 Key (API Key)', 'API key', 'API キー',
                    'Clave de API', 'Kunci API'),
    'agentModel': ('模型', '模型', 'Model', 'モデル', 'Modelo', 'Model'),
    'agentPreset': ('预设', '預設', 'Preset', 'プリセット', 'Preajuste', 'Preset'),
    'agentPresetCustom': ('自定义', '自訂', 'Custom', 'カスタム', 'Personalizado', 'Kustom'),
    'agentSystemPrompt': ('系统提示词（可选）', '系統提示詞（選填）', 'System prompt (optional)',
                          'システムプロンプト（任意）', 'Prompt del sistema (opcional)',
                          'Prompt sistem (opsional)'),
    'agentAllowSend': ('允许发送消息', '允許傳送訊息', 'Allow sending messages',
                       'メッセージ送信を許可', 'Permitir enviar mensajes', 'Izinkan mengirim pesan'),
    'agentAllowSendDesc': ('允许智能体代为发送私信、群消息与信标', '允許智慧代理代為傳送私訊、群訊息與信標',
                           'Let the agent send direct messages, group messages and beacons',
                           'エージェントに DM・グループメッセージ・ビーコンの送信を許可',
                           'Permite al agente enviar mensajes directos, de grupo y balizas',
                           'Izinkan agen mengirim pesan langsung, grup, dan beacon'),
    'agentAllowSettings': ('允许修改设置', '允許修改設定', 'Allow changing settings',
                           '設定変更を許可', 'Permitir cambiar ajustes', 'Izinkan mengubah setelan'),
    'agentAllowSettingsDesc': ('允许智能体修改应用设置（关闭后仅可查看）', '允許智慧代理修改應用設定（關閉後僅可檢視）',
                               'Let the agent change app settings (off = read-only)',
                               'エージェントにアプリ設定の変更を許可（オフ＝閲覧のみ）',
                               'Permite al agente cambiar ajustes (desactivado = solo lectura)',
                               'Izinkan agen mengubah setelan (mati = hanya baca)'),
    'agentTest': ('测试连接', '測試連線', 'Test connection', '接続テスト',
                  'Probar conexión', 'Uji koneksi'),
    'agentTesting': ('正在测试…', '正在測試…', 'Testing…', 'テスト中…', 'Probando…', 'Menguji…'),
    'agentTestOk': ('连接成功：{model}', '連線成功：{model}', 'Connected: {model}',
                    '接続に成功しました：{model}', 'Conexión correcta: {model}',
                    'Berhasil tersambung: {model}'),
    'agentNeedConfig': ('请先填写接口地址、Key 和模型', '請先填寫介面網址、Key 和模型',
                        'Please fill in the API base URL, key and model',
                        'API ベース URL・キー・モデルを入力してください',
                        'Rellena la URL base, la clave y el modelo de la API',
                        'Isi URL dasar, kunci, dan model API'),
    'agentChatTitle': ('智能体助手', '智慧代理助手', 'Agent assistant', 'エージェントアシスタント',
                       'Asistente de IA', 'Asisten agen'),
    'agentInputHint': ('告诉智能体你想做什么…', '告訴智慧代理你想做什麼…', 'Tell the agent what to do…',
                       'エージェントに依頼を入力…', 'Dile al agente qué hacer…', 'Beri tahu agen apa yang harus dilakukan…'),
    'agentSend': ('发送', '傳送', 'Send', '送信', 'Enviar', 'Kirim'),
    'agentClear': ('清空对话', '清除對話', 'Clear chat', '会話を消去', 'Borrar chat', 'Hapus obrolan'),
    'agentClearConfirm': ('确定清空当前对话？', '確定清除目前對話？', 'Clear this conversation?',
                          'この会話を消去しますか？', '¿Borrar esta conversación?',
                          'Hapus percakapan ini?'),
    'agentWelcome': (
        '你好，我是 APRSLocus 的智能体助手。你可以让我帮你改设置、发送消息、查看台站。请先在「智能体设置」里配置接口 Key。',
        '你好，我是 APRSLocus 的智慧代理助手。你可以讓我幫你改設定、傳送訊息、查看台站。請先在「智慧代理設定」裡設定介面 Key。',
        'Hi, I am the APRSLocus agent assistant. Ask me to change settings, send messages or look up stations. Please set your API key in “Agent settings” first.',
        'こんにちは。APRSLocus のエージェントアシスタントです。設定変更・メッセージ送信・局検索を依頼できます。まず「エージェント設定」で API キーを設定してください。',
        'Hola, soy el asistente de IA de APRSLocus. Pídeme cambiar ajustes, enviar mensajes o buscar estaciones. Configura tu clave de API en «Ajustes del agente».',
        'Hai, saya asisten agen APRSLocus. Minta saya mengubah setelan, mengirim pesan, atau mencari stasiun. Atur kunci API di "Setelan agen" dulu.'),
    'agentThinking': ('思考中…', '思考中…', 'Thinking…', '考えています…', 'Pensando…', 'Berpikir…'),
    'agentError': ('出错了：{msg}', '發生錯誤：{msg}', 'Error: {msg}', 'エラー：{msg}',
                   'Error: {msg}', 'Kesalahan: {msg}'),
    'agentConfirmTitle': ('智能体请求执行操作', '智慧代理請求執行操作', 'The agent wants to run an action',
                          'エージェントが操作を要求しています', 'El agente quiere ejecutar una acción',
                          'Agen ingin menjalankan tindakan'),
    'agentConfirmRun': ('允许', '允許', 'Allow', '許可', 'Permitir', 'Izinkan'),
    'agentConfirmDeny': ('拒绝', '拒絕', 'Deny', '拒否', 'Denegar', 'Tolak'),
    'agentDenied': ('已拒绝该操作', '已拒絕該操作', 'Action denied', '操作を拒否しました',
                    'Acción denegada', 'Tindakan ditolak'),
    'agentExecuted': ('已执行', '已執行', 'Done', '実行しました', 'Hecho', 'Selesai'),
    'agentToolResult': ('工具结果', '工具結果', 'Tool result', 'ツール結果', 'Resultado', 'Hasil alat'),
    'agentStopped': ('已停止', '已停止', 'Stopped', '停止しました', 'Detenido', 'Dihentikan'),
    'agentStop': ('停止', '停止', 'Stop', '停止', 'Detener', 'Hentikan'),
    'agentOpenSettings': ('智能体设置', '智慧代理設定', 'Agent settings', 'エージェント設定',
                          'Ajustes del agente', 'Setelan agen'),
    'agentNeedsEnable': ('请先在实验功能中开启「智能体模式」', '請先在實驗功能中開啟「智慧代理模式」',
                         'Enable “Agent mode” in Lab features first', 'まず実験機能で「エージェントモード」を有効にしてください',
                         'Activa «Modo agente» en Funciones de laboratorio primero',
                         'Aktifkan "Mode agen" di fitur Lab dulu'),
    'agentToolCalling': ('正在执行：{name}', '正在執行：{name}', 'Running: {name}',
                         '実行中：{name}', 'Ejecutando: {name}', 'Menjalankan: {name}'),
    'agentMinimize': ('收起', '收合', 'Minimize', '最小化', 'Minimizar', 'Perkecil'),
    'agentApiKeyTip': (
        'Key 只保存在本机，不会上传到任何 APRSlocus 服务器。',
        'Key 只保存在本機，不會上傳到任何 APRSlocus 伺服器。',
        'The key is stored on this device only and is never sent to any APRSlocus server.',
        'キーは本端末にのみ保存され、APRSlocus のサーバーには送信されません。',
        'La clave se guarda solo en este dispositivo y nunca se envía a los servidores de APRSlocus.',
        'Kunci hanya disimpan di perangkat ini dan tidak pernah dikirim ke server APRSlocus.'),
    'agentPresetHint': ('快速填充接口与模型', '快速填入介面與模型',
                        'Quickly fill the API URL and model', 'API URL とモデルをすばやく入力',
                        'Rellena rápidamente la URL y el modelo', 'Isi cepat URL dan model API'),
    'agentInterfaceSection': ('接口配置', '介面設定', 'API configuration', 'API 設定',
                              'Configuración de la API', 'Konfigurasi API'),
    'agentPermissions': ('权限', '權限', 'Permissions', '権限', 'Permisos', 'Izin'),
}
META = {
    'agentTestOk': '{"placeholders": {"model": {"type": "String"}}}',
    'agentError': '{"placeholders": {"msg": {"type": "String"}}}',
    'agentToolCalling': '{"placeholders": {"name": {"type": "String"}}}',
}

ANCHOR = '"codeContributionTranslation"'


def _params(key):
    raw = META.get(key)
    if not raw:
        return []
    return list(json.loads(raw).get('placeholders', {}).keys())


def member(key):
    ps = _params(key)
    if not ps:
        return 'get %s' % key
    return '%s(%s)' % (key, ', '.join('String ' + x for x in ps))


def interp(key, text):
    for x in _params(key):
        text = text.replace('{%s}' % x, '$%s' % x)
    return text


def class_body(src, name):
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        raise SystemExit('找不到类 ' + name)
    j = src.find('\n}\n', m.end())
    if j < 0:
        j = src.rfind('\n}')
    return m.end(), j


def main():
    for lg in LANGS:
        p = os.path.join(ROOT, 'lib', 'l10n', 'app_%s.arb' % lg)
        lines = io.open(p, encoding='utf-8').read().split('\n')
        out = [ln for ln in lines
               if not any(ln.strip().startswith('"%s"' % k) for k in DATA)]
        lines = out
        idx = next((i for i, ln in enumerate(lines)
                    if ln.strip().startswith(ANCHOR)), None)
        assert idx is not None, 'anchor not found in %s' % p
        block = []
        for k, v in DATA.items():
            block.append('  "%s": %s,' % (k, json.dumps(v[IDX[lg]], ensure_ascii=False)))
        for k, m in META.items():
            block.append('  "%s": %s,' % ('@' + k, m))
        lines[idx:idx] = block
        io.open(p, 'w', encoding='utf-8').write('\n'.join(lines))
        json.load(io.open(p, encoding='utf-8'))
        print('%s ok (+%d)' % (p, len(DATA)))

    p = os.path.join(ROOT, 'lib', 'l10n', 'app_localizations.dart')
    s = io.open(p, encoding='utf-8').read()
    code = []
    for k, v in DATA.items():
        if re.search(r'String (?:get )?%s\b' % k, s):
            continue
        code.append("  /// No description provided for @%s.\n  ///\n"
                    "  /// In zh, this message translates to:\n  /// **'%s'**\n"
                    "  String %s;\n" % (k, v[0], member(k)))
    if code:
        _, j = class_body(s, 'AppLocalizations')
        s = s[:j] + '\n' + '\n'.join(code) + s[j:]
        io.open(p, 'w', encoding='utf-8').write(s)
    print('抽象类 +%d' % len(code))

    for lg in LANGS:
        fn = ('app_localizations_zh.dart' if lg in ('zh', 'zh_TW')
              else 'app_localizations_%s.dart' % lg)
        p = os.path.join(ROOT, 'lib', 'l10n', fn)
        s = io.open(p, encoding='utf-8').read()
        b0, b1 = class_body(s, CLASSES[lg])
        code = []
        for k, v in DATA.items():
            if re.search(r'String (?:get )?%s\b' % k, s[b0:b1]):
                continue
            code.append('  @override\n  String %s => %s;\n'
                        % (member(k),
                           json.dumps(interp(k, v[IDX[lg]]), ensure_ascii=False)))
        if code:
            s = s[:b1] + '\n' + '\n'.join(code) + s[b1:]
            io.open(p, 'w', encoding='utf-8').write(s)
        print('%s +%d' % (CLASSES[lg], len(code)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
