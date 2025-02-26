import 'package:camerawesome/camerawesome_plugin.dart';

enum CameraAspectRatios {
  ratio_16_9,
  ratio_4_3,
  ratio_1_1; // only for iOS

  CameraAspectRatios get defaultRatio => CameraAspectRatios.ratio_4_3;
  double get ratio {
    switch (this) {
      case CameraAspectRatios.ratio_16_9:
        return 16/9;
      case CameraAspectRatios.ratio_4_3:
        return 4/3;
      case CameraAspectRatios.ratio_1_1:
        return 1;
    }
  }
}

enum SensorPosition {
  front,
  back,
}

class Sensor {
  SensorPosition? position;
  SensorType? type;
  String? deviceId;

  Sensor._({
    this.position,
    this.type,
    this.deviceId,
  });

  Sensor.position(SensorPosition position)
      : this._(
          position: position,
        );

  Sensor.type(SensorType type)
      : this._(
          type: type,
        );

  Sensor.id(String deviceId)
      : this._(
          deviceId: deviceId,
        );
}
