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

void SZEnumerateClassProperty(Class klass, void(^block)(NSString *property_name, NSString *type_attribute)){
    if (!block) {
        return;
    }
    
    unsigned int count;
    objc_property_t *props = class_copyPropertyList(klass, &count);
    for (int i = 0; i < count; i++) {
        objc_property_t property = props[i];
        const char *name = property_getName(property);
        NSString *propertyName = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
        const char *type = property_getAttributes(property);
        
        NSString *typeString = [NSString stringWithUTF8String:type];
        NSArray<NSString *> *attributes = [typeString componentsSeparatedByString:@","];
        NSString *typeAttribute = attributes[0];
        
        block(propertyName, typeAttribute);
    }
}

@interface SZJSONAdaptor ()

@property (nonatomic, copy) NSSet *jsonFoundationClasses;

@end

@implementation SZJSONAdaptor

- (instancetype)init
{
    self = [super init];
    if (self) {
        _jsonFoundationClasses =
        [NSSet setWithArray:@[
                              NSString.class,
                              NSNumber.class,
                              NSArray.class,
                              NSDictionary.class,
                              NSNull.class
                              ]];
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

- (NSDictionary<NSString *, NSString *> *)_propertyClassMapForClass:(Class)klass{
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    SZEnumerateClassProperty(klass, ^(NSString * _Nonnull property_name, NSString * _Nonnull typeAttribute) {
        if ([typeAttribute hasPrefix:@"T@"]) {
            NSString *typeClassName = [typeAttribute substringWithRange:NSMakeRange(3, [typeAttribute length] - 4)];
            ret[property_name] = typeClassName;
        }
    });

    return ret;
}

- (NSDictionary *)_dictionaryFromModel:(id)model {
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    SZEnumerateClassProperty([model class], ^(NSString * _Nonnull property_name, NSString * _Nonnull type_attribute) {
        
        id obj = [model valueForKey:property_name];
        
        /// handle object
        if (![self _canConvertToJSON:obj]) {
            id retObj = [self _dictionaryFromModel:obj];
            obj = retObj;
        }
        
        /// handle array
        if ([obj isKindOfClass:[NSArray class]]) {
            NSMutableArray *array = [NSMutableArray array];
            for (id o in (NSArray *)obj) {
                if ([self _canConvertToJSON:o]) {
                    [array addObject:o];
                } else {
                    NSDictionary *dict = [self _dictionaryFromModel:o];
                    [array addObject:dict];
                }
            }
            
            obj = array;
        }
        
        [ret setObject:obj forKey:property_name];
//        NSLog(@"property_name:%@, type:%@, obj:%@", property_name, type_attribute, obj);
    });
    
    return ret;
}

// All objects are NSString, NSNumber, NSArray, NSDictionary, or NSNull
- (NSString *)_dictionary2JSON:(NSDictionary *)dictioary {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictioary options:NSJSONWritingPrettyPrinted error:&error];
    if (!jsonData || error) {
        return @"{}";
    } else {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
}

- (BOOL)_canConvertToJSON:(id)obj {
    Class klass = [obj class];
    
    if ([self.jsonFoundationClasses containsObject:klass]) {
        return YES;
    }
    
    for (Class jsonKlass in self.jsonFoundationClasses) {
        if ([klass isSubclassOfClass:jsonKlass]) {
            return YES;
        }
    }
    
    return NO;
    
}

#pragma mark - API

- (id)modelFromClass:(Class)klass dictionary:(NSDictionary *)dictioary {
    return [self _modelFromClass:klass dictionary:dictioary];
}

- (NSDictionary *)dictionaryFromModel:(id)model {
    return [self _dictionaryFromModel:model];
}

@end

NS_ASSUME_NONNULL_END
