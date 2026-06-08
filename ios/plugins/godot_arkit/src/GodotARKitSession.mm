#import "GodotARKitSession.h"

#import <ARKit/ARKit.h>

@interface GodotARKitSession () <ARSessionDelegate>
@end

@implementation GodotARKitSession {
	ARSession *_session;
	BOOL _running;
	NSInteger _trackingStatus;
	NSString *_trackingStateName;
	NSString *_trackingStateReason;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		_session = [ARSession new];
		_session.delegate = self;
		_running = NO;
		_trackingStatus = 0;
		_trackingStateName = @"not_available";
		_trackingStateReason = @"not_running";
	}
	return self;
}

- (BOOL)isSupported {
	if (@available(iOS 11.0, *)) {
		return ARWorldTrackingConfiguration.isSupported;
	}
	return NO;
}

- (BOOL)isRunning {
	return _running;
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
	[self updateTrackingFromFrame:_session.currentFrame];
	return YES;
}

- (BOOL)stop {
	[_session pause];
	_running = NO;
	_trackingStatus = 0;
	_trackingStateName = @"not_available";
	_trackingStateReason = @"stopped";
	return YES;
}

- (NSInteger)trackingStatus {
	return _trackingStatus;
}

- (NSString *)trackingStateName {
	return _trackingStateName ?: @"unknown";
}

- (NSString *)trackingStateReason {
	return _trackingStateReason ?: @"unknown";
}

- (NSDictionary *)capabilities {
	BOOL supported = [self isSupported];
	return @{
		@"session": @(supported),
		@"tracking": @(_trackingStatus == 2),
		@"camera_background": @(supported),
		@"passthrough": @(supported),
		@"raycast": @(supported),
		@"plane_detection": @(supported),
		@"anchors": @(supported),
		@"native_plugin": @YES,
		@"ar_product_path": @(supported),
		@"arkit_supported": @(supported),
		@"arkit_running": @(_running),
		@"arkit_tracking_status": @(_trackingStatus),
		@"arkit_tracking_state": [self trackingStateName],
		@"arkit_tracking_reason": [self trackingStateReason],
	};
}

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
	(void)session;
	[self updateTrackingFromFrame:frame];
}

- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
	(void)session;
	[self updateTrackingFromCamera:camera];
}

- (void)updateTrackingFromFrame:(ARFrame *)frame {
	if (frame == nil) {
		return;
	}
	[self updateTrackingFromCamera:frame.camera];
}

- (void)updateTrackingFromCamera:(ARCamera *)camera {
	if (camera == nil) {
		_trackingStatus = _running ? 1 : 0;
		_trackingStateName = _running ? @"limited" : @"not_available";
		_trackingStateReason = _running ? @"waiting_for_frame" : @"not_running";
		return;
	}

	switch (camera.trackingState) {
		case ARTrackingStateNormal:
			_trackingStatus = 2;
			_trackingStateName = @"normal";
			_trackingStateReason = @"none";
			break;
		case ARTrackingStateLimited:
			_trackingStatus = 1;
			_trackingStateName = @"limited";
			_trackingStateReason = [self reasonNameForLimitedTracking:camera.trackingStateReason];
			break;
		case ARTrackingStateNotAvailable:
		default:
			_trackingStatus = 0;
			_trackingStateName = @"not_available";
			_trackingStateReason = @"not_available";
			break;
	}
}

- (NSString *)reasonNameForLimitedTracking:(ARTrackingStateReason)reason {
	switch (reason) {
		case ARTrackingStateReasonInitializing:
			return @"initializing";
		case ARTrackingStateReasonRelocalizing:
			return @"relocalizing";
		case ARTrackingStateReasonExcessiveMotion:
			return @"excessive_motion";
		case ARTrackingStateReasonInsufficientFeatures:
			return @"insufficient_features";
		default:
			return @"unknown";
	}
}

@end
