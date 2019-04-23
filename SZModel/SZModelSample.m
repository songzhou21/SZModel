#import "SZModelSample.h"

@interface SZModelSample ()
@end

@implementation SZModelSample

+ (NSDictionary<NSString *, Class > *)propertyClassDictionary {
    return @{
             @"nestedArray": SZNestedObject.class
             };
}

@end

@implementation SZModelSampleChild

@end
