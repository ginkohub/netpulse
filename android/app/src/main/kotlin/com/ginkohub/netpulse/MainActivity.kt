package com.ginkohub.netpulse

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppContext.init(applicationContext)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ginkohub.netpulse")
            .setMethodCallHandler { call, result ->
                NetworkMethodHandler.handle(call, result)
            }
    }
}
