package com.apparence.camerawesome.cameraX

import android.annotation.SuppressLint
import android.app.Activity
import android.hardware.camera2.CameraCharacteristics
import android.util.Log
import android.util.Rational
import android.util.Size
import android.view.Surface
import androidx.camera.camera2.internal.compat.CameraCharacteristicsCompat
import androidx.camera.camera2.internal.compat.quirk.CamcorderProfileResolutionQuirk
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.CameraFilter
import androidx.camera.core.AspectRatio
import androidx.camera.core.Camera
import androidx.camera.core.CameraControl
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.ConcurrentCamera
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageCapture
import androidx.camera.core.MirrorMode
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceRequest
import androidx.camera.core.UseCaseGroup
import androidx.camera.core.ViewPort
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.*
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.apparence.camerawesome.CamerawesomePlugin
import com.apparence.camerawesome.models.FlashMode
import com.apparence.camerawesome.sensors.SensorOrientation
import com.apparence.camerawesome.utils.isMultiCamSupported
import com.apparence.camerawesome.utils.getSensorType
import com.apparence.camerawesome.utils.getPigeonPosition
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.Executor

/// Hold the settings of the camera and use cases in this class and
/// call updateLifecycle() to refresh the state
data class CameraXState(
    private var cameraProvider: ProcessCameraProvider,
    val textureEntries: Map<String, TextureRegistry.SurfaceTextureEntry>,
//    var cameraSelector: CameraSelector,
    var sensors: List<PigeonSensor>,
    var imageCaptures: MutableList<ImageCapture> = mutableListOf(),
    var videoCaptures: MutableMap<PigeonSensor, VideoCapture<Recorder>> = mutableMapOf(),
    var previews: MutableList<Preview>? = null,
    var concurrentCamera: ConcurrentCamera? = null,
    var previewCamera: Camera? = null,
    private var currentCaptureMode: CaptureModes,
    var enableAudioRecording: Boolean = true,
    var recordings: MutableList<Recording>? = null,
    var photoSize: Size? = null,
    var previewSize: Size? = null,
    var aspectRatio: Int? = null,
    // Rational is used only in ratio 1:1
    var rational: Rational = Rational(3, 4),
    var flashMode: FlashMode = FlashMode.NONE,
    val onStreamReady: (state: CameraXState) -> Unit,
    var mirrorFrontCamera: Boolean = false,
    val videoRecordingQuality: VideoRecordingQuality?,
    val videoOptions: AndroidVideoOptions?,
) : EventChannel.StreamHandler, SensorOrientation {


    private val mainCameraInfos: CameraInfo
        @SuppressLint("RestrictedApi") get() {
            if (previewCamera == null && concurrentCamera == null) {
                throw Exception("Trying to access main camera infos before setting the preview")
            }
            return previewCamera?.cameraInfo ?: concurrentCamera?.cameras?.first()?.cameraInfo!!
        }

    private val mainCameraControl: CameraControl
        @SuppressLint("RestrictedApi") get() {
            if (previewCamera == null && concurrentCamera == null) {
                throw Exception("Trying to access main camera control before setting the preview")
            }
            return previewCamera?.cameraControl
                ?: concurrentCamera?.cameras?.first()?.cameraControl!!
        }

    val maxZoomRatio: Double
        @SuppressLint("RestrictedApi") get() = mainCameraInfos.zoomState.value!!.maxZoomRatio.toDouble()


    val minZoomRatio: Double
        get() = mainCameraInfos.zoomState.value!!.minZoomRatio.toDouble()


    val portrait: Boolean
        get() = mainCameraInfos.sensorRotationDegrees % 180 == 0

    fun executor(activity: Activity): Executor {
        return ContextCompat.getMainExecutor(activity)
    }

    @SuppressLint("RestrictedApi", "UnsafeOptInUsageError")
    @ExperimentalCamera2Interop
    private fun createCameraSelector(sensor: PigeonSensor, cameraProvider: ProcessCameraProvider): CameraSelector {
        return CameraSelector.Builder()
            .requireLensFacing(if (sensor.position == PigeonSensorPosition.FRONT) CameraSelector.LENS_FACING_FRONT else CameraSelector.LENS_FACING_BACK)
            .addCameraFilter(CameraFilter { cameraInfos ->
                val list = mutableListOf<CameraInfo>()
                
                // First try to find exact match by device ID
                if (sensor.deviceId != null) {
                    cameraInfos.forEach { cameraInfo ->
                        val camera2Info = Camera2CameraInfo.from(cameraInfo)
                        if (camera2Info.cameraId == sensor.deviceId) {
                            list.add(cameraInfo)
                            return@CameraFilter list
                        }
                    }
                }
                
                // Then try to match by sensor type and position
                cameraInfos.forEach { cameraInfo ->
                    Camera2CameraInfo.from(cameraInfo).let { camera2Info ->
                        if (camera2Info.getPigeonPosition() == sensor.position && 
                            (camera2Info.getSensorType() == sensor.type || sensor.type == PigeonSensorType.UNKNOWN)) {
                            list.add(cameraInfo)
                        }
                    }
                }
                
                // If no camera found, only filter based on the sensor position
                if (list.isEmpty()) {
                    cameraInfos.forEach { cameraInfo ->
                        Camera2CameraInfo.from(cameraInfo).let { camera2Info ->
                            if (camera2Info.getPigeonPosition() == sensor.position) {
                                list.add(cameraInfo)
                            }
                        }
                    }
                }
                return@CameraFilter list
            })
            .build()
    }

    @SuppressLint("RestrictedApi", "UnsafeOptInUsageError")
    @ExperimentalCamera2Interop
    fun updateLifecycle(activity: Activity) {
        previews = mutableListOf()
        imageCaptures.clear()
        videoCaptures.clear()
        if (cameraProvider.isMultiCamSupported() && sensors.size > 1) {
            val singleCameraConfigs = mutableListOf<ConcurrentCamera.SingleCameraConfig>()
            var isFirst = true
            for ((index, sensor) in sensors.withIndex()) {
                val useCaseGroupBuilder = UseCaseGroup.Builder()

                val cameraSelector = createCameraSelector(sensor, cameraProvider)


                val preview = if (aspectRatio != null) {
                    Preview.Builder().setTargetAspectRatio(aspectRatio!!)
                        .setCameraSelector(cameraSelector).build()
                } else {
                    Preview.Builder().setCameraSelector(cameraSelector).build()
                }
                preview.setSurfaceProvider(
                    surfaceProvider(executor(activity), sensor.deviceId ?: "$index")
                )
                useCaseGroupBuilder.addUseCase(preview)
                previews!!.add(preview)

                if (currentCaptureMode == CaptureModes.PHOTO) {
                    val imageCapture = ImageCapture.Builder().setCameraSelector(cameraSelector)
//                .setJpegQuality(100)
                        .apply {
                            //photoSize?.let { setTargetResolution(it) }
                            if (rational.denominator != rational.numerator) {
                                setTargetAspectRatio(aspectRatio ?: AspectRatio.RATIO_4_3)
                            }

                            setFlashMode(
                                if (isFirst) when (flashMode) {
                                    FlashMode.ALWAYS, FlashMode.ON -> ImageCapture.FLASH_MODE_ON
                                    FlashMode.AUTO -> ImageCapture.FLASH_MODE_AUTO
                                    else -> ImageCapture.FLASH_MODE_OFF
                                }
                                else ImageCapture.FLASH_MODE_OFF
                            )
                        }.build()
                    useCaseGroupBuilder.addUseCase(imageCapture)
                    imageCaptures.add(imageCapture)
                } else {
                    val videoCapture = buildVideoCapture(videoOptions)
                    useCaseGroupBuilder.addUseCase(videoCapture)
                    videoCaptures[sensor] = videoCapture
                }

                isFirst = false
                useCaseGroupBuilder.setViewPort(
                    ViewPort.Builder(rational, Surface.ROTATION_0).build()
                )
                singleCameraConfigs.add(
                    ConcurrentCamera.SingleCameraConfig(
                        cameraSelector,
                        useCaseGroupBuilder.build(), activity as LifecycleOwner,
                    )
                )
            }

            cameraProvider.unbindAll()
            previewCamera = null
            concurrentCamera = cameraProvider.bindToLifecycle(
                singleCameraConfigs
            )
            // Only set flash to the main camera (the first one)
            concurrentCamera!!.cameras.first().cameraControl.enableTorch(flashMode == FlashMode.ALWAYS)
        } else {
            val useCaseGroupBuilder = UseCaseGroup.Builder()
            // Handle single camera
            val cameraSelector = createCameraSelector(sensors.first(), cameraProvider)
            // Preview
            previews!!.add(
                if (aspectRatio != null) {
                    Preview.Builder().setTargetAspectRatio(aspectRatio!!)
                        .setCameraSelector(cameraSelector).build()
                } else {
                    Preview.Builder().setCameraSelector(cameraSelector).build()
                }
            )

            previews!!.first().setSurfaceProvider(
                surfaceProvider(executor(activity), sensors.first().deviceId ?: "0")
            )
            useCaseGroupBuilder.addUseCase(previews!!.first())

            if (currentCaptureMode == CaptureModes.PHOTO) {
                val imageCapture = ImageCapture.Builder().setCameraSelector(cameraSelector)
//                .setJpegQuality(100)
                    .apply {
                        //photoSize?.let { setTargetResolution(it) }
                        if (rational.denominator != rational.numerator) {
                            setTargetAspectRatio(aspectRatio ?: AspectRatio.RATIO_4_3)
                        }
                        setFlashMode(
                            when (flashMode) {
                                FlashMode.ALWAYS, FlashMode.ON -> ImageCapture.FLASH_MODE_ON
                                FlashMode.AUTO -> ImageCapture.FLASH_MODE_AUTO
                                else -> ImageCapture.FLASH_MODE_OFF
                            }
                        )
                    }.build()
                useCaseGroupBuilder.addUseCase(imageCapture)
                imageCaptures.add(imageCapture)
            } else if (currentCaptureMode == CaptureModes.VIDEO) {
                val videoCapture = buildVideoCapture(videoOptions)
                useCaseGroupBuilder.addUseCase(videoCapture)
                videoCaptures[sensors.first()] = videoCapture
            }


            cameraProvider.unbindAll()
            // TODO Orientation might be wrong, to be verified
            useCaseGroupBuilder.setViewPort(ViewPort.Builder(rational, Surface.ROTATION_0).build())
                .build()

            concurrentCamera = null
            previewCamera = cameraProvider.bindToLifecycle(
                activity as LifecycleOwner,
                cameraSelector,
                useCaseGroupBuilder.build(),
            )
            previewCamera!!.cameraControl.enableTorch(flashMode == FlashMode.ALWAYS)
        }
    }

    private fun buildVideoCapture(videoOptions: AndroidVideoOptions?): VideoCapture<Recorder> {
        val recorderBuilder = Recorder.Builder()
        // Aspect ratio is handled by the setViewPort on the UseCaseGroup
        if (videoRecordingQuality != null) {
            val quality = when (videoRecordingQuality) {
                VideoRecordingQuality.LOWEST -> Quality.LOWEST
                VideoRecordingQuality.SD -> Quality.SD
                VideoRecordingQuality.HD -> Quality.HD
                VideoRecordingQuality.FHD -> Quality.FHD
                VideoRecordingQuality.UHD -> Quality.UHD
                else -> Quality.HIGHEST
            }
            recorderBuilder.setQualitySelector(
                QualitySelector.from(
                    quality,
                    if (videoOptions?.fallbackStrategy == QualityFallbackStrategy.LOWER) FallbackStrategy.lowerQualityOrHigherThan(
                        quality
                    )
                    else FallbackStrategy.higherQualityOrLowerThan(quality)
                )
            )
        }
        if (videoOptions?.bitrate != null) {
            recorderBuilder.setTargetVideoEncodingBitRate(videoOptions.bitrate.toInt())
        }
        val recorder = recorderBuilder.build()
        return VideoCapture.Builder<Recorder>(recorder)
            .setMirrorMode(if (mirrorFrontCamera) MirrorMode.MIRROR_MODE_ON_FRONT_ONLY else MirrorMode.MIRROR_MODE_OFF)
            .build()
    }

    @SuppressLint("RestrictedApi")
    private fun surfaceProvider(executor: Executor, cameraId: String): Preview.SurfaceProvider {
//        Log.d("SurfaceProviderCamX", "Creating surface provider for $cameraId")
        return Preview.SurfaceProvider { request: SurfaceRequest ->
            val resolution = request.resolution
            val texture = textureEntries[cameraId]!!.surfaceTexture()
            texture.setDefaultBufferSize(resolution.width, resolution.height)
            val surface = Surface(texture)
            request.provideSurface(surface, executor) {
//                Log.d("CameraX", "Surface request result: ${it.resultCode}")
                surface.release()
            }
        }
    }

    fun setLinearZoom(zoom: Float) {
        mainCameraControl.setLinearZoom(zoom)
    }

    fun startFocusAndMetering(autoFocusAction: FocusMeteringAction) {
        mainCameraControl.startFocusAndMetering(autoFocusAction)
    }

    fun setCaptureMode(captureMode: CaptureModes) {
        currentCaptureMode = captureMode
        when (currentCaptureMode) {
            CaptureModes.PHOTO -> {
                // Release video related stuff
                videoCaptures.clear()
                recordings?.forEach { it.close() }
                recordings = null

            }

            CaptureModes.VIDEO -> {
                // Release photo related stuff
                imageCaptures.clear()
            }

            else -> {
                // Preview mode

                // Release video related stuff
                videoCaptures.clear()
                recordings?.forEach { it.close() }
                recordings = null

                // Release photo related stuff
                imageCaptures.clear()
            }
        }
    }

    @SuppressLint("RestrictedApi", "UnsafeOptInUsageError")
    fun previewSizes(): List<Size> {
        val characteristics = CameraCharacteristicsCompat.toCameraCharacteristicsCompat(
            Camera2CameraInfo.extractCameraCharacteristics(mainCameraInfos),
            Camera2CameraInfo.from(mainCameraInfos).cameraId
        )
        return CamcorderProfileResolutionQuirk(characteristics).supportedResolutions
    }

    fun qualityAvailableSizes(): List<String> {
        val supportedQualities = QualitySelector.getSupportedQualities(mainCameraInfos)
        return supportedQualities.map {
            when (it) {
                Quality.UHD -> {
                    "UHD"
                }

                Quality.HIGHEST -> {
                    "HIGHEST"
                }

                Quality.FHD -> {
                    "FHD"
                }

                Quality.HD -> {
                    "HD"
                }

                Quality.LOWEST -> {
                    "LOWEST"
                }

                Quality.SD -> {
                    "SD"
                }

                else -> {
                    "unknown"
                }
            }
        }
    }

    fun stop() {
        cameraProvider.unbindAll()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        // Image stream not supported anymore
    }

    override fun onCancel(arguments: Any?) {
        // Image stream not supported anymore
    }

    override fun onOrientationChanged(orientation: Int) {
        // Image analysis not supported anymore
    }

    fun updateAspectRatio(newAspectRatio: String) {
        // In CameraX, aspect ratio is an Int. RATIO_4_3 = 0 (default), RATIO_16_9 = 1
        aspectRatio = if (newAspectRatio == "RATIO_16_9") 1 else 0
        rational = when (newAspectRatio) {
            "RATIO_16_9" -> Rational(9, 16)
            "RATIO_1_1" -> Rational(1, 1)
            else -> Rational(3, 4)
        }
    }
}