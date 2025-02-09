enum SensorType {
  /// A built-in wide-angle camera.
  ///
  /// The wide angle sensor is the default sensor for iOS
  wideAngle (1),

  /// A built-in camera with a shorter focal length than that of the wide-angle camera.
  ultraWideAngle (0),

  /// A built-in camera device with a longer focal length than the wide-angle camera.
  telephoto (2),

  /// A device that consists of two cameras, one Infrared and one YUV.
  ///
  /// iOS only
  trueDepth (3),

  unknown (4);

  final int order;

  SensorType get defaultSensorType => SensorType.wideAngle;

  const SensorType (this.order);
}

class SensorTypeDevice {
  final SensorType sensorType;

  /// A localized device name for display in the user interface.
  final String name;

  /// The current exposure ISO value.
  final num iso;

  /// A Boolean value that indicates whether the flash is currently available for use.
  final bool flashAvailable;

  /// An identifier that uniquely identifies the device.
  final String uid;

  /// Available min zoom;
  final num minZoom;

  /// Available Optical (no distorsion) zoom
  final num maxOpticalZoom;

  /// Available Digital Zoom;
  final num maxDigitalZoom;

  SensorTypeDevice({
    required this.sensorType,
    required this.name,
    required this.iso,
    required this.flashAvailable,
    required this.uid,
    required this.minZoom,
    required this.maxOpticalZoom,
    required this.maxDigitalZoom
  });

  @override
  String toString() {
    return "Sensor: $sensorType - $name\n"
      "ISO: $iso\n"
      "Flash Available: $flashAvailable\n"
      "UID: $uid\n"
      "Min Zoom: $minZoom\n"
      "Max Opt Zoom: $maxOpticalZoom - Max Dig Zoom: $maxDigitalZoom";
  }
}

// TODO: instead of storing SensorTypeDevice values,
// this would be useful when CameraX will support multiple sensors.
// store them in a list of SensorTypeDevice.
// ex:
// List<SensorTypeDevice> wideAngle;
// List<SensorTypeDevice> ultraWideAngle;

class SensorDeviceData {
  /// A built-in wide-angle camera.
  ///
  /// The wide angle sensor is the default sensor for iOS
  SensorTypeDevice? wideAngle;

  /// A built-in camera with a shorter focal length than that of the wide-angle camera.
  SensorTypeDevice? ultraWideAngle;

  /// A built-in camera device with a longer focal length than the wide-angle camera.
  SensorTypeDevice? telephoto;

  /// A device that consists of two cameras, one Infrared and one YUV.
  ///
  /// iOS only
  SensorTypeDevice? trueDepth;

  SensorDeviceData({
    this.wideAngle,
    this.ultraWideAngle,
    this.telephoto,
    this.trueDepth,
  });

  List<SensorTypeDevice> get availableSensors {
    return [
      wideAngle,
      ultraWideAngle,
      telephoto,
      trueDepth,
    ].where((element) => element != null).cast<SensorTypeDevice>().toList();
  }

  List<SensorTypeDevice?> get backSensors => [
    wideAngle,
    ultraWideAngle,
    telephoto,
  ];

  List<SensorTypeDevice?> get frontSensors => [
    trueDepth
  ];

  int get availableBackSensors => [
        wideAngle,
        ultraWideAngle,
        telephoto,
      ].nonNulls.length;

  int get availableFrontSensors => [
        trueDepth,
      ].nonNulls.length;

  SensorTypeDevice? deviceFromType (SensorType type) {
    switch (type) {
      case SensorType.wideAngle:
        return wideAngle;
      case SensorType.ultraWideAngle:
        return ultraWideAngle;
      case SensorType.telephoto:
        return telephoto;
      case SensorType.trueDepth:
        return trueDepth;
      case SensorType.unknown:
        return null;
    }
  }
}
