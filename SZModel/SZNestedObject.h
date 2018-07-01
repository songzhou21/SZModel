//
//  SZNestedObject.h
//  SZModel
//
//  Created by songzhou on 2018/6/30.
//  Copyright © 2018年 songzhou. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SZModel.h"

@class SZNestedObject2;

@interface SZNestedObject : SZModel

@property (nonatomic, copy) NSString *name;
@property (nonatomic) SZNestedObject2 *nestedObject;

@end

@interface SZNestedObject2 : SZModel

@property (nonatomic, copy) NSString *name;

@end
