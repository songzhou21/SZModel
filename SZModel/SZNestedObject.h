//
//  SZNestedObject.h
//  SZModel
//
//  Created by songzhou on 2018/6/30.
//  Copyright © 2018年 songzhou. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SZNestedObject2;

@interface SZNestedObject : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic) SZNestedObject2 *nestedObject;

@end

@interface SZNestedObject2 : NSObject

@property (nonatomic, copy) NSString *name;

@end
