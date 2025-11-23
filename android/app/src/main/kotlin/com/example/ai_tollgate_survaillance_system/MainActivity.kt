package com.example.ai_tollgate_survaillance_system

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import android.view.WindowManager.LayoutParams
import android.os.Bundle

class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // LOGIC: Check if the app is NOT debuggable (i.e., it is Release mode)
        if (!BuildConfig.DEBUG) {
            window.setFlags(
                LayoutParams.FLAG_SECURE,
                LayoutParams.FLAG_SECURE
            )
        }
    }
}