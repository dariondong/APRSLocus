package com.aprslocus.aprslocus

// 本文件由 tool/gen_app_widget_icons.py **自动生成**，不要手改。
//
// 把 Dart 传来的图标名映射到已烘焙的 PNG。图标名与 PNG、与
// lib/weather.dart 里的 Icons.xxx 一一对应（同一套 MaterialIcons 字形）。
//
// 生成器同时产出 PNG 与这张表，所以两边不会漂移；名字对不上时
// 宁可用兵底图标（rss_feed / cloud）也不要崩。
internal object WidgetIcons {
    /** 13dp 图标（提示行 / 指标 / 标题 / 城市点） */
    private val SMALL = mapOf(
        "ac_unit" to R.drawable.aw_ic_ac_unit,
        "air" to R.drawable.aw_ic_air,
        "auto_awesome" to R.drawable.aw_ic_auto_awesome,
        "blur_on" to R.drawable.aw_ic_blur_on,
        "calendar_month" to R.drawable.aw_ic_calendar_month,
        "cell_tower" to R.drawable.aw_ic_cell_tower,
        "cloud" to R.drawable.aw_ic_cloud,
        "device_thermostat" to R.drawable.aw_ic_device_thermostat,
        "flag" to R.drawable.aw_ic_flag,
        "flash_on" to R.drawable.aw_ic_flash_on,
        "grain" to R.drawable.aw_ic_grain,
        "graphic_eq" to R.drawable.aw_ic_graphic_eq,
        "hearing_disabled" to R.drawable.aw_ic_hearing_disabled,
        "history" to R.drawable.aw_ic_history,
        "icecream" to R.drawable.aw_ic_icecream,
        "local_fire_department" to R.drawable.aw_ic_local_fire_department,
        "masks" to R.drawable.aw_ic_masks,
        "nightlight" to R.drawable.aw_ic_nightlight,
        "nights_stay" to R.drawable.aw_ic_nights_stay,
        "opacity" to R.drawable.aw_ic_opacity,
        "place" to R.drawable.aw_ic_place,
        "power_off" to R.drawable.aw_ic_power_off,
        "public" to R.drawable.aw_ic_public,
        "public_off" to R.drawable.aw_ic_public_off,
        "rss_feed" to R.drawable.aw_ic_rss_feed,
        "thermostat" to R.drawable.aw_ic_thermostat,
        "thunderstorm" to R.drawable.aw_ic_thunderstorm,
        "trending_down" to R.drawable.aw_ic_trending_down,
        "tune" to R.drawable.aw_ic_tune,
        "umbrella" to R.drawable.aw_ic_umbrella,
        "visibility" to R.drawable.aw_ic_visibility,
        "warning_amber" to R.drawable.aw_ic_warning_amber,
        "water" to R.drawable.aw_ic_water,
        "water_drop" to R.drawable.aw_ic_water_drop,
        "waves" to R.drawable.aw_ic_waves,
        "wb_cloudy" to R.drawable.aw_ic_wb_cloudy,
        "wb_sunny" to R.drawable.aw_ic_wb_sunny,
        "wb_twilight" to R.drawable.aw_ic_wb_twilight,
        "wifi_tethering" to R.drawable.aw_ic_wifi_tethering,
    )

    /** 26dp 天气主图标（只给天气档位会用到的几个出一份大图） */
    private val BIG = mapOf(
        "ac_unit" to R.drawable.aw_ic_big_ac_unit,
        "blur_on" to R.drawable.aw_ic_big_blur_on,
        "cloud" to R.drawable.aw_ic_big_cloud,
        "grain" to R.drawable.aw_ic_big_grain,
        "nights_stay" to R.drawable.aw_ic_big_nights_stay,
        "thunderstorm" to R.drawable.aw_ic_big_thunderstorm,
        "water_drop" to R.drawable.aw_ic_big_water_drop,
        "wb_cloudy" to R.drawable.aw_ic_big_wb_cloudy,
        "wb_sunny" to R.drawable.aw_ic_big_wb_sunny,
    )

    fun small(name: String): Int =
        SMALL[name] ?: R.drawable.aw_ic_rss_feed

    fun big(name: String): Int =
        BIG[name] ?: R.drawable.aw_ic_big_cloud
}
