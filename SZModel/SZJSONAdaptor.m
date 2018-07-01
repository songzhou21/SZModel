//
//  SZJSONAdaptor.m
//  SZModel
//
//  Created by songzhou on 2018/6/30.
//  Copyright © 2018年 songzhou. All rights reserved.
//

#import "SZJSONAdaptor.h"
#import "SZModelSample.h"
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface SZJSONAdaptor ()


@end

@implementation SZJSONAdaptor

- (instancetype)init
{
    self = [super init];
    if (self) {

    }
    
    return self;
}

- (id)_modelFromClass:(Class)klass dictionary:(NSDictionary *)dictionary {
    if (![klass isSubclassOfClass:[SZModel class]]) {
        return [NSNull null];
    }
    
    SZModel *ret = [klass new];
    NSDictionary<NSString *, NSString *> * propertyClassMap = [self _propertyClassMapForClass:[ret class]];
    
    for (NSString *key in dictionary.allKeys) {
        id value = dictionary[key];
        
        // nested object
        if ([value isKindOfClass:[NSDictionary class]]) {
            NSString *mapClassString = propertyClassMap[key];
            if (mapClassString) {
                Class mapClass = NSClassFromString(mapClassString);
                id mapObjectValue = [self modelFromClass:mapClass dictionary:value];
                [ret setValue:mapObjectValue forKey:key];
                
                continue;
            }
        } else if ([value isKindOfClass:[NSArray class]]) {
            NSDictionary *propertyClassMap = [ret propertyClassMap];
            NSString *mapClassString = propertyClassMap[key];
            
            NSArray *retArray = [self _modelFromArray:value class:NSClassFromString(mapClassString)];
            
            [ret setValue:retArray forKey:key];
            continue;
        }
        
        
        [ret setValue:value forKey:key];
    }
    
    return ret;
}

/*
  custom object in array is klass class, klass is subclass of SZModel,
 not support nested array object mapping
 */
- (NSArray *)_modelFromArray:(NSArray *)array class:(_Nullable Class)klass {
    if (![klass isSubclassOfClass:[SZModel class]]) {
        return array;
    }
    
    NSMutableArray *retArray = [NSMutableArray arrayWithCapacity:array.count];
    for (id obj in array) {
        id retObj;
        if ([obj isKindOfClass:[NSDictionary class]]) {
            retObj = [self modelFromClass:klass dictionary:obj];
        } else if ([obj isKindOfClass:[NSArray class]]) {
            retObj = [self _modelFromArray:obj class:nil];
        } else {
            retObj = obj;
        }
        
        [retArray addObject:retObj];
    }

    return [retArray copy];
}

- (NSDictionary<NSString *, NSString *> *)_propertyClassMapForClass:(Class)kclass{
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    unsigned int count;
    objc_property_t *props = class_copyPropertyList(kclass, &count);
    for (int i = 0; i < count; i++) {
        objc_property_t property = props[i];
        const char *name = property_getName(property);
        NSString *propertyName = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
        const char *type = property_getAttributes(property);
        
        NSString *typeString = [NSString stringWithUTF8String:type];
        NSArray<NSString *> *attributes = [typeString componentsSeparatedByString:@","];
        NSString *typeAttribute = attributes[0];
        
        if ([typeAttribute hasPrefix:@"T@"]) {
            NSString *typeClassName = [typeAttribute substringWithRange:NSMakeRange(3, [typeAttribute length] - 4)];
            ret[propertyName] = typeClassName;
        }
    }
    
    return ret;
}

#pragma mark - API
- (id)modelFromClass:(Class)klass dictionary:(NSDictionary *)dictioary {
    return [self _modelFromClass:klass dictionary:dictioary];
}

@end

NS_ASSUME_NONNULL_END
