#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GodotARKitSession : NSObject

- (BOOL)isSupported;
- (BOOL)isRunning;
- (BOOL)start;
- (BOOL)stop;
- (NSDictionary *)capabilities;

@end

NS_ASSUME_NONNULL_END
