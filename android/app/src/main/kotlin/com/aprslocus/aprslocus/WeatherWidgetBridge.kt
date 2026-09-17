package com.aprslocus.aprslocus

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart → 原生：桌面小组件的快照入口。
 *
 * Flutter 侧（lib/app_widget.dart::AppWidgetBridge）算好一份「已本地化、已
 * 格式化」的 JSON 推过来，这里只做两件事：落盘 + 通知组件重画。
 *
 * 通道名与方法名与 Dart 侧必须一致：
 *   通道  com.aprslocus/app_widget
 *   方法  update（String: 快照 JSON）/ clear（无参）
 *
 * 与 MainActivity 里其它通道一样是「同进程直连」，不走广播 —— 广播在 Android
 * 后台限制下不可靠，而且这里本来就是同一个进程。
 */
class WeatherWidgetBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)

    fun attach() {
        channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "update" -> {
                    val json = call.arguments as? String
                    if (json.isNullOrEmpty()) {
                        result.error("bad_args", "update 需要一个非空 JSON 字符串", null)
                        return@setMethodCallHandler
                    }
                    WeatherWidgetStore.save(context, json)
                    WeatherWidgetProvider.refreshAll(context)
                    result.success(true)
                }

                // 短波/电离层组件用**同一个通道的另一个方法**，而不是新开通道：
                // 两者都由 Dart 侧的 AppWidgetSync 推送，同一个 Lifecycle，
                // 分通道只会多一份 attach/错误处理。
                "updateHf" -> {
                    val json = call.arguments as? String
                    if (json.isNullOrEmpty()) {
                        result.error("bad_args", "updateHf 需要一个非空 JSON 字符串", null)
                        return@setMethodCallHandler
                    }
                    HfWidgetStore.save(context, json)
                    HfWidgetProvider.refreshAll(context)
                    result.success(true)
                }

                "clearHf" -> {
                    HfWidgetStore.clear(context)
                    HfWidgetProvider.refreshAll(context)
                    result.success(true)
                }

                // 系统状态组件：与前两个同通道的另一个方法
                "updateSys" -> {
                    val json = call.arguments as? String
                    if (json.isNullOrEmpty()) {
                        result.error("bad_args", "updateSys 需要一个非空 JSON 字符串", null)
                        return@setMethodCallHandler
                    }
                    SysWidgetStore.save(context, json)
                    SysWidgetProvider.refreshAll(context)
                    result.success(true)
                }

                "clearSys" -> {
                    SysWidgetStore.clear(context)
                    SysWidgetProvider.refreshAll(context)
                    result.success(true)
                }

                "clear" -> {
                    WeatherWidgetStore.clear(context)
                    WeatherWidgetProvider.refreshAll(context)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        /** ← 与 lib/app_widget.dart 的 kAppWidgetChannel 必须一致 */
        const val CHANNEL = "com.aprslocus/app_widget"
    }
}
