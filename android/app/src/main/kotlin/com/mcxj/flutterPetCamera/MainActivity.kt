package com.mcxj.flutterPetCamera

import com.mcxj.flutterPetCamera.gallery.GalleryMediaPlugin
import com.mcxj.flutterPetCamera.native_camera.NativeCameraPlugin
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(NativeCameraPlugin())
        flutterEngine.plugins.add(GalleryMediaPlugin())
    }
}
