package my.edu.tarumt.collaborative_asg

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.SystemClock
import android.util.Log
import android.view.WindowManager
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.webrtc.VideoFrame
import org.webrtc.YuvHelper
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal class AttractionCameraBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "themepark/attraction-camera")
    private val inference = Executors.newSingleThreadExecutor()
    private var session: Session? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val trackId = call.argument<String>("trackId")
                    val track = trackId?.let { FlutterWebRTCPlugin.sharedSingleton?.getLocalTrack(it) }
                    if (track !is LocalVideoTrack) {
                        result.error("camera-unavailable", "The camera could not start.", null)
                    } else {
                        stop()
                        val next = Session(track, trackId!!)
                        session = next
                        track.addProcessor(next)
                        activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                }
                "stop" -> { stop(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    fun stop() {
        val previous = session ?: return
        session = null
        previous.active = false
        previous.track.removeProcessor(previous)
        inference.execute { previous.detector?.close() }
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    fun dispose() {
        stop()
        channel.setMethodCallHandler(null)
        inference.shutdown()
    }

    private inner class Session(val track: LocalVideoTrack, val trackId: String) : LocalVideoTrack.ExternalVideoFrameProcessing {
        @Volatile var active = true
        var detector: CameraPersonDetector? = null
        private var lastFrame = 0L
        private val busy = AtomicBoolean(false)

        override fun onFrame(frame: VideoFrame): VideoFrame {
            val now = SystemClock.elapsedRealtime()
            if (!active || now - lastFrame < 500 || !busy.compareAndSet(false, true)) return frame
            lastFrame = now
            frame.retain()
            inference.execute {
                try {
                    val bitmap = try {
                        if (active) bitmapOf(frame) else null
                    } finally {
                        // Return the camera texture before running model inference.
                        frame.release()
                    }
                    if (bitmap != null) {
                        try {
                            if (active) detect(bitmap)
                        } finally {
                            bitmap.recycle()
                        }
                    }
                } catch (error: Throwable) {
                    if (error !is Exception && error !is LinkageError) throw error
                    Log.e("AttractionCamera", "Person detection failed", error)
                    active = false
                    activity.runOnUiThread {
                        if (session === this) channel.invokeMethod("detectorError", trackId)
                    }
                } finally {
                    busy.set(false)
                }
            }
            return frame
        }

        private fun detect(bitmap: Bitmap) {
            val startingDetector = detector == null
            val model = detector ?: CameraPersonDetector(activity).also { detector = it }
            val boxes = model.detect(bitmap)
            if (startingDetector) Log.i("AttractionCamera", "Person detection is ready")
            activity.runOnUiThread {
                if (session === this && active) {
                    channel.invokeMethod("detections", mapOf("trackId" to trackId, "boxes" to boxes))
                }
            }
        }
    }

    private fun bitmapOf(frame: VideoFrame): Bitmap? {
        val buffer = frame.buffer.toI420() ?: return null
        val width = buffer.width
        val height = buffer.height
        val jpeg = ByteArrayOutputStream()
        try {
            if (width % 2 != 0 || height % 2 != 0) return null
            val nv21 = ByteBuffer.allocateDirect(width * height * 3 / 2)
            YuvHelper.I420ToNV12(buffer.dataY, buffer.strideY, buffer.dataV, buffer.strideV,
                buffer.dataU, buffer.strideU, nv21, width, height)
            val bytes = ByteArray(nv21.capacity())
            nv21.rewind()
            nv21.get(bytes)
            if (!YuvImage(bytes, ImageFormat.NV21, width, height, null)
                    .compressToJpeg(Rect(0, 0, width, height), 90, jpeg)) return null
        } finally { buffer.release() }
        val encoded = jpeg.toByteArray()
        val bitmap = BitmapFactory.decodeByteArray(encoded, 0, encoded.size) ?: return null
        if (frame.rotation == 0) return bitmap
        val rotation = Matrix().apply { postRotate(frame.rotation.toFloat()) }
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, rotation, true)
        if (rotated !== bitmap) bitmap.recycle()
        return rotated
    }
}
