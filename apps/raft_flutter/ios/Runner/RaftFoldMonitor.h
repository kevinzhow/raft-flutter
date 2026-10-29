#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface RaftFoldMonitor : NSObject
- (nullable instancetype)initWithView:(UIView *)view onHinge:(void (^)(NSString *status))onHinge;
- (NSArray<NSDictionary *> *)readRegions;
- (void)invalidate;
@end
NS_ASSUME_NONNULL_END
