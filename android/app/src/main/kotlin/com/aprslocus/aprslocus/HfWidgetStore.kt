package com.aprslocus.aprslocus

import android.content.Context

/**
 * 短波/电离层组件快照的落盘位置。
 *
 * 与天气组件（[WeatherWidgetStore]）分开存：两个组件的数据来源与刷新节奏
 * 完全不同（天气按定位 15 分钟、短波按 hamqsl 30 分钟），混在一个键里
 * 会让「短波更新」顺带把天气数据也重写一遍，反过来也一样。
 *
 * 写入走 `apply()`：组件刷新是「锦上添花」，不该为了它阻塞 App 主线程。
 */
object HfWidgetStore {
    private const val PREFS = "aprslocus_hf_widget"
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
