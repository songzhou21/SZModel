//
//  SZJSONAdaptor.h
//  SZModel
//
//  Created by songzhou on 2018/6/30.
//  Copyright © 2018年 songzhou. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SZJSONAdaptor : NSObject

- (id)modelFromClass:(Class)klass dictionary:(NSDictionary *)dictioary;

@end

NS_ASSUME_NONNULL_END
