package com.aprslocus.aprslocus

import android.content.Context

/**
 * 系统状态组件快照的落盘位置。
 *
 * 与天气 / 短波组件**分开存**：三者的刷新触发条件完全不同
 * （天气跟随定位、短波跟随 hamqsl 的 30 分钟 TTL、系统状态跟随链路与收发计数），
 * 混在一个键里会让任一方的更新顺带把另外两份也重写一遍。
 */
object SysWidgetStore {
    private const val PREFS = "aprslocus_sys_widget"
    private const val KEY_SNAPSHOT = "snapshot"

    fun save(context: Context, json: String) {
        prefs(context).edit().putString(KEY_SNAPSHOT, json).apply()
    }

    fun load(context: Context): String? =
        prefs(context).getString(KEY_SNAPSHOT, null)

    fun clear(context: Context) {
        prefs(context).edit().remove(KEY_SNAPSHOT).apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
