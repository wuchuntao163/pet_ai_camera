package com.mcxj.flutterPetCamera.gallery

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log

object GalleryMediaHelper {
    private const val TAG = "GalleryMediaHelper"
    private const val ALBUM_SEGMENT = "PetAiCamera"

    fun deleteAppPhotos(
        context: Context,
        activity: Activity?,
        assetIds: List<String>,
        captureIds: List<String>,
    ): Int {
        val resolver = context.contentResolver
        val urisToDelete = linkedSetOf<Uri>()

        for (rawId in assetIds) {
            val id = rawId.toLongOrNull() ?: continue
            urisToDelete.add(
                ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id),
            )
        }

        for (captureId in captureIds) {
            if (captureId.isBlank()) continue
            urisToDelete.addAll(findUrisByCaptureId(resolver, captureId))
        }

        if (urisToDelete.isEmpty()) return 0

        return deleteUris(context, activity, resolver, urisToDelete.toList())
    }

    private fun findUrisByCaptureId(
        resolver: ContentResolver,
        captureId: String,
    ): List<Uri> {
        val uris = linkedSetOf<Uri>()
        val projection = arrayOf(MediaStore.Images.Media._ID)
        val selection = "${MediaStore.Images.Media.DISPLAY_NAME} LIKE ?"
        val selectionArgs = arrayOf("pet_ai_${captureId}%")

        resolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            null,
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                uris.add(
                    ContentUris.withAppendedId(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        id,
                    ),
                )
            }
        }

        return uris.toList()
    }

    private fun deleteUris(
        context: Context,
        activity: Activity?,
        resolver: ContentResolver,
        uris: List<Uri>,
    ): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && activity != null) {
            return deleteWithSystemDialog(activity, resolver, uris)
        }

        var deleted = 0
        val needApproval = mutableListOf<Uri>()
        for (uri in uris) {
            try {
                val count = resolver.delete(uri, null, null)
                if (count > 0) deleted += count
            } catch (e: RecoverableSecurityException) {
                needApproval.add(uri)
            } catch (e: SecurityException) {
                needApproval.add(uri)
                Log.w(TAG, "SecurityException deleting $uri", e)
            } catch (e: Exception) {
                Log.w(TAG, "Failed deleting $uri", e)
            }
        }

        if (needApproval.isNotEmpty() && activity != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                deleted += deleteWithSystemDialog(activity, resolver, needApproval)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                for (uri in needApproval) {
                    try {
                        deleted += resolver.delete(uri, null, null)
                    } catch (_: Exception) {
                    }
                }
            }
        }

        return deleted
    }

    private fun deleteWithSystemDialog(
        activity: Activity,
        resolver: ContentResolver,
        uris: List<Uri>,
    ): Int {
        if (uris.isEmpty()) return 0
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val pendingIntent = MediaStore.createDeleteRequest(resolver, uris)
                activity.startIntentSenderForResult(
                    pendingIntent.intentSender,
                    GALLERY_DELETE_REQUEST_CODE,
                    null,
                    0,
                    0,
                    0,
                )
                // User confirmation required; assume scheduled.
                uris.size
            } else {
                var deleted = 0
                for (uri in uris) {
                    deleted += resolver.delete(uri, null, null)
                }
                deleted
            }
        } catch (e: Exception) {
            Log.e(TAG, "deleteWithSystemDialog failed", e)
            0
        }
    }

    const val GALLERY_DELETE_REQUEST_CODE = 9101
}
