package com.ticktodo.ticktodo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "refreshWidget" -> {
                        MonthWidgetProvider.refreshAll(this)
                        result.success(null)
                    }
                    "getStartupDate" -> {
                        result.success(intent?.getStringExtra(EXTRA_DATE))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        const val CHANNEL = "ticktodo/widget"
        const val EXTRA_DATE = "widget_date"
    }
}
