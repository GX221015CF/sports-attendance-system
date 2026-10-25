package com.example.mobile_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var interactionAudio: InteractionAudio? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        interactionAudio = runCatching { InteractionAudio(this, flutterEngine.dartExecutor.binaryMessenger) }.getOrNull()
    }

    override fun onResume() { super.onResume(); interactionAudio?.setActive(true) }
    override fun onPause() { interactionAudio?.setActive(false); super.onPause() }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        interactionAudio?.dispose()
        interactionAudio = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
