package com.example.pet_ai_camera.native_camera

import android.app.Activity
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class NativeCameraPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    companion object {
        const val CHANNEL = "com.example.pet_ai_camera/native_camera"
        const val VIEW_TYPE = "native-camera-preview"

        var currentActivity: LifecycleOwner? = null
            private set
    }

    private var channel: MethodChannel? = null
    private var appContext: android.content.Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            NativeCameraPreviewFactory(),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Application context missing", null)
            return
        }
        val controller = NativeCameraController.getInstance(context)
        val owner = currentActivity

        when (call.method) {
            "initialize" -> {
                if (owner == null) {
                    result.error("NO_ACTIVITY", "Activity not ready", null)
                    return
                }
                controller.initialize(owner) { r ->
                    r.onSuccess { result.success(it) }
                        .onFailure { result.error("INIT_FAILED", it.message, null) }
                }
            }
            "dispose" -> {
                controller.dispose()
                result.success(null)
            }
            "pause" -> {
                controller.pause()
                result.success(null)
            }
            "resume" -> {
                controller.resume { r ->
                    r.onSuccess { result.success(it) }
                        .onFailure { result.error("RESUME_FAILED", it.message, null) }
                }
            }
            "switchCamera" -> {
                controller.switchCamera { r ->
                    r.onSuccess { result.success(it) }
                        .onFailure { result.error("SWITCH_FAILED", it.message, null) }
                }
            }
            "setZoom" -> {
                val zoom = call.argument<Double>("zoom")
                if (zoom == null) {
                    result.error("ARG", "zoom required", null)
                    return
                }
                controller.setZoom(zoom)
                result.success(null)
            }
            "setFlash" -> {
                val mode = call.argument<String>("mode") ?: "off"
                controller.setFlash(mode)
                result.success(null)
            }
            "setPreviewMode" -> {
                val contain = call.argument<Boolean>("contain") ?: false
                val viewportAspect = call.argument<Double>("viewportAspect")
                controller.setPreviewMode(contain, viewportAspect) { r ->
                    r.onSuccess { result.success(it) }
                        .onFailure { result.error("PREVIEW_MODE_FAILED", it.message, null) }
                }
            }
            "takePicture" -> {
                @Suppress("UNCHECKED_CAST")
                val crop = call.argument<Map<String, Any>>("crop")
                controller.takePicture(crop) { r ->
                    r.onSuccess { result.success(it) }
                        .onFailure { result.error("CAPTURE_FAILED", it.message, null) }
                }
            }
            "writeImageGps" -> {
                val path = call.argument<String>("path")
                val latitude = call.argument<Double>("latitude")
                val longitude = call.argument<Double>("longitude")
                if (path.isNullOrBlank() || latitude == null || longitude == null) {
                    result.error("ARG", "path, latitude, longitude required", null)
                    return
                }
                val ok = PhotoExifHelper.writeGps(File(path), latitude, longitude)
                result.success(ok)
            }
            "writeImageDevice" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("ARG", "path required", null)
                    return
                }
                val ok = PhotoExifHelper.writeDeviceInfo(
                    File(path),
                    call.argument("make"),
                    call.argument("model"),
                )
                result.success(ok)
            }
            "writeCaptureMetadata" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("ARG", "path required", null)
                    return
                }
                val ok = PhotoExifHelper.writeCaptureMetadata(
                    File(path),
                    call.argument("latitude"),
                    call.argument("longitude"),
                    call.argument("make"),
                    call.argument("model"),
                    call.argument("dateTimeOriginal"),
                )
                result.success(ok)
            }
            else -> result.notImplemented()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        currentActivity = binding.activity as? LifecycleOwner
    }

    override fun onDetachedFromActivityForConfigChanges() {
        currentActivity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        currentActivity = binding.activity as? LifecycleOwner
    }

    override fun onDetachedFromActivity() {
        currentActivity = null
    }
}
