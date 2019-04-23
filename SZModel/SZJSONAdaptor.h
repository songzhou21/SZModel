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

/**
 convert model to Foundation Object

 @param model to model needs to be converted
 @return Foudnation Object, depend on the Class of model, return value may not be [NSDictionary class]
 
 @note not handle NSDictionary contains custom object case
 */
- (NSDictionary *)dictionaryFromModel:(NSObject *)model;

@end

NS_ASSUME_NONNULL_END
