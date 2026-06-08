#import <Foundation/Foundation.h>

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

@end

NS_ASSUME_NONNULL_END
