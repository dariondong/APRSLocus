# 公告（应用内的公告横幅读这里）

**这个目录里的 `.md` 就是唯一手写源 —— 直接改它。** 应用按
`notice/<语言>.md` 从官网拉取（`lib/notice.dart`），官网首页那张公告卡片由它生成。

```
docs/notice/{zh,zh_TW,en}.md      ← 唯一手写处（改这里）
        │  python3 tool/sync_notice_site.py
        ▼
docs/{index.html, zh-TW/index.html, en/index.html} 的 #announce 区块
```

改完公告 md 后**必须**跑一次：

```bash
python3 tool/sync_notice_site.py   # md → 官网三语公告区
python3 tool/check_notice.py       # 防漂移：官网公告区与 md 不一致就报红
```

> ⛔ **不要跑 `tool/sync_notice_md.py`**（已废弃，方向相反：HTML → md）。
> 它会用官网首页那段固定字段把整篇手写公告**覆盖掉** —— 现在公告里有
> 多级标题、列表、`@video` 内嵌视频，那种生成式表达不了。那个文件只留作历史参考。

## 语言

| 文件 | 官网卡片 | 说明 |
|---|---|---|
| `zh.md` | `docs/index.html` | 简体 |
| `zh_TW.md` | `docs/zh-TW/index.html` | 繁體 |
| `en.md` | `docs/en/index.html` | English，**兜底**：其它语言取不到时用这份 |
| `ja.md` / `es.md` / `id.md` | （无） | 官网只有三语；这三种语言的用户看 `en.md` |

某个语言要单独发公告，直接手写一份 `docs/notice/ja.md` 即可（同步脚本不管它）。

## 官网卡片的头部是**另一处**手写

`kicker` / 标题 / 右侧英文小字 / 导语（`announce-head` 那三行）**不是**从 md 推出来的 ——
它们写在 `tool/sync_notice_site.py` 顶部的 `HEAD` 字典里（三语各一份）。
**换一期公告时要连 HEAD 一起改**，否则会出现「正文是新的、标题还是上一期」。
卡片底部的按钮（下载 / 更新日志 / 反馈）同样是手写的，别忘了一起更新版本号。

## Markdown 子集（官网那张卡片只认这些）

| 写法 | 官网卡片里渲染成 |
|---|---|
| `# 标题` | 不渲染（标题走上面的 `HEAD`）；**应用横幅的摘要取的就是这一行** |
| `##` / `###` 小节 | 加粗段落 |
| `---` | 忽略 |
| `**粗体**` | `<b>` |
| `[文字](链接)` | 新窗口打开的超链接 |
| `- 列表项` | 项目符号列表 |
| `> 引用` | 引用块（连续行合成一段） |
| `@video <URL>` | 内嵌 B 站播放器等 iframe |
| 行内 `` `代码` `` | 原样显示（**不会**渲染成代码块） |

## 应用侧行为（见 `lib/notice.dart`）

1. 按当前界面语言取 `notice/<语言>.md`；
2. 取不到（404 / 超时 / 断网）→ 退回 `notice/en.md`；
3. 还是取不到 → 用**上次成功拉到的缓存**（存在 SharedPreferences 里，断网也看得见）；
4. 连缓存都没有 → 界面上如实写「暂无公告」+ 重试，而不是留一片空白。

**公告内容变了，横幅会重新出现**（记住「关掉的是哪一条」的指纹，见
`lib/state.dart` 的 `onNoticeLoaded`，issue #21-5）—— 所以发新公告不用清用户设置。

## 防漂移

`tool/check_notice.py`（已接进 CI）会按 `render_head` / `render_body` 重算一遍，
与官网三语页面**逐字节比对**：改了 md 却忘了跑 `sync_notice_site.py`，CI 直接报红。
