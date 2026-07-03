package com.example.pet_ai_camera

import com.example.pet_ai_camera.gallery.GalleryMediaPlugin
import com.example.pet_ai_camera.native_camera.NativeCameraPlugin
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(NativeCameraPlugin())
        flutterEngine.plugins.add(GalleryMediaPlugin())
    }
}
