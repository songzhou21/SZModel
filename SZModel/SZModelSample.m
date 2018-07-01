#import "SZModelSample.h"

@interface SZModelSample ()
@end

@implementation SZModelSample

- (NSDictionary *)propertyClassMap {
    return @{
             @"nestedArray": @"SZNestedObject"
             };
}

@end
