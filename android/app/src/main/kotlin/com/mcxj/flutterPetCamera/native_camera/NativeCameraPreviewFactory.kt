package com.mcxj.flutterPetCamera.native_camera

import android.content.Context
import android.graphics.Color
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.camera.view.PreviewView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class NativeCameraPreviewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return NativeCameraPlatformView(context)
    }
}

class NativeCameraPlatformView(context: Context) : PlatformView {
    private val previewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
        setBackgroundColor(Color.TRANSPARENT)
        layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
    }

    private val controller = NativeCameraController.getInstance(context)

    private val container = FrameLayout(context).apply {
        setBackgroundColor(Color.TRANSPARENT)
        layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        addView(previewView)
    }

    init {
        val activity = NativeCameraPlugin.currentActivity
        if (activity != null) {
            controller.attachPreview(previewView, activity)
        }
    }

    override fun getView() = container

    override fun dispose() {
        controller.detachPreview(previewView)
    }
}
