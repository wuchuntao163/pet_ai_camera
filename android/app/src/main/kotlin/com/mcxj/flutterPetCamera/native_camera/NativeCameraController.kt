package com.mcxj.flutterPetCamera.native_camera

import android.content.Context
import android.media.AudioManager
import android.media.MediaActionSound
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.Rational
import android.util.Size
import android.view.Surface
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.core.UseCaseGroup
import androidx.camera.core.ViewPort
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

class NativeCameraController private constructor(private val appContext: Context) {
    companion object {
        private const val TAG = "NativeCamera"

        @Volatile
        private var instance: NativeCameraController? = null

        fun getInstance(context: Context): NativeCameraController {
            return instance ?: synchronized(this) {
                instance ?: NativeCameraController(context.applicationContext).also { instance = it }
            }
        }
    }

    private val mainExecutor = ContextCompat.getMainExecutor(appContext)
    private val captureExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var shutterSound: MediaActionSound? = null
    private var shutterSoundLoaded = false
    private val shutterHandler = Handler(Looper.getMainLooper())

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var previewUseCase: Preview? = null
    private var imageCapture: ImageCapture? = null
    private var lifecycleOwner: LifecycleOwner? = null
    private var pendingPreviewView: PreviewView? = null

    private var useBackCamera = true
    private var flashMode = ImageCapture.FLASH_MODE_OFF
    private var torchEnabled = false
    private var currentZoom = 1f
    private var selectedCameraId = ""

    private var baselineOneX = 1.0
    private var minZoom = 1.0
    private var maxZoom = 1.0
    private var previewAspectRatio = 3.0 / 4.0
    private var previewFitContain = true
    /** 全屏模式：ViewPort 使用屏幕宽高比，预览/成片与取景一�?*/
    private var viewportAspectRatio: Double? = null

    fun initialize(lifecycleOwner: LifecycleOwner, callback: (Result<Map<String, Any>>) -> Unit) {
        this.lifecycleOwner = lifecycleOwner
        val future = ProcessCameraProvider.getInstance(appContext)
        future.addListener({
            try {
                cameraProvider = future.get()
                bindUseCases(callback)
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }, mainExecutor)
    }

    fun attachPreview(previewView: PreviewView, lifecycleOwner: LifecycleOwner) {
        this.lifecycleOwner = lifecycleOwner
        if (pendingPreviewView != null && pendingPreviewView !== previewView) {
            detachPreview(pendingPreviewView!!)
        }
        pendingPreviewView = previewView
        applyPreviewScaleType()
        previewUseCase?.setSurfaceProvider(previewView.surfaceProvider)
        if (camera == null && cameraProvider != null) {
            bindUseCases(null)
        }
    }

    fun detachPreview(previewView: PreviewView) {
        if (pendingPreviewView !== previewView) return
        pendingPreviewView = null
        pause()
    }

    fun setPreviewMode(
        contain: Boolean,
        viewportAspect: Double?,
        callback: ((Result<Map<String, Any>>) -> Unit)?,
    ) {
        val aspect = if (contain) null else viewportAspect
        if (previewFitContain == contain && viewportAspectRatio == aspect) {
            callback?.invoke(Result.success(currentCameraInfo()))
            return
        }
        previewFitContain = contain
        viewportAspectRatio = aspect
        applyPreviewScaleType()
        if (cameraProvider != null && lifecycleOwner != null) {
            bindUseCases(callback)
        } else {
            callback?.invoke(Result.success(currentCameraInfo()))
        }
    }

    private fun applyPreviewScaleType() {
        pendingPreviewView?.scaleType = if (previewFitContain) {
            PreviewView.ScaleType.FIT_CENTER
        } else {
            PreviewView.ScaleType.FILL_CENTER
        }
    }

    fun pause() {
        previewUseCase?.setSurfaceProvider { request ->
            request.willNotProvideSurface()
        }
        cameraProvider?.unbindAll()
        camera = null
        previewUseCase = null
        imageCapture = null
        torchEnabled = false
    }

    fun resume(callback: ((Result<Map<String, Any>>) -> Unit)?) {
        if (cameraProvider == null || lifecycleOwner == null) {
            callback?.invoke(Result.failure(IllegalStateException("Camera lifecycle not ready")))
            return
        }
        bindUseCases(callback)
    }

    fun dispose() {
        pause()
        pendingPreviewView = null
        selectedCameraId = ""
        shutterHandler.removeCallbacksAndMessages(null)
        shutterSound?.release()
        shutterSound = null
        shutterSoundLoaded = false
    }

    private fun getOrCreateShutterSound(): MediaActionSound? {
        if (shutterSound != null) return shutterSound
        return try {
            MediaActionSound().also { shutterSound = it }
        } catch (e: Exception) {
            Log.w(TAG, "MediaActionSound create failed: $e")
            null
        }
    }

    private fun prepareShutterSound() {
        if (shutterSoundLoaded) return
        val sound = getOrCreateShutterSound() ?: return
        try {
            sound.load(MediaActionSound.SHUTTER_CLICK)
            shutterSoundLoaded = true
        } catch (e: Exception) {
            Log.w(TAG, "prepareShutterSound failed: $e")
            shutterSound?.release()
            shutterSound = null
            shutterSoundLoaded = false
        }
    }

    private fun playSystemShutterFallback() {
        try {
            val am =
                appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            @Suppress("DEPRECATION")
            am.playSoundEffect(AudioManager.FX_KEY_CLICK, 1.0f)
        } catch (fallback: Exception) {
            Log.w(TAG, "playShutterSound fallback failed: $fallback")
        }
    }

    fun playShutterSound() {
        shutterHandler.post {
            try {
                prepareShutterSound()
                val sound = shutterSound
                if (sound != null && shutterSoundLoaded) {
                    sound.play(MediaActionSound.SHUTTER_CLICK)
                } else {
                    playSystemShutterFallback()
                }
            } catch (e: Exception) {
                Log.w(TAG, "playShutterSound MediaActionSound failed: $e")
                playSystemShutterFallback()
            }
        }
    }

    fun switchCamera(callback: (Result<Map<String, Any>>) -> Unit) {
        useBackCamera = !useBackCamera
        bindUseCases(callback)
    }

    fun setZoom(zoom: Double) {
        currentZoom = zoom.toFloat()
        camera?.cameraControl?.setZoomRatio(currentZoom)
    }

    fun setFlash(mode: String) {
        when (mode) {
            "off" -> {
                flashMode = ImageCapture.FLASH_MODE_OFF
                torchEnabled = false
                camera?.cameraControl?.enableTorch(false)
            }
            "on" -> {
                flashMode = ImageCapture.FLASH_MODE_OFF
                torchEnabled = true
                camera?.cameraControl?.enableTorch(true)
            }
            "auto" -> {
                flashMode = ImageCapture.FLASH_MODE_AUTO
                torchEnabled = false
                camera?.cameraControl?.enableTorch(false)
            }
        }
        imageCapture?.flashMode = flashMode
    }

    fun takePicture(crop: Map<String, Any>?, callback: (Result<Map<String, Any>>) -> Unit) {
        val capture = imageCapture
        if (capture == null) {
            callback(Result.failure(IllegalStateException("ImageCapture not ready")))
            return
        }
        capture.flashMode = if (torchEnabled) ImageCapture.FLASH_MODE_OFF else flashMode

        if (crop?.get("playShutter") == true) {
            playShutterSound()
        }

        val cropParams = CropParams.from(crop)
        val outputPath = crop?.get("outputPath") as? String
        val photoFile = if (!outputPath.isNullOrBlank()) {
            File(outputPath).also { it.parentFile?.mkdirs() }
        } else {
            File(appContext.cacheDir, "capture_${System.currentTimeMillis()}.jpg")
        }
        val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()
        val captureStartedMs = SystemClock.elapsedRealtime()

        capture.takePicture(
            outputOptions,
            captureExecutor,
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    if (cropParams != null && !cropParams.directOutput) {
                        PhotoCropHelper.cropFileInPlace(photoFile, cropParams)
                    }
                    if (cropParams?.mirrorFront == true) {
                        PhotoCropHelper.mirrorHorizontallyInPlace(photoFile)
                    }
                    val elapsed = SystemClock.elapsedRealtime() - captureStartedMs
                    Log.i(TAG, "Capture done in ${elapsed}ms direct=${cropParams?.directOutput}")
                    mainExecutor.execute {
                        callback(
                            Result.success(
                                mapOf(
                                    "path" to photoFile.absolutePath,
                                    "captureDurationMs" to elapsed,
                                    "directOutput" to (cropParams?.directOutput ?: false),
                                ),
                            ),
                        )
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    mainExecutor.execute {
                        callback(Result.failure(exception))
                    }
                }
            },
        )
    }

    private fun bindUseCases(callback: ((Result<Map<String, Any>>) -> Unit)?) {
        val owner = lifecycleOwner
        val provider = cameraProvider
        if (owner == null || provider == null) {
            callback?.invoke(Result.failure(IllegalStateException("Camera lifecycle not ready")))
            return
        }

        provider.unbindAll()

        val selector = buildCameraSelector(provider, useBackCamera)

        val captureResolution = ResolutionSelector.Builder()
            .setResolutionStrategy(
                ResolutionStrategy(
                    Size(1280, 960),
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER,
                ),
            )
            .build()

        val rotation = pendingPreviewView?.display?.rotation ?: Surface.ROTATION_0

        previewUseCase = Preview.Builder()
            .setTargetRotation(rotation)
            .build()
            .also { preview ->
                pendingPreviewView?.let { preview.setSurfaceProvider(it.surfaceProvider) }
            }

        imageCapture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .setResolutionSelector(captureResolution)
            .setFlashMode(flashMode)
            .setTargetRotation(rotation)
            .setJpegQuality(82)
            .setSoftwareJpegEncoderRequested(false)
            .build()

        camera = if (previewFitContain) {
            provider.bindToLifecycle(
                owner,
                selector,
                previewUseCase,
                imageCapture,
            )
        } else {
            provider.bindToLifecycle(
                owner,
                selector,
                UseCaseGroup.Builder()
                    .addUseCase(previewUseCase!!)
                    .addUseCase(imageCapture!!)
                    .setViewPort(buildViewPort(rotation))
                    .build(),
            )
        }

        val zoomState = camera?.cameraInfo?.zoomState?.value
        minZoom = zoomState?.minZoomRatio?.toDouble() ?: 1.0
        maxZoom = zoomState?.maxZoomRatio?.toDouble() ?: max(minZoom, 10.0)
        // 多摄机型（如小米）minZoom 可能 < 1（超广角）；UI�?X」应对应主摄 1.0，而非最广角
        baselineOneX = 1.0.coerceIn(minZoom, maxZoom)
        currentZoom = baselineOneX.toFloat()
        camera?.cameraControl?.setZoomRatio(currentZoom)

        previewAspectRatio = readEffectivePreviewAspect()

        Log.i(
            TAG,
            "Bound cameraId=$selectedCameraId back=$useBackCamera " +
                "zoom=[$minZoom,$maxZoom] baseline=$baselineOneX aspect=$previewAspectRatio " +
                "contain=$previewFitContain viewport=$viewportAspectRatio",
        )

        callback?.invoke(Result.success(currentCameraInfo()))
    }

    private fun currentCameraInfo(): Map<String, Any> = mapOf(
        "baselineOneX" to baselineOneX,
        "minZoom" to minZoom,
        "maxZoom" to maxZoom,
        "previewAspectRatio" to previewAspectRatio,
        "isBackCamera" to useBackCamera,
        "cameraId" to selectedCameraId,
    )

    private fun buildCameraSelector(
        provider: ProcessCameraProvider,
        back: Boolean,
    ): CameraSelector {
        if (!back) {
            selectedCameraId = "front"
            return CameraSelector.DEFAULT_FRONT_CAMERA
        }

        selectedCameraId = "0"
        Log.i(TAG, "Using default back camera (main wide lens)")
        return CameraSelector.DEFAULT_BACK_CAMERA
    }

    private fun buildViewPort(rotation: Int): ViewPort {
        val aspect = viewportAspectRatio ?: readSensorAspectDouble()
        return ViewPort.Builder(aspectToRational(aspect), rotation)
            .setScaleType(ViewPort.FILL_CENTER)
            .build()
    }

    private fun aspectToRational(aspect: Double): Rational {
        var w = (aspect * 10000).roundToInt().coerceAtLeast(1)
        var h = 10000
        fun gcd(a: Int, b: Int): Int = if (b == 0) kotlin.math.abs(a) else gcd(b, a % b)
        val g = gcd(w, h)
        w /= g
        h /= g
        return Rational(w, h)
    }

    private fun readEffectivePreviewAspect(): Double {
        viewportAspectRatio?.let { return it }
        return readSensorAspectDouble()
    }

    private fun readSensorAspectDouble(): Double {
        val res = imageCapture?.resolutionInfo?.resolution
            ?: previewUseCase?.resolutionInfo?.resolution
        if (res != null && res.width > 0 && res.height > 0) {
            val w = minOf(res.width, res.height).toDouble()
            val h = maxOf(res.width, res.height).toDouble()
            return w / h
        }
        return 3.0 / 4.0
    }

}
