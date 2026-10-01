// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

package com.aprslocus.aprslocus

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address

/**
 * Android 平台 Wi-Fi 网络选择器与平台通道（对应 mod 的 Ic705AndroidNetwork.kt）。
 *
 * 即使 IC-705 作为 Wi-Fi AP 没有互联网连接，Android 将默认网络指向蜂窝网络（移动数据），
 * 本管理器也能从 ConnectivityManager 中精准选出电台所在的 Wi-Fi 网络及其分配到的 IPv4 地址。
 */
class Ic705NetworkManager(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "com.aprslocus/ic705_network"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "findRadioNetwork" -> {
                try {
                    val info = findWifiNetworkInfo()
                    result.success(info)
                } catch (e: Exception) {
                    result.error("NET_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun findWifiNetwork(): Network? {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return null

        val active = cm.activeNetwork
        if (active != null) {
            val caps = cm.getNetworkCapabilities(active)
            if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) {
                return active
            }
        }

        return try {
            @Suppress("DEPRECATION")
            cm.allNetworks.firstOrNull { net ->
                cm.getNetworkCapabilities(net)?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            }
        } catch (_: Exception) {
            null
        }
    }

    fun findWifiNetworkInfo(): Map<String, Any?> {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return mapOf("status" to "NO_CONNECTIVITY_SERVICE")
        val network = findWifiNetwork()
            ?: return mapOf("status" to "NOT_FOUND")

        var ipv4: String? = null
        val linkProps = cm.getLinkProperties(network)
        if (linkProps != null) {
            for (linkAddr in linkProps.linkAddresses) {
                val addr = linkAddr.address
                if (addr is Inet4Address && !addr.isAnyLocalAddress && !addr.isLoopbackAddress) {
                    ipv4 = addr.hostAddress
                    break
                }
            }
        }

        return mapOf(
            "status" to "AVAILABLE",
            "networkHandle" to network.networkHandle,
            "ipv4Address" to ipv4,
        )
    }
}
