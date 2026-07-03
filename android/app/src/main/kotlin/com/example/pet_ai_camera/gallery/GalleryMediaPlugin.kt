package com.example.pet_ai_camera.gallery

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class GalleryMediaPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var applicationContext: android.content.Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "pet_ai_camera/gallery_media")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "deleteAppPhotos" -> {
                val context = applicationContext
                if (context == null) {
                    result.success(0)
                    return
                }
                @Suppress("UNCHECKED_CAST")
                val assetIds = (call.argument<List<Any>>("assetIds") ?: emptyList())
                    .map { it.toString() }
                @Suppress("UNCHECKED_CAST")
                val captureIds = (call.argument<List<Any>>("captureIds") ?: emptyList())
                    .map { it.toString() }
                val deleted = GalleryMediaHelper.deleteAppPhotos(
                    context = context,
                    activity = activity,
                    assetIds = assetIds,
                    captureIds = captureIds,
                )
                result.success(deleted)
            }

            else -> result.notImplemented()
        }
    }
}
