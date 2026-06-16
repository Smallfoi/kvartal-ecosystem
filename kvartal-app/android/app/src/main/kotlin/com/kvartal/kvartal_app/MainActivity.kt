package com.kvartal.kvartal_app

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocationService" -> {
                    startLocationService()
                    result.success(true)
                }
                "stopLocationService" -> {
                    stopLocationService()
                    result.success(true)
                }
                "getManufacturer" -> {
                    result.success(android.os.Build.MANUFACTURER ?: "")
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startLocationService() {
        val intent = Intent(this, KvartalLocationService::class.java).apply {
            action = KvartalLocationService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopLocationService() {
        val intent = Intent(this, KvartalLocationService::class.java).apply {
            action = KvartalLocationService.ACTION_STOP
        }
        startService(intent)
    }

    companion object {
        private const val CHANNEL = "kvartal/location_service"
    }
}
