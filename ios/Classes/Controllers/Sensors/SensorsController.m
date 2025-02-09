//
//  SensorsController.m
//  camerawesome
//
//  Created by Dimitri Dessus on 28/03/2023.
//

#import "SensorsController.h"
#import "Pigeon.h"

@implementation SensorsController

+ (NSArray<NSNumber *> *)getVirtualDeviceSwitchZoomFactor:(NSString*) deviceType {
	AVCaptureDevice *capDev = [
		AVCaptureDevice defaultDeviceWithDeviceType:deviceType
		mediaType:AVMediaTypeVideo
		position:AVCaptureDevicePositionBack
	];
	if (capDev != nil) {
		return capDev.virtualDeviceSwitchOverVideoZoomFactors;
	} else {
		return nil;
	}
}

+ (CGFloat)getMinZoom:(AVCaptureDevice *)device {
	{
		NSArray<NSNumber *>* factors = [self getVirtualDeviceSwitchZoomFactor:AVCaptureDeviceTypeBuiltInTripleCamera];
		if (factors && factors.count == 2) {
			if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInUltraWideCamera]) {
				return device.minAvailableVideoZoomFactor / 2;
			} else if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera]) {
				return [factors[0] floatValue] / 2;
			} else if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInTelephotoCamera]) {
				return [factors[1] floatValue] / 2;
			}
		}
	}
	{
		NSArray<NSNumber *>* factors=  [self getVirtualDeviceSwitchZoomFactor:AVCaptureDeviceTypeBuiltInDualCamera];
		if (factors && factors.count == 1) {
			if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera]) {
				return device.minAvailableVideoZoomFactor;
			} else if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInTelephotoCamera]) {
				return [factors[0] floatValue] / 2;
			}
		}
	}
	{
		NSArray<NSNumber *>* factors = [self getVirtualDeviceSwitchZoomFactor:AVCaptureDeviceTypeBuiltInDualWideCamera];
		if (factors != nil && factors.count == 1) {
			if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInUltraWideCamera]) {
				return device.minAvailableVideoZoomFactor / 2;
			} else if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera]) {
				return [factors[0] floatValue] / 2;
			}
		}
	}
	
	return device.minAvailableVideoZoomFactor;
}

+ (CGFloat)_getMaxDigitalZoom:(AVCaptureDevice *)device {
	CGFloat maxZoom = device.maxAvailableVideoZoomFactor;
	// Not sure why on iPhone 14 Pro, zoom at 90 not working, so let's block to 50 which is very high
	return maxZoom > 50.0 ? 50.0 : maxZoom;
}

+ (CGFloat)_getMaxOpticalZoom:(AVCaptureDevice *) device {
	return device.activeFormat.videoZoomFactorUpscaleThreshold;
}

+ (CGFloat)_getMaxZoom:(AVCaptureDevice *) device {
	{
		NSArray<NSNumber *>* factors=  [self getVirtualDeviceSwitchZoomFactor:AVCaptureDeviceTypeBuiltInTripleCamera];
		
		if (factors && factors.count == 2) {
			if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInUltraWideCamera]) {
				return[factors[0] floatValue] / 2;
			} else if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera]) {
				return [factors[1] floatValue] / 2;
			} else if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInTelephotoCamera]) {
				return  [self _getMaxOpticalZoom:device] + [self getMinZoom:device];
			}
		}
	}
	{
		NSArray<NSNumber *>* factors = [self getVirtualDeviceSwitchZoomFactor:AVCaptureDeviceTypeBuiltInDualCamera];
		
		if (factors && factors.count == 1) {
			if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera]) {
				return [factors[0] doubleValue] / 2;
			} else if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInTelephotoCamera]) {
				return [self _getMaxOpticalZoom:device] + [self getMinZoom:device];
			}
		}
	}
	{
		NSArray<NSNumber *>* factors = [self getVirtualDeviceSwitchZoomFactor:AVCaptureDeviceTypeBuiltInDualWideCamera];
		if (factors != nil && factors.count == 1) {
			if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInUltraWideCamera]) {
				return [factors[0] doubleValue] / 2;
			} else if ([device.deviceType isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera]) {
				return  [self _getMaxOpticalZoom:device] + [self getMinZoom:device];
			}
		}
	}
	
	return [self _getMaxOpticalZoom:device];
}


+ (PigeonSensorTypeDevice *)getPigeonSensorTypeDeviceFromAVCaptureDevice:(AVCaptureDevice *)device {
	PigeonSensorType type;
	if (device.deviceType == AVCaptureDeviceTypeBuiltInTelephotoCamera) {
		type = PigeonSensorTypeTelephoto;
	} else if (device.deviceType == AVCaptureDeviceTypeBuiltInUltraWideCamera) {
		type = PigeonSensorTypeUltraWideAngle;
	} else if (device.deviceType == AVCaptureDeviceTypeBuiltInTrueDepthCamera) {
		type = PigeonSensorTypeTrueDepth;
	} else if (device.deviceType == AVCaptureDeviceTypeBuiltInWideAngleCamera) {
		type = PigeonSensorTypeWideAngle;
	} else {
		type = PigeonSensorTypeUnknown;
	}
	
	CGFloat minZoom = [self getMinZoom:device];
	CGFloat maxOpticalZoom = [self _getMaxZoom:device];
	CGFloat maxDigitalZoom = [self _getMaxDigitalZoom:device];
	PigeonSensorTypeDevice *sensorType = [
		PigeonSensorTypeDevice
			makeWithSensorType:type
			name:device.localizedName
			iso:[NSNumber numberWithFloat:device.ISO]
			flashAvailable:[NSNumber numberWithBool:device.flashAvailable]
			uid:device.uniqueID
			minZoom:minZoom
			maxOpticalZoom:maxOpticalZoom
			maxDigitalZoom:maxDigitalZoom
	];
	return sensorType;
}

+ (NSArray *)getSensors:(AVCaptureDevicePosition)position {
  NSMutableArray *sensors = [NSMutableArray new];
  
  NSArray *sensorsType = @[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInTelephotoCamera, AVCaptureDeviceTypeBuiltInUltraWideCamera, AVCaptureDeviceTypeBuiltInTrueDepthCamera];
  
  AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession
                                                       discoverySessionWithDeviceTypes:sensorsType
                                                       mediaType:AVMediaTypeVideo
                                                       position:AVCaptureDevicePositionUnspecified];
  
  for (AVCaptureDevice *device in discoverySession.devices) {
		PigeonSensorTypeDevice *sensorType = [self getPigeonSensorTypeDeviceFromAVCaptureDevice:device];
    
    if (device.position == position) {
      [sensors addObject:sensorType];
    }
  }
  
  return sensors;
}

@end
