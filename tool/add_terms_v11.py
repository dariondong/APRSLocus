#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""用户协议 V1.0 → V1.1：补三处条款 + 未成年人 + 第三方数据免责，三语同步。

用户要求（原话）：「全部添加 然后添加未成年的提示 加上可能将数据传入第三方软件服务的免责声明」

补了什么（都是"代码里有、协议里没有"的）：
  * 3.5 网关（iGate）/射频转发的责任 —— App 能把 APRS-IS 的报文转到射频上发射；
  * 3.6 **未成年人**：应在监护人同意与指导下使用，监护人承担后果，不得无证发射；
  * 5.3 除 APRS-IS/地图之外还会与哪些第三方通信（天气发送位置、翻译发送文本、
        更新向 GitHub 请求、佳明 LiveTrack、多源地图瓦片）；
  * 6.3 去掉中文正文里夹着的英文 `affiliation or endorsement`；
  * 7.6 生命守护 / 碰撞摔倒检测 / 心率告警：辅助提醒，**不是医疗设备、不是紧急救援**；
  * 7.7 **数据可能传入第三方软件服务**的免责声明；
  * 版本 V1.1 + 新日期；§10 补一句联系方式（邮箱仓库里没有，不凭空编）。

改完由 tool/check_terms.py 守着：两份副本逐字节一致、三语条款号一致、版本一致。
用法：python3 tool/add_terms_v11.py   （幂等：已改过会提示并跳过）
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, 'assets')
DD = os.path.join(ROOT, 'docs', 'assets')
TARGETS = ['terms_zh.txt', 'terms_zh_TW.txt', 'terms_en.txt']

# ── 三语的新增内容 ──
NEW_34 = {
    'terms_zh.txt': """

3.5 开启「网关（iGate）」或使用射频链路转发报文，意味着您将代表他人在业余频段上发射。您应自行确保所用呼号、频率、功率与工作方式合法合规，并对转发的内容负责。未取得相应操作资格时，请勿开启射频转发功能。

3.6 本软件面向具备相应民事行为能力的使用者。未成年人（未满 18 周岁，或所在国家/地区规定的成年年龄）应在监护人同意并指导下使用本软件；因未成年人使用本软件所产生的一切后果，由监护人承担。未成年人尤其不得在未取得相应资格的情况下进行射频发射。

3.7 APRS 是公开、跨国的网络：您通过 APRS 发送的内容（位置、消息、备注、状态）应当真实、准确、合法，并尊重不同国家和地区的法律、宗教与文化习俗。请勿发送不实信息、违法内容，或可能被视为骚扰、冒犯的内容；您对以自己呼号发出的全部内容负责。
""",
    'terms_zh_TW.txt': """
3.5 開啟「閘道（iGate）」或使用射頻鏈路轉發報文，意味著您將代表他人在業餘頻段上發射。您應自行確保所用呼號、頻率、功率與工作方式合法合規，並對轉發的內容負責。未取得相應操作資格時，請勿開啟射頻轉發功能。

3.6 本軟體面向具備相應民事行為能力的使用者。未成年人（未滿 18 歲，或所在國家/地區規定的成年年齡）應在監護人同意並指導下使用本軟體；因未成年人使用本軟體所產生的一切後果，由監護人承擔。未成年人尤其不得在未取得相應資格的情況下進行射頻發射。

3.7 APRS 是公開、跨國的網絡：您透過 APRS 傳送的內容（位置、訊息、備註、狀態）應當真實、準確、合法，並尊重不同國家和地區的法律、宗教與文化習俗。請勿傳送不實資訊、違法內容，或可能被視為騷擾、冒犯的內容；您對以自己呼號發出的全部內容負責。
""",
    'terms_en.txt': """
3.5 Enabling the "Gateway (iGate)" feature or forwarding packets over a radio link means that you will transmit on amateur bands on behalf of others. You are responsible for ensuring that your callsign, frequency, power, and mode of operation are lawful and compliant, and for the content you forward. Do not enable RF forwarding if you do not hold the required operator privileges.

3.6 This software is intended for users with the corresponding legal capacity. Minors (under 18, or the age of majority in your jurisdiction) should use this software with the consent and guidance of a guardian, and the guardian bears all consequences of the minor's use. In particular, minors must not transmit on radio frequencies without the required qualifications.

3.7 APRS is a public, international network: the content you send over APRS (position, messages, comments, status) should be truthful, accurate, and lawful, and should respect the laws, religions, and cultural customs of different countries and regions. Do not send false information, unlawful content, or content that could reasonably be seen as harassment or offensive; you are responsible for all content transmitted under your callsign.
""",
}

NEW_52 = {
    'terms_zh.txt': """

5.3 除 APRS-IS 与地图服务外，本软件在您使用相应功能时还会与其它第三方通信：查询天气时会发送位置（和风天气）、翻译消息时会发送待翻译文本（Google 翻译或您自行配置的接口）、检查更新时会向 GitHub 请求版本信息、添加佳明 LiveTrack 分享链接时会访问该链接、以及在地图上加载第三方瓦片（高德、百度、腾讯、OpenStreetMap、CARTO、Esri 等）。这些通信仅在您主动使用该功能时发生，不使用即不发生；各服务商对数据的处理受其各自的条款与隐私政策约束。
""",
    'terms_zh_TW.txt': """
5.3 除 APRS-IS 與地圖服務外，本軟體在您使用相應功能時還會與其它第三方通訊：查詢天氣時會傳送位置（和風天氣）、翻譯訊息時會傳送待翻譯文字（Google 翻譯或您自行設定的介面）、檢查更新時會向 GitHub 請求版本資訊、加入佳明 LiveTrack 分享連結時會存取該連結、以及在地圖上載入第三方圖磚（高德、百度、騰訊、OpenStreetMap、CARTO、Esri 等）。這些通訊僅在您主動使用該功能時發生，不使用即不發生；各服務商對資料的處理受其各自的條款與隱私政策約束。
""",
    'terms_en.txt': """
5.3 In addition to APRS-IS and map services, this software communicates with other third parties when you use the corresponding features: it sends a location when fetching weather (QWeather), the text to be translated when translating messages (Google Translate or an endpoint you configure yourself), a version request to GitHub when checking for updates, accesses the link you add for Garmin LiveTrack, and loads third-party map tiles (Amap, Baidu, Tencent, OpenStreetMap, CARTO, Esri, etc.). Such communication only happens when you actively use that feature, and not otherwise. Each provider processes data under its own terms and privacy policy.
""",
}

NEW_75 = {
    'terms_zh.txt': """

7.6 「生命守护」「碰撞/摔倒检测」「心率告警」等功能仅是基于手机传感器与定位的辅助提醒，不是医疗设备，也不是紧急救援服务；它们可能漏报、误报或延迟，并且依赖设备状态与网络。请勿依赖上述功能保障人身安全；遇到紧急情况，请直接拨打当地急救电话。

7.7 使用天气、翻译、地图、应用更新、佳明 LiveTrack 等功能时，相关数据（如位置、待翻译文本、设备与版本信息）会发送给您所选择的第三方软件服务商。我们无法控制其对数据的处理、存储、留存与再分发，不对第三方对您数据的处理行为及由此产生的任何后果承担责任；该等传输受各服务商自身的条款与隐私政策约束。您可以在不使用这些功能的情况下使用本软件的核心 APRS 功能。
""",
    'terms_zh_TW.txt': """
7.6 「生命守護」「碰撞/摔倒偵測」「心率告警」等功能僅是基於手機感測器與定位的輔助提醒，不是醫療設備，也不是緊急救援服務；它們可能漏報、誤報或延遲，並且依賴裝置狀態與網路。請勿依賴上述功能保障人身安全；遇到緊急情況，請直接撥打當地急救電話。

7.7 使用天氣、翻譯、地圖、應用程式更新、佳明 LiveTrack 等功能時，相關資料（如位置、待翻譯文字、裝置與版本資訊）會傳送給您所選擇的第三方軟體服務商。我們無法控制其對資料的處理、儲存、留存與再分發，不對第三方對您資料的處理行為及由此產生的任何後果承擔責任；該等傳輸受各服務商自身的條款與隱私政策約束。您可以在不使用這些功能的情況下使用本軟體的核心 APRS 功能。
""",
    'terms_en.txt': """
7.6 Features such as "Life Guard", "crash/fall detection", and "heart-rate alarms" are auxiliary reminders based on phone sensors and location only. They are not medical devices and not an emergency service, and they may miss events, raise false alarms, or be delayed; they also depend on device state and network availability. Do not rely on them to protect personal safety. In an emergency, call your local emergency number directly.

7.7 When you use features such as weather, translation, maps, app updates, or Garmin LiveTrack, the relevant data (for example your location, the text to be translated, device and version information) is sent to the third-party software service you choose. We cannot control how those providers process, store, retain, or redistribute it, and we assume no liability for their handling of your data or for any consequences arising from it. Those transfers are governed by the providers' own terms and privacy policies. You may use the core APRS features of this software without using any of these features.
""",
}

# §6.3（只有中文两版夹了英文）
FIX_63 = {
    'terms_zh.txt': (
        '6.3 “APRS”是 Bob Bruninga（WB4APR）的注册商标。本软件对“APRS”一词的使用仅为描述兼容性，不暗示任何 affiliation 或 endorsement。',
        '6.3 “APRS”是 Bob Bruninga（WB4APR）的注册商标。本软件对“APRS”一词的使用仅为说明兼容性，不代表与其持有人存在任何关联、合作或经其背书。'),
    'terms_zh_TW.txt': (
        '6.3 「APRS」是 Bob Bruninga（WB4APR）的註冊商標。本軟體對「APRS」一詞的使用僅為描述兼容性，不暗示任何 affiliation 或 endorsement。',
        '6.3 「APRS」是 Bob Bruninga（WB4APR）的註冊商標。本軟體對「APRS」一詞的使用僅為說明相容性，不代表與其持有人存在任何關聯、合作或經其背書。'),
}

# §10 联系方式（邮箱仓库里没有，不凭空编 —— 只把"走哪条路"说清）
NEW_10 = {
    'terms_zh.txt': '· GitHub 仓库：搜索“APRSlocus”提交 Issue\n\n如需就个人信息或本协议相关事项联系我们，请通过上述 GitHub 仓库提交 Issue（公开可查，也便于其他用户参考）。',
    'terms_zh_TW.txt': '· GitHub 倉庫：搜索「APRSlocus」提交 Issue\n\n如需就個人資訊或本協議相關事項聯繫我們，請通過上述 GitHub 倉庫提交 Issue（公開可查，也便於其他使用者參考）。',
    'terms_en.txt': '· GitHub Repository: search for "APRSlocus" and submit an Issue\n\nFor matters related to personal information or this agreement, please open an Issue in the GitHub repository above (publicly visible, and easy for other users to check).',
}

VER = {
    'terms_zh.txt': ('版本：V1.0', '版本：V1.1', '更新日期：2026年9月5日', '更新日期：2026年10月1日'),
    'terms_zh_TW.txt': ('版本：V1.0', '版本：V1.1', '更新日期：2026年9月5日', '更新日期：2026年10月1日'),
    'terms_en.txt': ('Version: V1.0', 'Version: V1.1',
                     'Effective Date: September 5, 2026', 'Effective Date: October 1, 2026'),
}


def patch(path, name):
    s = io.open(path, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in s else '\n'      # ⚠ 这些文本是 CRLF（别用 \n 去找）
    if '3.7 ' in s and '5.3 ' in s and '7.7 ' in s:
        print('%-26s 已经是 V1.1（跳过）' % name)
        return
    n0 = len(s)

    def add(text):
        # 插入点落在"段末 + 空行 + ---"的**第一个换行**上，所以这里必须自己补一个
        # 空行 —— 否则新条款会和上一条贴成一段（用户报过「7.5 和 7.6 贴在一起了」）。
        # 放在逻辑里而不是逐个字符串前面加，是因为三个语言的块各有自己的前文，
        # 用字符串锚点去补的写法只对第一个键生效（另外两个静默跳过 —— 踩过）。
        t = text.replace('\n', nl)
        return t if t.startswith(nl + nl) else nl + t

    # ① 版本 / 日期
    a, b, c, d = VER[name]
    assert a in s and c in s, '%s 找不到版本行' % name
    s = s.replace(a, b, 1).replace(c, d, 1)

    sep = nl + nl + '---' + nl

    # ② 3.5 / 3.6：插在 3.4 最后一条之后（它后面紧跟分隔线）
    idx = s.index(sep, s.index('3.4 '))
    s = s[:idx] + add(NEW_34[name]) + s[idx:]

    # ③ 5.3：插在 5.2 之后
    idx = s.index(sep, s.index('5.2 '))
    s = s[:idx] + add(NEW_52[name]) + s[idx:]

    # ④ 6.3（中文两版）
    if name in FIX_63:
        old, new = FIX_63[name]
        assert old in s, '%s 找不到 6.3' % name
        s = s.replace(old, new, 1)

    # ⑤ 7.6 / 7.7：插在 7.5 之后
    idx = s.index(sep, s.index('7.5 '))
    s = s[:idx] + add(NEW_75[name]) + s[idx:]

    # ⑥ §10 联系方式
    # ⚠ 这里是**替换**不是插入：不能走 add()（那会给它加一个前导换行，
    #   于是 `split(nl)[0]` 变成空串，`replace('', …)` 会把整段塞到文件开头 ——
    #   重放测试当场抓出来的）。
    tail = NEW_10[name].replace('\n', nl)
    first = tail.split(nl)[0]
    assert first.strip(), '§10 的锚点不能是空串'
    assert first in s, '%s 找不到 §10 的 GitHub 行' % name
    s = s.replace(first, tail, 1)

    io.open(path, 'w', encoding='utf-8', newline='').write(s)
    print('%-26s %d → %d 字节' % (name, n0, len(s)))


def main():
    for name in TARGETS:
        patch(os.path.join(D, name), name)
    # 同步到官网（在线加载的那一份必须逐字节一致）
    for name in TARGETS:
        data = io.open(os.path.join(D, name), 'rb').read()
        io.open(os.path.join(DD, name), 'wb').write(data)
    print('已同步 docs/assets/（两处逐字节一致）')


if __name__ == '__main__':
    main()
