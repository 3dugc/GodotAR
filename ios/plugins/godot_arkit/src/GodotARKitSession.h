#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface GodotARKitSession : NSObject

- (BOOL)isSupported;
- (BOOL)isRunning;
- (BOOL)isCameraBackgroundRendering;
- (BOOL)start;
- (BOOL)stop;
- (NSInteger)trackingStatus;
- (NSString *)trackingStateName;
- (NSString *)trackingStateReason;
- (NSDictionary *)capabilities;
- (NSDictionary *)cameraIntrinsics;
- (NSDictionary *)cameraFrame;
- (NSDictionary *)cameraBackgroundState;
- (NSDictionary *)lightEstimate;
- (NSArray<NSDictionary *> *)hitTestFromOrigin:(simd_float3)origin direction:(simd_float3)direction maxDistance:(double)maxDistance;
- (NSDictionary *)addAnchorWithTransform:(NSArray *)transformMatrix;
- (NSArray<NSDictionary *> *)planes;

@end

NS_ASSUME_NONNULL_END
