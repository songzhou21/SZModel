//
//  SZModelContainer.h
//  SZModel
//
//  Created by songzhou on 2019/4/23.
//  Copyright © 2019 songzhou. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SZCodable <NSObject>

@required
+ (NSDictionary<NSString *, Class > *)propertyClassDictionary;

@end


NS_ASSUME_NONNULL_END
