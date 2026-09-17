package com.aprslocus.aprslocus

import org.json.JSONArray
import org.json.JSONObject

// 组件快照的读取工具。两个组件（天气 / 短波）共用同一套容错策略。
//
// **为什么一律容错、宁可少显示一个字段也不抛异常**：
// AppWidgetProvider 里未捕获的异常会直接让组件变成白块，而用户没有任何自救
// 途径（不能重装，只能删掉重加）。所以「某个 key 缺失 / 类型不符」时返回空串，
// 让那一格空着 —— 界面难看一点，但组件还活着。
//
// 注意：这两个扩展**刻意是 internal 而不是 private**。之前它们各自写在各
// Provider 文件里（private，文件级可见），两份同名实现容易在后续改动里只改了
// 一份。集中一处，行为必然一致。

/** 安全取字符串（缺失 / null / 类型不符 → 空串） */
internal fun JSONObject?.read(key: String): String {
    if (this == null || !has(key) || isNull(key)) return ""
    return optString(key, "")
}

/** 安全取第 [i] 项字符串（越界 / 缺失 → 空串） */
internal fun JSONArray?.read(i: Int): String {
    if (this == null || i < 0 || i >= length()) return ""
    return optString(i, "")
}
