package com.ginkohub.netpulse

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object NetworkMethodHandler {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getWifiInfo" -> {
                    val info = NetworkInfoProvider.getWifiInfo()
                    result.success(info)
                }
                "getConnectivityInfo" -> {
                    val info = NetworkInfoProvider.getConnectivityInfo()
                    result.success(info)
                }
                "getIpAddress" -> {
                    result.success(NetworkInfoProvider.getIpAddress())
                }
                "getGateway" -> {
                    result.success(NetworkInfoProvider.getGateway())
                }
                "getDns" -> {
                    result.success(NetworkInfoProvider.getDns())
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("NETPULSE_ERROR", e.message, null)
        }
    }
}