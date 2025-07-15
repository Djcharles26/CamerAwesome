import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/src/orchestrator/camera_context.dart';

enum CaptureMode {
  photo,
  video,
  preview;

  void changeState(CameraContext cameraContext) {
    if (this == CaptureMode.photo) {
      cameraContext.changeState<PhotoCameraState>();
    } else if (this == CaptureMode.video) {
      cameraContext.changeState<VideoCameraState>();
    } else if (this == CaptureMode.preview) {
      cameraContext.changeState<PreviewCameraState>();
    }
    throw "State not recognized";
  }
}
