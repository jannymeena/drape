package app.drape.mobile

import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.ByteBufferExtractor
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

/**
 * Finds the body in a photo on the device with MediaPipe's Pose Landmarker
 * (the bundled `pose_landmarker_full.task`). The photo never leaves the phone.
 *
 * `detect` takes the image as raw RGBA (`rgba`, `width`, `height`), decoded
 * and scaled by Flutter so orientation and coordinates match what the app
 * shows. It answers `{poses: [{landmarks, mask, maskWidth, maskHeight}]}`:
 * 33 landmarks as x, y, visibility, presence (x and y as fractions of the
 * image), and the body mask as one byte per pixel (255 = body).
 *
 * Mirrored on iOS by `ios/Runner/PoseDetectorChannel.swift`.
 */
class PoseDetectorChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** Loaded on first use, then kept: loading the model takes a moment. */
    private var landmarker: PoseLandmarker? = null

    init {
        MethodChannel(messenger, NAME).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "detect") {
            result.notImplemented()
            return
        }
        val rgba = call.argument<ByteArray>("rgba")
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        if (rgba == null || width == null || height == null) {
            result.error("bad_args", "rgba, width and height are required", null)
            return
        }
        executor.execute {
            try {
                val poses = detect(rgba, width, height)
                main.post { result.success(poses) }
            } catch (e: Exception) {
                main.post { result.error("pose_failed", e.message, null) }
            }
        }
    }

    private fun landmarker(): PoseLandmarker = landmarker ?: run {
        // Read through the AssetManager (Flutter may store assets compressed)
        // into a direct buffer, which is what MediaPipe loads from.
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(MODEL)
        val bytes = context.assets.open(key).use { it.readBytes() }
        val model = ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder())
        model.put(bytes).rewind()
        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetBuffer(model).build())
            .setRunningMode(RunningMode.IMAGE)
            // Two, so a second person in the shot can be reported.
            .setNumPoses(2)
            .setOutputSegmentationMasks(true)
            .build()
        PoseLandmarker.createFromOptions(context, options).also { landmarker = it }
    }

    private fun detect(rgba: ByteArray, width: Int, height: Int): Map<String, Any> {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(rgba))
        val found = landmarker().detect(BitmapImageBuilder(bitmap).build())
        bitmap.recycle()

        val masks = found.segmentationMasks().orElse(emptyList())
        val poses = found.landmarks().mapIndexed { i, points ->
            val landmarks = DoubleArray(points.size * 4)
            points.forEachIndexed { j, p ->
                landmarks[j * 4] = p.x().toDouble()
                landmarks[j * 4 + 1] = p.y().toDouble()
                landmarks[j * 4 + 2] = p.visibility().orElse(0f).toDouble()
                landmarks[j * 4 + 3] = p.presence().orElse(0f).toDouble()
            }
            val pose = mutableMapOf<String, Any>("landmarks" to landmarks)
            masks.getOrNull(i)?.let { mask ->
                val floats = ByteBufferExtractor.extract(mask)
                    .order(ByteOrder.nativeOrder())
                    .asFloatBuffer()
                val count = mask.width * mask.height
                pose["mask"] = ByteArray(count) { k ->
                    (floats.get(k).coerceIn(0f, 1f) * 255f).toInt().toByte()
                }
                pose["maskWidth"] = mask.width
                pose["maskHeight"] = mask.height
            }
            pose
        }
        return mapOf("poses" to poses)
    }

    companion object {
        const val NAME = "style.zoura.mobile/pose"
        const val MODEL = "assets/models/pose_landmarker_full.task"
    }
}
