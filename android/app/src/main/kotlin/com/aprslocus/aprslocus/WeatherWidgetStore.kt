package com.aprslocus.aprslocus

import android.content.Context

/**
 * 桌面小组件快照的落盘位置。
 *
 * 单独放在组件自己的 SharedPreferences 里（而不是蹭 Flutter 的
 * `FlutterSharedPreferences`）：后者的文件格式与键名前缀是 flutter 插件的
 * 内部实现，插件升级换实现就会连带把组件读崩。这里自成一份，
 * 只有一个键、一个字符串，生命周期完全由我们自己掌握。
 *
 * 写入走 `apply()`：组件刷新是「锦上添花」，不该为了它阻塞 App 的主线程。
 */
object WeatherWidgetStore {
    private const val PREFS = "aprslocus_app_widget"
    private const val KEY_SNAPSHOT = "snapshot"

    fun save(context: Context, json: String) {
        prefs(context).edit().putString(KEY_SNAPSHOT, json).apply()
    }

    fun load(context: Context): String? = prefs(context).getString(KEY_SNAPSHOT, null)

    fun clear(context: Context) {
        prefs(context).edit().remove(KEY_SNAPSHOT).apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
