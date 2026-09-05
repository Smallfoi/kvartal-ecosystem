package ru.mata.kvartal

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, а не FlutterActivity: плагин health спрашивает разрешения
// Health Connect через ActivityResultContract, а тот живёт только во фрагментной
// активности. С обычной FlutterActivity диалог разрешений просто не открывается.
class MainActivity : FlutterFragmentActivity() {
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
