import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/src/orchestrator/camera_context.dart';

enum CaptureMode {
  photo,
  video,
  preview,
  // ignore: constant_identifier_names
  analysis_only;

  void changeState(CameraContext cameraContext) {
    if (this == CaptureMode.photo) {
      cameraContext.changeState<PhotoCameraState>();
    } else if (this == CaptureMode.video) {
      cameraContext.changeState<VideoCameraState>();
    } else if (this == CaptureMode.preview) {
      cameraContext.changeState<PreviewCameraState>();
    } else if (this == CaptureMode.analysis_only) {
      cameraContext.changeState<AnalysisCameraState>();
    }
    throw "State not recognized";
  }
}
