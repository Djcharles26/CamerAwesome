# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

CamerAwesome is a Flutter plugin providing comprehensive camera functionality with support for photos, videos, filters, and multi-camera capabilities. It uses Pigeon for type-safe platform communication, with Android implementation using CameraX and iOS using AVFoundation.

## Essential Commands

### Development Workflow
```bash
# 1. Clean and get dependencies
flutter clean
flutter pub get

# 2. Generate platform channel code (after modifying pigeons/interface.dart)
bash pigeons/pigeon.sh

# 3. Run linting
flutter analyze

# 4. Run unit tests
flutter test

# 5. Run integration tests
cd example
patrol test --target integration_test/bundled_test.dart
```

### Building
```bash
# Build example app
cd example
flutter build apk  # Android
flutter build ios  # iOS

# Android native build
cd android
./gradlew build

# iOS (requires pod install first)
cd example/ios
pod install
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug
```

### Testing
```bash
# Unit tests
flutter test

# Integration tests with Patrol
patrol test --target integration_test/bundled_test.dart

# Android instrumentation tests
cd example/android
./gradlew :app:connectedDebugAndroidTest -Ptarget=$(pwd)/../integration_test/bundled_test.dart

# Firebase Test Lab
cd example/scripts
bash run_firebase_test_lab.sh
```

## Architecture Overview

### State Machine Design
The camera operates through a state machine pattern with these states:
- `PreparingCameraState` - Handles permissions and initialization
- `PhotoCameraState` - Ready to capture photos
- `VideoCameraState` - Ready to record videos  
- `VideoRecordingCameraState` - Actively recording
- `PreviewCameraState` - Preview-only mode

State transitions are managed by `CameraContext` which serves as the central orchestrator.

### Platform Communication
Uses Pigeon for type-safe platform channels:
- **Interface Definition**: `pigeons/interface.dart`
- **Generated Code**: `lib/pigeon.dart` (Dart), Android Kotlin, iOS Objective-C
- **Event Channels**: 
  - `camerawesome/orientation` - Device orientation
  - `camerawesome/physical_button` - Volume buttons
  - `camerawesome/permissions` - Permission status

### Key Components
- **CameraContext** (`lib/src/orchestrator/camera_context.dart`): Central state management using RxDart BehaviorSubjects
- **CameraAwesomeBuilder** (`lib/src/widgets/camera_awesome_builder.dart`): Main widget for building camera UIs
- **SensorConfig** (`lib/src/orchestrator/models/sensor_config.dart`): Camera configuration (sensors, aspect ratio, zoom, flash)

### Native Implementations
- **Android**: `android/src/main/kotlin/com/apparence/camerawesome/` - Uses CameraX API
- **iOS**: `ios/Classes/` - Uses AVFoundation framework

### Adding New Features
1. Update Pigeon interface in `pigeons/interface.dart`
2. Run `bash pigeons/pigeon.sh` to regenerate platform code
3. Implement in native platforms:
   - Android: Kotlin files in `android/src/main/kotlin/`
   - iOS: Objective-C files in `ios/Classes/`
4. Update relevant camera states if needed
5. Add Flutter-side implementation

### Code Style
- 2 spaces for indentation
- LF line endings
- Run `flutter analyze` before committing
- Follow existing patterns in the codebase

### Important Notes
- Multi-camera support is in beta
- Minimum Android SDK: 21
- iOS requires camera, microphone, and location permissions in Info.plist
- The project uses reactive streams (RxDart) for state management
- All platform operations must respect the state machine transitions