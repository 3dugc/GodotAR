#import "GodotARKitSession.h"

#import <ARKit/ARKit.h>

@implementation GodotARKitSession {
	ARSession *_session;
	BOOL _running;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		_session = [ARSession new];
		_running = NO;
	}
	return self;
}

- (BOOL)isSupported {
	if (@available(iOS 11.0, *)) {
		return ARWorldTrackingConfiguration.isSupported;
	}
	return NO;
}

- (BOOL)start {
	if (![self isSupported]) {
		return NO;
	}

	ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];
	if (@available(iOS 11.3, *)) {
		configuration.planeDetection = ARPlaneDetectionHorizontal | ARPlaneDetectionVertical;
	}
	[_session runWithConfiguration:configuration];
	_running = YES;
	return YES;
}

- (BOOL)stop {
	[_session pause];
	_running = NO;
	return YES;
}

- (NSDictionary *)capabilities {
	BOOL supported = [self isSupported];
	return @{
		@"session": @(supported),
		@"tracking": @(supported),
		@"camera_background": @(supported),
		@"passthrough": @(supported),
		@"raycast": @(supported),
		@"plane_detection": @(supported),
		@"anchors": @(supported),
		@"native_plugin": @YES,
		@"ar_product_path": @(supported),
		@"arkit_supported": @(supported),
		@"arkit_running": @(_running),
	};
}

@end
