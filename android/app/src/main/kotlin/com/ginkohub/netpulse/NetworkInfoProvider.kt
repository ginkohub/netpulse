package com.ginkohub.netpulse

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.net.wifi.WifiConfiguration
import android.os.Build

object NetworkInfoProvider {
    private val wifiManager: WifiManager by lazy {
        AppContext.get().getSystemService(Context.WIFI_SERVICE) as WifiManager
    }
    
    private val connectivityManager: ConnectivityManager by lazy {
        AppContext.get().getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    fun getWifiInfo(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        try {
            @Suppress("DEPRECATION")
            val info = wifiManager.connectionInfo
            
            map["linkSpeed"] = info.linkSpeed.takeIf { it > 0 }
            map["frequency"] = info.frequency.takeIf { it > 0 }
            map["rssi"] = info.rssi.takeIf { it != -127 }
            map["networkId"] = info.networkId.takeIf { it != -1 }
            map["ssid"] = info.ssid?.replace("\"", "")?.takeIf { it.isNotEmpty() }
            map["bssid"] = info.bssid?.takeIf { it != "02:00:00:00:00:00" }
            map["macAddress"] = info.macAddress?.takeIf { it != "02:00:00:00:00:00" && it.isNotEmpty() }
            map["ipAddress"] = intToIpAddress(info.ipAddress)
            
            map["channel"] = frequencyToChannel(info.frequency)
            map["band"] = getWifiBand(info.frequency)
            map["security"] = getWifiSecurity()
            map["standard"] = getWifiStandard(info)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    val txSpeed = android.net.wifi.WifiInfo::class.java.getMethod("getTxLinkSpeed").invoke(info)
                    val rxSpeed = android.net.wifi.WifiInfo::class.java.getMethod("getRxLinkSpeed").invoke(info)
                    @Suppress("UNCHECKED_CAST")
                    map["txLinkSpeed"] = txSpeed as? Int
                    @Suppress("UNCHECKED_CAST")
                    map["rxLinkSpeed"] = rxSpeed as? Int
                } catch (e: Exception) { }
            }
            
            map["error"] = null
        } catch (e: Exception) {
            map["error"] = e.message
        }
        return map
    }

    fun getConnectivityInfo(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        try {
            val network = connectivityManager.activeNetwork
            val capabilities = connectivityManager.getNetworkCapabilities(network)
            
            if (capabilities == null) {
                map["type"] = "NONE"
                map["status"] = "DISCONNECTED"
                map["isConnected"] = false
                map["error"] = null
                return map
            }
            
            map["isConnected"] = true
            map["status"] = if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                "CONNECTED"
            } else { "CONNECTED_NO_INTERNET" }
            
            map["type"] = when {
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WIFI"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "CELLULAR"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ETHERNET"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "VPN"
                else -> "OTHER"
            }
            
            val capabilitiesList = mutableListOf<String>()
            if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) capabilitiesList.add("INTERNET")
            if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)) capabilitiesList.add("NOT_METERED")
            if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) capabilitiesList.add("VALIDATED")
            map["capabilities"] = capabilitiesList
            
            map["isMetered"] = !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            map["error"] = null
        } catch (e: Exception) {
            map["error"] = e.message
        }
        return map
    }

    fun getIpAddress(): String? {
        return try {
            @Suppress("DEPRECATION")
            intToIpAddress(wifiManager.connectionInfo.ipAddress)
        } catch (e: Exception) { null }
    }

    fun getGateway(): String? {
        return try {
            intToIpAddress(wifiManager.dhcpInfo.gateway)
        } catch (e: Exception) { null }
    }

    fun getDns(): String? {
        return try {
            val dhcpInfo = wifiManager.dhcpInfo
            val dns1 = intToIpAddress(dhcpInfo.dns1)
            val dns2 = intToIpAddress(dhcpInfo.dns2)
            listOfNotNull(dns1, dns2).joinToString(", ")
        } catch (e: Exception) { null }
    }

    private fun getWifiSecurity(): String {
        return try {
            @Suppress("DEPRECATION")
            val configs = wifiManager.configuredNetworks ?: return "UNKNOWN"
            if (configs.isEmpty()) return "UNKNOWN"
            
            val currentNetworkId = wifiManager.connectionInfo.networkId
            val config = configs.find { it.networkId == currentNetworkId } ?: return "UNKNOWN"
            
            try {
                val keyMgmtStr = config.allowedKeyManagement.toString()
                val protocolsStr = config.allowedProtocols.toString()
                
                when {
                    keyMgmtStr.contains("SAE") -> "WPA3"
                    keyMgmtStr.contains("WPA2") -> "WPA2"
                    keyMgmtStr.contains("WPA") -> "WPA"
                    protocolsStr.contains("RSN") -> "WPA2"
                    protocolsStr.contains("WPA") -> "WPA"
                    else -> "OPEN"
                }
            } catch (e: Exception) { "UNKNOWN" }
        } catch (e: Exception) { "UNKNOWN" }
    }

    private fun getWifiStandard(info: android.net.wifi.WifiInfo): String? {
        return try {
            val freq = info.frequency
            val speed = info.linkSpeed
            when {
                freq in 5950..7125 || speed >= 2400 -> "802.11be/WiFi7"
                freq in 5925..7125 || speed >= 1200 -> "802.11ax/WiFi6"
                freq in 5100..5900 || speed >= 433 -> "802.11ac/WiFi5"
                freq in 2400..2500 || speed >= 200 -> "802.11n/WiFi4"
                else -> null
            }
        } catch (e: Exception) { null }
    }

    private fun frequencyToChannel(frequency: Int): Int? {
        return when (frequency) {
            in 2412..2484 -> frequency - 2412 + 1
            in 5170..5825 -> (frequency - 5170) / 5 + 34
            in 5925..7125 -> (frequency - 5925) / 5 + 1
            else -> null
        }
    }

    private fun getWifiBand(frequency: Int): String? {
        return when {
            frequency in 2400..2500 -> "2.4GHz"
            frequency in 5100..5900 -> "5GHz"
            frequency in 5900..7200 -> "6GHz"
            else -> null
        }
    }

    private fun intToIpAddress(ip: Int): String? {
        return if (ip != 0) {
            listOf(
                (ip shr 0) and 0xFF,
                (ip shr 8) and 0xFF,
                (ip shr 16) and 0xFF,
                (ip shr 24) and 0xFF
            ).joinToString(".")
        } else null
    }
}