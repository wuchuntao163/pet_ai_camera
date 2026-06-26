package com.example.pet_ai_camera.native_camera

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import kotlin.math.max
import kotlin.math.min

data class CropParams(
    val ratio: Double,
    val screenWidth: Double,
    val screenHeight: Double,
    val topInset: Double,
    val bottomInset: Double,
    val frameAlignY: Double,
    val previewAspect: Double,
    val fitContain: Boolean,
    val fullScreenPreview: Boolean,
    val fullScreen: Boolean,
    val nativeSensor: Boolean,
    val directOutput: Boolean,
    val mirrorFront: Boolean,
) {
    companion object {
        @Suppress("UNCHECKED_CAST")
        fun from(map: Map<String, Any>?): CropParams? {
            if (map == null) return null
            return CropParams(
                ratio = (map["ratio"] as Number).toDouble(),
                screenWidth = (map["screenWidth"] as Number).toDouble(),
                screenHeight = (map["screenHeight"] as Number).toDouble(),
                topInset = (map["topInset"] as Number).toDouble(),
                bottomInset = (map["bottomInset"] as Number).toDouble(),
                frameAlignY = (map["frameAlignY"] as Number).toDouble(),
                previewAspect = (map["previewAspect"] as Number).toDouble(),
                fitContain = map["fitContain"] as Boolean,
                fullScreenPreview = map["fullScreenPreview"] as Boolean,
                fullScreen = map["fullScreen"] as Boolean,
                nativeSensor = map["nativeSensor"] as Boolean,
                directOutput = map["directOutput"] as? Boolean ?: false,
                mirrorFront = map["mirrorFront"] as? Boolean ?: false,
            )
        }
    }
}

object PhotoCropHelper {
    /** 前置自拍：水平翻转成片，与镜像预览一致 */
    fun mirrorHorizontallyInPlace(file: File, quality: Int = 82): Boolean {
        val bitmap = BitmapFactory.decodeFile(file.absolutePath) ?: return false
        val matrix = Matrix().apply {
            preScale(-1f, 1f, bitmap.width / 2f, bitmap.height / 2f)
        }
        val mirrored = Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            matrix,
            true,
        )
        if (mirrored != bitmap && !bitmap.isRecycled) {
            bitmap.recycle()
        }
        return writeJpeg(file, mirrored, quality).also {
            if (!mirrored.isRecycled) mirrored.recycle()
        }
    }

    /** 解码并按 EXIF 旋转，裁切后覆盖原 JPEG */
    fun cropFileInPlace(file: File, params: CropParams): Boolean {
        if (params.directOutput) return true
        if (params.nativeSensor && orientedAspectMatches(file, params.ratio)) {
            return true
        }

        val rotation = readExifRotation(file)
        val bounds = decodeBounds(file) ?: return false
        val orientedW = if (rotation == 90 || rotation == 270) bounds.outHeight else bounds.outWidth
        val orientedH = if (rotation == 90 || rotation == 270) bounds.outWidth else bounds.outHeight

        // 9:16 全屏预览：成片与屏幕预览一致（屏幕比例，非固定 9:16）
        val rect = if (params.fullScreenPreview) {
            val screenRatio = when {
                params.screenHeight > 0 -> params.screenWidth / params.screenHeight
                params.previewAspect > 0 -> params.previewAspect
                else -> params.ratio
            }
            val orientedAspect = orientedW.toDouble() / orientedH
            if (kotlin.math.abs(orientedAspect - screenRatio) < 0.03) {
                return true
            }
            computeCropRect(
                orientedW,
                orientedH,
                params.copy(ratio = screenRatio),
            )
        } else if (params.nativeSensor) {
            centerCropRect(orientedW, orientedH, params.ratio)
        } else {
            computeCropRect(orientedW, orientedH, params)
        }

        if (tryCropRegionFast(file, rect, rotation, bounds, 82)) {
            return true
        }

        val oriented = decodeOrientedBitmap(file) ?: return false
        val output = Bitmap.createBitmap(oriented, rect.x, rect.y, rect.width, rect.height)
        if (output != oriented && !oriented.isRecycled) {
            oriented.recycle()
        }
        return writeJpeg(file, output, 82).also {
            if (!output.isRecycled) output.recycle()
        }
    }

    private fun decodeBounds(file: File): BitmapFactory.Options? {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, opts)
        return if (opts.outWidth > 0 && opts.outHeight > 0) opts else null
    }

    private fun tryCropRegionFast(
        file: File,
        orientedRect: RectI,
        rotation: Int,
        bounds: BitmapFactory.Options,
        quality: Int,
    ): Boolean {
        val fileRect = mapOrientedRectToFile(
            rotation,
            orientedRect,
            bounds.outWidth,
            bounds.outHeight,
        )
        return try {
            FileInputStream(file).use { stream ->
                val decoder = BitmapRegionDecoder.newInstance(stream, false) ?: return false
                val region = android.graphics.Rect(
                    fileRect.x,
                    fileRect.y,
                    fileRect.x + fileRect.width,
                    fileRect.y + fileRect.height,
                )
                var bitmap = decoder.decodeRegion(region, BitmapFactory.Options()) ?: return false
                if (rotation != 0) {
                    val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
                    val rotated = Bitmap.createBitmap(
                        bitmap,
                        0,
                        0,
                        bitmap.width,
                        bitmap.height,
                        matrix,
                        true,
                    )
                    if (rotated != bitmap && !bitmap.isRecycled) bitmap.recycle()
                    bitmap = rotated
                }
                val ok = writeJpeg(file, bitmap, quality)
                if (!bitmap.isRecycled) bitmap.recycle()
                ok
            }
        } catch (_: Exception) {
            false
        }
    }

    /** 将已旋转坐标系中的裁切区域映射回 JPEG 文件坐标 */
    private fun mapOrientedRectToFile(
        rotation: Int,
        rect: RectI,
        fileW: Int,
        fileH: Int,
    ): RectI {
        return when (rotation) {
            90 -> RectI(
                rect.y,
                fileW - rect.x - rect.width,
                rect.height,
                rect.width,
            )
            180 -> RectI(
                fileW - rect.x - rect.width,
                fileH - rect.y - rect.height,
                rect.width,
                rect.height,
            )
            270 -> RectI(
                fileH - rect.y - rect.height,
                rect.x,
                rect.height,
                rect.width,
            )
            else -> rect
        }
    }

    private fun decodeOrientedBitmap(file: File): Bitmap? {
        val raw = BitmapFactory.decodeFile(file.absolutePath) ?: return null
        val rotation = readExifRotation(file)
        if (rotation == 0) return raw
        val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
        val rotated = Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, matrix, true)
        if (rotated != raw && !raw.isRecycled) raw.recycle()
        return rotated
    }

    private fun readExifRotation(file: File): Int {
        return try {
            when (ExifInterface(file.absolutePath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }
        } catch (_: Exception) {
            0
        }
    }

    private fun orientedAspectMatches(file: File, ratio: Double): Boolean {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, opts)
        if (opts.outWidth <= 0 || opts.outHeight <= 0) return false
        val rotation = readExifRotation(file)
        var w = opts.outWidth
        var h = opts.outHeight
        if (rotation == 90 || rotation == 270) {
            w = opts.outHeight
            h = opts.outWidth
        }
        val aspect = w.toDouble() / h
        return kotlin.math.abs(aspect - ratio) < 0.02
    }

    private fun writeJpeg(file: File, bitmap: Bitmap, quality: Int): Boolean {
        return try {
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private data class RectI(val x: Int, val y: Int, val width: Int, val height: Int)

    private fun computeCropRect(imageW: Int, imageH: Int, p: CropParams): RectI {
        val frame = computeFrame(p)
        val layout = computePreviewLayout(
            p.screenWidth, p.screenHeight, p.previewAspect,
            p.fitContain, p.fullScreenPreview, p.frameAlignY,
        )
        val captureAspect = imageW.toDouble() / imageH

        fun screenToNormX(x: Double) =
            ((x - layout.offsetX) / layout.scaledW).coerceIn(0.0, 1.0)
        fun screenToNormY(y: Double) =
            ((y - layout.offsetY) / layout.scaledH).coerceIn(0.0, 1.0)

        val px0 = screenToNormX(frame.boxLeft)
        val py0 = screenToNormY(frame.boxTop)
        val px1 = screenToNormX(frame.boxLeft + frame.boxWidth)
        val py1 = screenToNormY(frame.boxTop + frame.boxHeight)

        var nx0 = previewToCaptureNorm(px0, p.previewAspect, captureAspect)
        var ny0 = previewToCaptureNorm(py0, p.previewAspect, captureAspect)
        var nx1 = previewToCaptureNorm(px1, p.previewAspect, captureAspect)
        var ny1 = previewToCaptureNorm(py1, p.previewAspect, captureAspect)

        if (nx0 > nx1) nx0 = nx1.also { nx1 = nx0 }
        if (ny0 > ny1) ny0 = ny1.also { ny1 = ny0 }

        nx0 = nx0.coerceIn(0.0, 1.0)
        ny0 = ny0.coerceIn(0.0, 1.0)
        nx1 = nx1.coerceIn(0.0, 1.0)
        ny1 = ny1.coerceIn(0.0, 1.0)

        if (nx1 <= nx0 || ny1 <= ny0) {
            return centerCropRect(imageW, imageH, p.ratio)
        }

        var x = (nx0 * imageW).toInt()
        var y = (ny0 * imageH).toInt()
        var w = ((nx1 - nx0) * imageW).toInt()
        var h = ((ny1 - ny0) * imageH).toInt()
        if (w <= 0 || h <= 0) return centerCropRect(imageW, imageH, p.ratio)
        if (x + w > imageW) w = imageW - x
        if (y + h > imageH) h = imageH - y
        x = x.coerceIn(0, imageW - 1)
        y = y.coerceIn(0, imageH - 1)

        val outAspect = w.toDouble() / h
        if (kotlin.math.abs(outAspect - p.ratio) > 0.02) {
            return centerCropRectOnRegion(x, y, w, h, p.ratio)
        }
        return RectI(x, y, max(1, w), max(1, h))
    }

    private data class FrameBox(
        val boxLeft: Double,
        val boxTop: Double,
        val boxWidth: Double,
        val boxHeight: Double,
    )

    private data class Layout(
        val offsetX: Double,
        val offsetY: Double,
        val scaledW: Double,
        val scaledH: Double,
    )

    private fun computeFrame(p: CropParams): FrameBox {
        if (p.fullScreen || p.screenWidth <= 0 || p.screenHeight <= 0) {
            return FrameBox(0.0, 0.0, p.screenWidth, p.screenHeight)
        }
        val areaTop = p.topInset
        val areaH = (p.screenHeight - p.topInset - p.bottomInset)
            .coerceIn(0.0, p.screenHeight)
        if (areaH <= 0) {
            return FrameBox(0.0, 0.0, p.screenWidth, p.screenHeight)
        }
        val boxW: Double
        val boxH: Double
        if (p.screenWidth / areaH > p.ratio) {
            boxH = areaH
            boxW = areaH * p.ratio
        } else {
            boxW = p.screenWidth
            boxH = p.screenWidth / p.ratio
        }
        val alignY = p.frameAlignY.coerceIn(0.0, 1.0)
        val boxTop = (areaTop + (areaH - boxH) * alignY)
            .coerceIn(0.0, p.screenHeight - boxH)
        return FrameBox(
            (p.screenWidth - boxW) / 2,
            boxTop,
            boxW,
            boxH,
        )
    }

    private fun computePreviewLayout(
        screenW: Double,
        screenH: Double,
        previewAspect: Double,
        fitContain: Boolean,
        fullScreenPreview: Boolean,
        verticalAlignY: Double,
    ): Layout {
        val childW: Double
        val childH: Double
        if (screenW / screenH > previewAspect) {
            childH = screenH
            childW = screenH * previewAspect
        } else {
            childW = screenW
            childH = screenW / previewAspect
        }
        val scaleW = screenW / childW
        val scaleH = screenH / childH
        val scale = if (fitContain) min(scaleW, scaleH) else max(scaleW, scaleH)
        val scaledW = childW * scale
        val scaledH = childH * scale
        val alignY = if (fullScreenPreview) 0.5 else verticalAlignY.coerceIn(0.0, 1.0)
        return Layout(
            (screenW - scaledW) / 2,
            (screenH - scaledH) * alignY,
            scaledW,
            scaledH,
        )
    }

    private fun previewToCaptureNorm(
        previewNorm: Double,
        previewAspect: Double,
        captureAspect: Double,
    ): Double {
        if (previewAspect <= 0 || captureAspect <= 0) return previewNorm
        return 0.5 + (previewNorm - 0.5) * (previewAspect / captureAspect)
    }

    private fun centerCropRect(w: Int, h: Int, ratio: Double): RectI {
        val cropW: Double
        val cropH: Double
        if (w.toDouble() / h > ratio) {
            cropH = h.toDouble()
            cropW = h * ratio
        } else {
            cropW = w.toDouble()
            cropH = w / ratio
        }
        return RectI(
            ((w - cropW) / 2).toInt(),
            ((h - cropH) / 2).toInt(),
            cropW.toInt().coerceIn(1, w),
            cropH.toInt().coerceIn(1, h),
        )
    }

    private fun centerCropRectOnRegion(
        x: Int, y: Int, w: Int, h: Int, ratio: Double,
    ): RectI {
        val cropW: Double
        val cropH: Double
        if (w.toDouble() / h > ratio) {
            cropH = h.toDouble()
            cropW = h * ratio
        } else {
            cropW = w.toDouble()
            cropH = w / ratio
        }
        return RectI(
            x + ((w - cropW) / 2).toInt(),
            y + ((h - cropH) / 2).toInt(),
            cropW.toInt().coerceIn(1, w),
            cropH.toInt().coerceIn(1, h),
        )
    }
}
