#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface GodotARKitSession : NSObject

- (BOOL)isSupported;
- (BOOL)isRunning;
- (BOOL)start;
- (BOOL)stop;
- (NSInteger)trackingStatus;
- (NSString *)trackingStateName;
- (NSString *)trackingStateReason;
- (NSDictionary *)capabilities;
- (NSArray<NSDictionary *> *)hitTestFromOrigin:(simd_float3)origin direction:(simd_float3)direction maxDistance:(double)maxDistance;
- (NSArray<NSDictionary *> *)planes;

@end

NS_ASSUME_NONNULL_END
