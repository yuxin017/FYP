package my.edu.tarumt.collaborative_asg

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Rect
import android.graphics.RectF
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.objectdetector.ObjectDetector
import kotlin.math.abs

internal class CameraPersonDetector(context: Context) : AutoCloseable {
    private val detector = ObjectDetector.createFromOptions(
        context,
        ObjectDetector.ObjectDetectorOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetPath("efficientdet_lite2.tflite").build())
            .setScoreThreshold(0.25f)
            .setMaxResults(MAX_PEOPLE)
            .setCategoryAllowlist(listOf("person"))
            .build()
    )

    fun detect(bitmap: Bitmap): List<List<Double>> {
        val frame = Rect(0, 0, bitmap.width, bitmap.height)
        val candidates = mutableListOf<Candidate>()
        for (region in overlappingRegions(frame)) {
            val crop = Bitmap.createBitmap(bitmap, region.left, region.top, region.width(), region.height())
            try {
                candidates += detectInRegion(crop, region, frame)
            } finally {
                crop.recycle()
            }
        }
        // Closing the MediaPipe image recycles its bitmap, so run the full
        // frame only after creating and processing the crops.
        candidates += detectInRegion(bitmap, frame, frame)

        // Keep the highest-confidence box when two passes find the same person.
        // Overlapping but distinct people can still contribute to the heatmap.
        val people = mutableListOf<RectF>()
        for (candidate in candidates.sortedByDescending { it.score }) {
            if (people.none { isDuplicate(it, candidate.box) }) {
                people.add(candidate.box)
                if (people.size == MAX_PEOPLE) break
            }
        }
        return people.map { box ->
            listOf(
                box.left.toDouble() / frame.width(),
                box.top.toDouble() / frame.height(),
                box.right.toDouble() / frame.width(),
                box.bottom.toDouble() / frame.height()
            )
        }
    }

    private fun detectInRegion(bitmap: Bitmap, region: Rect, frame: Rect): List<Candidate> {
        val image = BitmapImageBuilder(bitmap).build()
        try {
            return detector.detect(image).detections().mapNotNull { detection ->
                val box = detection.boundingBox()
                val score = detection.categories().firstOrNull()?.score() ?: return@mapNotNull null
                // Skip fragments cut by a crop boundary. The full frame and
                // overlapping crop can still supply a complete detection.
                val margin = 3
                if ((region.left > frame.left && box.left <= margin) ||
                    (region.top > frame.top && box.top <= margin) ||
                    (region.right < frame.right && box.right >= bitmap.width - margin) ||
                    (region.bottom < frame.bottom && box.bottom >= bitmap.height - margin)
                ) return@mapNotNull null

                val mapped = RectF(
                    region.left + box.left.coerceIn(0f, bitmap.width.toFloat()),
                    region.top + box.top.coerceIn(0f, bitmap.height.toFloat()),
                    region.left + box.right.coerceIn(0f, bitmap.width.toFloat()),
                    region.top + box.bottom.coerceIn(0f, bitmap.height.toFloat())
                )
                if (mapped.isEmpty) null else Candidate(mapped, score)
            }
        } finally {
            image.close()
        }
    }

    private fun overlappingRegions(frame: Rect): List<Rect> {
        val width = frame.width()
        val height = frame.height()
        return when {
            width >= 1.3 * height -> {
                val cropWidth = (width * .65).toInt()
                listOf(Rect(0, 0, cropWidth, height), Rect(width - cropWidth, 0, width, height))
            }
            height >= 1.3 * width -> {
                val cropHeight = (height * .65).toInt()
                listOf(Rect(0, 0, width, cropHeight), Rect(0, height - cropHeight, width, height))
            }
            else -> emptyList()
        }
    }

    private fun isDuplicate(first: RectF, second: RectF): Boolean {
        val width = (minOf(first.right, second.right) - maxOf(first.left, second.left)).coerceAtLeast(0f)
        val height = (minOf(first.bottom, second.bottom) - maxOf(first.top, second.top)).coerceAtLeast(0f)
        val shared = width * height
        val firstArea = first.width() * first.height()
        val secondArea = second.width() * second.height()
        val combined = firstArea + secondArea - shared
        if (shared >= 0.50 * combined) return true

        // A torso-only box can have low IoU with a full-body box of the same
        // person. Require their upper edges and horizontal centers to align.
        return shared >= 0.80 * minOf(firstArea, secondArea) &&
            abs(first.centerX() - second.centerX()) <= 0.20 * minOf(first.width(), second.width()) &&
            abs(first.top - second.top) <= 0.20 * minOf(first.height(), second.height())
    }

    override fun close() = detector.close()

    private data class Candidate(val box: RectF, val score: Float)

    private companion object {
        const val MAX_PEOPLE = 60
    }
}
