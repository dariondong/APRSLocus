# 公告（应用内的公告横幅读这里）

**这个目录里的 `.md` 是生成的，不要手改。**

唯一手写处是**官网首页的公告区**（`docs/index.html` / `docs/zh-TW/index.html` /
`docs/en/index.html` 里的 `<section class="section announce" id="announce">`）——
按你原来的方式改那段 HTML（样式、按钮都在原地），然后跑：

```bash
python3 tool/sync_notice_md.py
```

它会把这些页面里的公告**生成为** `notice/<语言>.md`。官网与应用从此看同一份内容：
官网发什么，应用横幅就显示什么。

## 语言

| 文件 | 来源 | 说明 |
|---|---|---|
| `zh.md` | `docs/index.html` | 简体 |
| `zh_TW.md` | `docs/zh-TW/index.html` | 繁體 |
| `en.md` | `docs/en/index.html` | English，**兜底**：其它语言取不到时用这份 |
| `ja.md` / `es.md` / `id.md` | （无） | **不生成** —— 官网只有三语，这三种语言的用户看 `en.md` |

将来某个语言要单独发公告，直接手写一份 `docs/notice/ja.md` 就行
（`sync_notice_md.py` 不会删它，它只生成上面三种）。

## 应用侧行为（见 `lib/notice.dart`）

1. 按当前界面语言取 `notice/<语言>.md`；
2. 取不到（404 / 超时 / 断网）→ 退回 `notice/en.md`；
3. 还是取不到 → 用**上次成功拉到的缓存**（存在 SharedPreferences 里，断网也看得见）；
4. 连缓存都没有 → 界面上如实写「暂无公告」+ 重试，而不是留一片空白。

## 生成规则（`sync_notice_md.py` 里实现了，改 HTML 时照着写就行）

| 页面里的 | 生成的 Markdown |
|---|---|
| `announce-kicker`（标题上方的小字） | `**加粗一行**` |
| `announce-title` + `announce-en`（右侧小字） | `# 标题 · 小字`（应用横幅拿它当摘要） |
| `announce-sub`（导语） | 普通段落 |
| `announce-greet` / 正文 `<p>` | 普通段落（`<b>` → `**粗体**`） |
| `announce-quote`（`<br>` 分行） | 引用块（两行） |
| `announce-sign` 三行 | 引用块（三行） |
| 底部按钮（非 `#锚点`） | 末尾的「相关链接」列表 |

> 页内锚点按钮（如 `href="#community"`）**不进** Markdown：应用里没有对应的位置，
> 留着就是个点不动的死链。

## 防漂移

`tool/check_notice.py`（已接进 CI）会把「用本脚本生成的内容」与「仓库里那份 .md」
逐字节比对：**改了官网公告区却忘了跑同步**，CI 直接报红。
