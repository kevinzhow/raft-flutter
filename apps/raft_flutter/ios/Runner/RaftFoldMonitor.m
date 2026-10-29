#import "RaftFoldMonitor.h"

@implementation RaftFoldMonitor {
  __weak UIView *_view;
  id<UIInteraction> _interaction;
}

- (instancetype)initWithView:(UIView *)view onHinge:(void (^)(NSString *))onHinge {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
  if (@available(iOS 27.1, *)) {
    self = [super init];
    if (self) {
      _view = view;
      _interaction = [[UIHingeInteraction alloc] initWithUpdateHandler:^(UIHingeInteraction *interaction, UIHingeInteractionUpdate *update) {
        NSString *status = @"none";
        if (update.hinge) {
          switch (update.hinge.status) {
            case UIHingeStatusClosed: status = @"closed"; break;
            case UIHingeStatusPartiallyOpen: status = @"partiallyOpen"; break;
            case UIHingeStatusFullyOpen: status = @"fullyOpen"; break;
            default: status = @"unknown"; break;
          }
        }
        onHinge(status);
      }];
      [view addInteraction:_interaction];
    }
    return self;
  }
#endif
  return nil;
}

- (NSArray<NSDictionary *> *)readRegions {
  NSMutableArray *result = [NSMutableArray array];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
  if (@available(iOS 27.1, *)) {
    NSArray *kinds = @[[UIViewReservedRegionKind divisionRegionKind], [UIViewReservedRegionKind occlusionRegionKind]];
    NSArray *names = @[@"division", @"occlusion"];
    for (NSUInteger i = 0; i < kinds.count; i++) {
      for (UIViewReservedRegion *region in [_view reservedRegionsOfKind:kinds[i] options:UIViewReservedRegionQueryOptionsIncludeInactive]) {
        CGRect frame = region.frame;
        [result addObject:@{@"kind": names[i], @"active": @(region.isActive),
                           @"x": @(frame.origin.x), @"y": @(frame.origin.y),
                           @"w": @(frame.size.width), @"h": @(frame.size.height)}];
      }
    }
  }
#endif
  return result;
}

- (void)invalidate {
  if (_interaction) [_view removeInteraction:_interaction];
  _interaction = nil;
  _view = nil;
}
@end
