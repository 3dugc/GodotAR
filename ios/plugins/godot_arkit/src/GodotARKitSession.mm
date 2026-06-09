#import "GodotARKitSession.h"

#import <ARKit/ARKit.h>

@interface GodotARKitSession () <ARSessionDelegate>
@end

@implementation GodotARKitSession {
	ARSession *_session;
	NSMutableDictionary<NSUUID *, ARPlaneAnchor *> *_planeAnchors;
	BOOL _running;
	NSInteger _trackingStatus;
	NSString *_trackingStateName;
	NSString *_trackingStateReason;
}

static NSArray *matrixArrayFromTransform(simd_float4x4 transform) {
	return @[
		@(transform.columns[0].x), @(transform.columns[0].y), @(transform.columns[0].z), @(transform.columns[0].w),
		@(transform.columns[1].x), @(transform.columns[1].y), @(transform.columns[1].z), @(transform.columns[1].w),
		@(transform.columns[2].x), @(transform.columns[2].y), @(transform.columns[2].z), @(transform.columns[2].w),
		@(transform.columns[3].x), @(transform.columns[3].y), @(transform.columns[3].z), @(transform.columns[3].w),
	];
}

static simd_float4x4 matrixFromArray(NSArray *values) {
	if (values == nil || values.count < 16) {
		return matrix_identity_float4x4;
	}
	simd_float4x4 transform = matrix_identity_float4x4;
	transform.columns[0] = simd_make_float4([values[0] floatValue], [values[1] floatValue], [values[2] floatValue], [values[3] floatValue]);
	transform.columns[1] = simd_make_float4([values[4] floatValue], [values[5] floatValue], [values[6] floatValue], [values[7] floatValue]);
	transform.columns[2] = simd_make_float4([values[8] floatValue], [values[9] floatValue], [values[10] floatValue], [values[11] floatValue]);
	transform.columns[3] = simd_make_float4([values[12] floatValue], [values[13] floatValue], [values[14] floatValue], [values[15] floatValue]);
	return transform;
}

static NSArray *matrixArrayFromIntrinsics(matrix_float3x3 intrinsics) {
	return @[
		@(intrinsics.columns[0].x), @(intrinsics.columns[0].y), @(intrinsics.columns[0].z),
		@(intrinsics.columns[1].x), @(intrinsics.columns[1].y), @(intrinsics.columns[1].z),
		@(intrinsics.columns[2].x), @(intrinsics.columns[2].y), @(intrinsics.columns[2].z),
	];
}

static NSDictionary *intrinsicsDictionaryFromCamera(ARCamera *camera) {
	if (camera == nil) {
		return @{
			@"success": @NO,
			@"reason": @"camera_unavailable",
			@"source": @"arkit_camera_intrinsics",
		};
	}

	matrix_float3x3 intrinsics = camera.intrinsics;
	CGSize resolution = camera.imageResolution;
	return @{
		@"success": @YES,
		@"focal_length": @[@(intrinsics.columns[0].x), @(intrinsics.columns[1].y)],
		@"principal_point": @[@(intrinsics.columns[2].x), @(intrinsics.columns[2].y)],
		@"resolution": @[@((NSInteger)resolution.width), @((NSInteger)resolution.height)],
		@"matrix": matrixArrayFromIntrinsics(intrinsics),
		@"source": @"arkit_camera_intrinsics",
	};
}

- (instancetype)init {
	self = [super init];
	if (self) {
		_session = [ARSession new];
		_session.delegate = self;
		_planeAnchors = [NSMutableDictionary new];
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
	configuration.lightEstimationEnabled = YES;
	[_session runWithConfiguration:configuration];
	_running = YES;
	[self updateTrackingFromFrame:_session.currentFrame];
	return YES;
}

- (BOOL)stop {
	[_session pause];
	[_planeAnchors removeAllObjects];
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
	ARFrame *frame = _session.currentFrame;
	return @{
		@"session": @(supported),
		@"tracking": @(_trackingStatus == 2),
		@"camera_background": @(supported),
		@"passthrough": @(supported),
		@"raycast": @(supported),
		@"plane_detection": @(supported),
		@"anchors": @(supported),
		@"light_estimation": @(supported),
		@"native_plugin": @YES,
		@"ar_product_path": @(supported),
		@"arkit_supported": @(supported),
		@"arkit_running": @(_running),
		@"arkit_tracking_status": @(_trackingStatus),
		@"arkit_tracking_state": [self trackingStateName],
		@"arkit_tracking_reason": [self trackingStateReason],
		@"arkit_camera_frame_available": @(frame != nil),
		@"arkit_camera_intrinsics": @(frame != nil && frame.camera != nil),
	};
}

- (NSDictionary *)cameraIntrinsics {
	ARFrame *frame = _session.currentFrame;
	if (!_running || frame == nil) {
		return @{
			@"success": @NO,
			@"reason": _running ? @"waiting_for_frame" : @"not_running",
			@"source": @"arkit_camera_intrinsics",
		};
	}
	return intrinsicsDictionaryFromCamera(frame.camera);
}

- (NSDictionary *)lightEstimate {
	ARFrame *frame = _session.currentFrame;
	if (!_running || frame == nil || frame.lightEstimate == nil) {
		return @{
			@"available": @NO,
			@"reason": _running ? @"waiting_for_light_estimate" : @"not_running",
			@"source": @"arkit_light_estimate",
		};
	}

	ARLightEstimate *estimate = frame.lightEstimate;
	return @{
		@"available": @YES,
		@"ambient_intensity": @(estimate.ambientIntensity),
		@"ambient_color_temperature": @(estimate.ambientColorTemperature),
		@"source": @"arkit_light_estimate",
	};
}

- (NSDictionary *)cameraFrame {
	ARFrame *frame = _session.currentFrame;
	if (!_running || frame == nil) {
		return @{
			@"available": @NO,
			@"reason": _running ? @"waiting_for_frame" : @"not_running",
			@"runtime": @"ARKit",
		};
	}

	NSDictionary *intrinsics = [self cameraIntrinsics];
	NSDictionary *lightEstimate = [self lightEstimate];
	return @{
		@"available": @YES,
		@"runtime": @"ARKit",
		@"timestamp": @(frame.timestamp),
		@"timestamp_msec": @(frame.timestamp * 1000.0),
		@"tracking_state": [self trackingStateName],
		@"tracking_reason": [self trackingStateReason],
		@"has_intrinsics": @([intrinsics[@"success"] boolValue]),
		@"intrinsics": intrinsics,
		@"has_light_estimate": @([lightEstimate[@"available"] boolValue]),
		@"light_estimation": lightEstimate,
	};
}

- (NSArray<NSDictionary *> *)hitTestFromOrigin:(simd_float3)origin direction:(simd_float3)direction maxDistance:(double)maxDistance {
	if (!_running || _session.currentFrame == nil) {
		return @[];
	}

	float length = simd_length(direction);
	if (length <= 0.0001f) {
		return @[];
	}

	if (@available(iOS 13.0, *)) {
		simd_float3 normalizedDirection = direction / length;
		ARRaycastQuery *query = [[ARRaycastQuery alloc]
			initWithOrigin:origin
			direction:normalizedDirection
			allowingTarget:ARRaycastTargetEstimatedPlane
			alignment:ARRaycastTargetAlignmentAny];
		NSArray<ARRaycastResult *> *results = [_session raycast:query];
		NSMutableArray<NSDictionary *> *hits = [NSMutableArray arrayWithCapacity:results.count];
		for (ARRaycastResult *result in results) {
			simd_float4x4 transform = result.worldTransform;
			simd_float3 position = simd_make_float3(transform.columns[3].x, transform.columns[3].y, transform.columns[3].z);
			double distance = simd_distance(origin, position);
			if (maxDistance > 0.0 && distance > maxDistance) {
				continue;
			}
			NSString *anchorId = result.anchor != nil ? result.anchor.identifier.UUIDString : @"";
			[hits addObject:@{
				@"trackable_id": anchorId,
				@"distance": @(distance),
				@"transform": matrixArrayFromTransform(transform),
				@"position": @[@(position.x), @(position.y), @(position.z)],
				@"normal": @[@(0.0), @(1.0), @(0.0)],
				@"target": @"estimated_plane",
			}];
		}
		return hits;
	}

	return @[];
}

- (NSDictionary *)addAnchorWithTransform:(NSArray *)transformMatrix {
	if (!_running) {
		return @{
			@"success": @NO,
			@"reason": @"not_running",
			@"runtime": @"ARKit",
		};
	}

	simd_float4x4 transform = matrixFromArray(transformMatrix);
	ARAnchor *anchor = [[ARAnchor alloc] initWithTransform:transform];
	[_session addAnchor:anchor];
	return @{
		@"success": @YES,
		@"trackable_id": anchor.identifier.UUIDString,
		@"persistent_id": anchor.identifier.UUIDString,
		@"transform": matrixArrayFromTransform(anchor.transform),
		@"runtime": @"ARKit",
		@"raw_anchor": @"ARKitAnchor",
	};
}

- (NSArray<NSDictionary *> *)planes {
	NSMutableArray<NSDictionary *> *planes = [NSMutableArray arrayWithCapacity:_planeAnchors.count];
	for (ARPlaneAnchor *anchor in _planeAnchors.objectEnumerator) {
		vector_float3 center = anchor.center;
		vector_float3 extent = anchor.extent;
		vector_float4 worldCenter = simd_mul(anchor.transform, simd_make_float4(center.x, center.y, center.z, 1.0f));
		simd_float4x4 planeTransform = anchor.transform;
		planeTransform.columns[3] = simd_make_float4(worldCenter.x, worldCenter.y, worldCenter.z, 1.0f);
		NSString *alignment = @"unknown";
		switch (anchor.alignment) {
			case ARPlaneAnchorAlignmentHorizontal:
				alignment = @"horizontal";
				break;
			case ARPlaneAnchorAlignmentVertical:
				alignment = @"vertical";
				break;
			default:
				break;
		}
		[planes addObject:@{
			@"trackable_id": anchor.identifier.UUIDString,
			@"transform": matrixArrayFromTransform(planeTransform),
			@"position": @[@(worldCenter.x), @(worldCenter.y), @(worldCenter.z)],
			@"size": @[@(extent.x), @(extent.z)],
			@"alignment": alignment,
			@"label": @"",
		}];
	}
	return planes;
}

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
	(void)session;
	[self updateTrackingFromFrame:frame];
}

- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
	(void)session;
	[self updateTrackingFromCamera:camera];
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<ARAnchor *> *)anchors {
	(void)session;
	[self updatePlaneAnchors:anchors];
}

- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<ARAnchor *> *)anchors {
	(void)session;
	[self updatePlaneAnchors:anchors];
}

- (void)session:(ARSession *)session didRemoveAnchors:(NSArray<ARAnchor *> *)anchors {
	(void)session;
	for (ARAnchor *anchor in anchors) {
		[_planeAnchors removeObjectForKey:anchor.identifier];
	}
}

- (void)updatePlaneAnchors:(NSArray<ARAnchor *> *)anchors {
	for (ARAnchor *anchor in anchors) {
		if ([anchor isKindOfClass:ARPlaneAnchor.class]) {
			_planeAnchors[anchor.identifier] = (ARPlaneAnchor *)anchor;
		}
	}
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
