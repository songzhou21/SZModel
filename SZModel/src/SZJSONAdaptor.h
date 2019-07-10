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

/**
 default is NO,
 otherwise, when converting the model to Dictionary,
 ignore properties which have ni value
 */
@property (nonatomic) BOOL ignoreNilValue;

/**
 convert NSDcitonary to model object
 
 @param klass the Class of model object
 @param dictioary the dictionary needs to be converted
 @return model object
 */
- (id)modelFromClass:(Class)klass dictionary:(NSDictionary *)dictioary;

/**
 convert model to Foundation Object
 
 @param model model needs to be converted
 @return Foudnation Object
 
 @note not handle NSDictionary contains custom object case
 */
- (id)foundationObjFromModel:(NSObject *)model;

/**
 convert model to Foundation Object
 bypass property with nil value
 
 @param model model needs to be converted
 @return Foudnation Object
 
 @note not handle NSDictionary contains custom object case
 */
- (id)foundationObjNoNullFromModel:(NSObject *)model;

@end

NS_ASSUME_NONNULL_END
