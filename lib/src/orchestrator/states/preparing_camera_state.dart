import 'dart:async';
import 'dart:io';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:camerawesome/src/orchestrator/exceptions/camera_states_exceptions.dart';
import 'package:camerawesome/src/orchestrator/models/camera_physical_button.dart';

/// When is not ready
class PreparingCameraState extends CameraState {
  /// this is the next state we are preparing to
  final CaptureMode nextCaptureMode;

  /// plugin user can execute some code once the permission has been granted
  final OnPermissionsResult? onPermissionsResult;

  PreparingCameraState(
    super.cameraContext,
    this.nextCaptureMode, {
    this.onPermissionsResult,
  });

  @override
  CaptureMode? get captureMode => null;

  /// Obtains data from sensors and update user's current
  /// sensor config in order to contain more data.
  Future<void> _configureSensorDevices () async {
    SensorDeviceData data = await CamerawesomePlugin.getSensors();

    Set<SensorTypeDevice> devices = data.availableSensors.toSet();
    // /// List all sensors and obtain its device data
    // for (Sensor sensor in sensorConfig.sensors) {
    //   /// If sensor position is not null, obtain all sensor device data
    //   /// from that position
    //   if (sensor.position == SensorPosition.front) {
    //     devices.addAll (data.frontSensors.nonNulls);
    //   } else if (sensor.position == SensorPosition.back) {
    //     devices.addAll (data.backSensors.nonNulls);
    //   } else if (sensor.deviceId != null) {
    //     SensorTypeDevice? device = data.availableSensors.firstWhereOrNull (
    //       (dev) => dev.uid == sensor.deviceId
    //     );
    //     if (device != null) {
    //       devices.add (
    //         device
    //       );
    //     }
    //   } else if (sensor.type != null) {
    //     SensorTypeDevice? device = data.deviceFromType(sensor.type!);
    //     if (device != null) {
    //       devices.add (device);
    //     }
    //   }
    // }

    cameraContext.updateSensorTypeDevices (devices);
  }

  Future<void> start() async {
    print ("Starting state!");
    /// Since this is the first state on Camera Context, sensor devices must 
    /// be configured before setting any other state
    await _configureSensorDevices ();
    /// Let devices are obtained and configured before initializing any mode 
    final filter = cameraContext.filterController.valueOrNull;
    if (filter != null) {
      await setFilter(filter);
    }
    /// Initialize CameraPlugin
    await Future.delayed(
      const Duration(milliseconds: 500), 
      () async {
        await _init(
          enableImageStream: cameraContext.imageAnalysisEnabled,
          enablePhysicalButton: cameraContext.enablePhysicalButton,
        );
      }
    );
    
    switch (nextCaptureMode) {
      case CaptureMode.photo:
        await _startPhotoMode();
        break;
      case CaptureMode.video:
        await _startVideoMode();
        break;
      case CaptureMode.preview:
        await _startPreviewMode();
        break;
      case CaptureMode.analysis_only:
        await _startAnalysisMode();
        break;
    }
    await cameraContext.analysisController?.setup();
    if (nextCaptureMode == CaptureMode.analysis_only) {
      // Analysis controller needs to be setup before going to AnalysisCameraState
      cameraContext.changeState<AnalysisCameraState>( );
    }

    if (cameraContext.enablePhysicalButton) {
      initPhysicalButton();
    }
  }

  /// subscription for permissions
  StreamSubscription? _permissionStreamSub;

  /// subscription for physical button
  StreamSubscription? _physicalButtonStreamSub;

  Future<void> initPermissions(
    SensorConfig sensorConfig, {
    required bool enableImageStream,
    required bool enablePhysicalButton,
  }) async {
    // wait user accept permissions to init widget completely on android
    if (Platform.isAndroid) {
      _permissionStreamSub =
          CamerawesomePlugin.listenPermissionResult()!.listen(
        (res) {
          if (res && !_isReady) {
            _init(
              enableImageStream: enableImageStream,
              enablePhysicalButton: enablePhysicalButton,
            );
          }
          if (onPermissionsResult != null) {
            onPermissionsResult!(res);
          }
        },
      );
    }
    final grantedPermissions =
        await CamerawesomePlugin.checkAndRequestPermissions(
      cameraContext.exifPreferences.saveGPSLocation,
      checkCameraPermissions: true,
      checkMicrophonePermissions:
          cameraContext.initialCaptureMode == CaptureMode.video,
    );
    if (cameraContext.exifPreferences.saveGPSLocation &&
        !(grantedPermissions?.contains(CamerAwesomePermission.location) ==
            true)) {
      cameraContext.exifPreferences = ExifPreferences(saveGPSLocation: false);
      cameraContext.state
          .when(onPhotoMode: (pm) => pm.shouldSaveGpsLocation(false));
    }
    if (onPermissionsResult != null) {
      onPermissionsResult!(
          grantedPermissions?.hasRequiredPermissions() == true);
    }
  }

  void initPhysicalButton() {
    _physicalButtonStreamSub?.cancel();
    _physicalButtonStreamSub =
        CamerawesomePlugin.listenPhysicalButton()!.listen(
      (res) async {
        if (res == CameraPhysicalButton.volume_down ||
            res == CameraPhysicalButton.volume_up) {
          cameraContext.state.when(
            onPhotoMode: (pm) => pm.takePhoto(),
            onVideoMode: (vm) => vm.startRecording(),
            onVideoRecordingMode: (vrm) => vrm.stopRecording(),
          );
        }
      },
    );
  }

  @override
  void setState(CaptureMode captureMode) {
    throw CameraNotReadyException(
      message:
          '''You can't change current state while camera is in PreparingCameraState''',
    );
  }

  /////////////////////////////////////
  // PRIVATES
  /////////////////////////////////////

  Future _startVideoMode() async {
    cameraContext.changeState<VideoCameraState>();

    return CamerawesomePlugin.start();
  }

  Future _startPhotoMode() async {
    cameraContext.changeState<PhotoCameraState>();

    return CamerawesomePlugin.start();
  }

  Future _startPreviewMode() async {
    cameraContext.changeState<PreviewCameraState>();

    return CamerawesomePlugin.start();
  }

  Future _startAnalysisMode() async {
    // On iOS, we need to start the camera to get the first frame because there
    // is no "AnalysisMode" at all.
    if (Platform.isIOS) {
      return CamerawesomePlugin.start();
    }
  }

  bool _isReady = false;

  // TODO Refactor this (make it stream providing state)
  Future<bool> _init({
    required bool enableImageStream,
    required bool enablePhysicalButton,
  }) async {
    initPermissions(
      super.sensorConfig,
      enableImageStream: enableImageStream,
      enablePhysicalButton: enablePhysicalButton,
    );
    await CamerawesomePlugin.init(
      super.sensorConfig,
      enableImageStream,
      enablePhysicalButton,
      captureMode: nextCaptureMode,
      exifPreferences: cameraContext.exifPreferences,
      videoOptions: saveConfig?.videoOptions,
      mirrorFrontCamera: saveConfig?.mirrorFrontCamera ?? false,
    );
    _isReady = true;
    return _isReady;
  }

  @override
  void dispose() {
    _permissionStreamSub?.cancel();
    _physicalButtonStreamSub?.cancel();
  }
}
