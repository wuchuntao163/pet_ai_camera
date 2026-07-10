package com.example.pet_ai_camera.native_camera

import androidx.exifinterface.media.ExifInterface
import java.io.File

object PhotoExifHelper {
    fun writeGps(file: File, latitude: Double, longitude: Double): Boolean {
        if (!latitude.isFinite() || !longitude.isFinite()) return false
        if (latitude == 0.0 && longitude == 0.0) return false
        if (!file.exists()) return false

        return try {
            val exif = ExifInterface(file.absolutePath)
            exif.setLatLong(latitude, longitude)
            exif.saveAttributes()
            true
        } catch (_: Exception) {
            false
        }
    }

    fun writeDeviceInfo(file: File, make: String?, model: String?): Boolean {
        if (!file.exists()) return false
        val makeValue = make?.trim().orEmpty()
        val modelValue = model?.trim().orEmpty()
        if (makeValue.isEmpty() && modelValue.isEmpty()) return false

        return try {
            val exif = ExifInterface(file.absolutePath)
            if (makeValue.isNotEmpty()) {
                exif.setAttribute(ExifInterface.TAG_MAKE, makeValue)
            }
            if (modelValue.isNotEmpty()) {
                exif.setAttribute(ExifInterface.TAG_MODEL, modelValue)
            }
            exif.saveAttributes()
            true
        } catch (_: Exception) {
            false
        }
    }

    /// GPS + 设备信息一次写入，与 iOS writeCaptureMetadata 对齐
    fun writeCaptureMetadata(
        file: File,
        latitude: Double?,
        longitude: Double?,
        make: String?,
        model: String?,
        dateTimeOriginal: String?,
    ): Boolean {
        if (!file.exists()) return false

        val makeValue = make?.trim().orEmpty()
        val modelValue = model?.trim().orEmpty()
        val dateValue = dateTimeOriginal?.trim().orEmpty()
        val hasGps = latitude != null &&
            longitude != null &&
            latitude.isFinite() &&
            longitude.isFinite() &&
            !(latitude == 0.0 && longitude == 0.0)
        if (!hasGps && makeValue.isEmpty() && modelValue.isEmpty() && dateValue.isEmpty()) {
            return false
        }

        return try {
            val exif = ExifInterface(file.absolutePath)
            if (hasGps) {
                exif.setLatLong(latitude!!, longitude!!)
            }
            if (makeValue.isNotEmpty()) {
                exif.setAttribute(ExifInterface.TAG_MAKE, makeValue)
            }
            if (modelValue.isNotEmpty()) {
                exif.setAttribute(ExifInterface.TAG_MODEL, modelValue)
            }
            if (dateValue.isNotEmpty()) {
                exif.setAttribute(ExifInterface.TAG_DATETIME_ORIGINAL, dateValue)
                exif.setAttribute(ExifInterface.TAG_DATETIME, dateValue)
            }
            exif.saveAttributes()
            true
        } catch (_: Exception) {
            false
        }
    }
}

