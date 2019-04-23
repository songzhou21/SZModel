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
/// primitive types, can be converted to JSON directly, ignore NSDictionary contains custom object
@property (nonatomic, copy) NSSet<Class> *primitiveTypes;

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
        
        _primitiveTypes =
        [NSSet setWithArray:@[
                              NSNull.class,
                              NSNumber.class,
                              NSString.class,
                              NSDictionary.class,
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

- (NSObject *)_foundationObjFromModel:(NSObject *)model {
    if ([self _isPrimitiveType:model]) {
        return model;
    } else if ([model isKindOfClass:[NSArray class]]) {
        NSArray *objArray = (NSArray *)model;
        NSMutableArray *retArray = [NSMutableArray arrayWithCapacity:objArray.count];
        
        for (int i = 0; i < objArray.count; i++) {
            retArray[i] = [self _foundationObjFromModel:objArray[i]];
        }
        
        return retArray;
    } else {
        NSMutableDictionary *ret = [NSMutableDictionary dictionary];
        SZEnumerateClassProperty([model class], ^(NSString * _Nonnull property_name, NSString * _Nonnull type_attribute) {
            id obj = [model valueForKey:property_name];
            [ret setObject:[[self _foundationObjFromModel:obj] copy] forKey:property_name];
        });
        
        return ret;
    }
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

- (BOOL)_isFoundationType:(id)obj {
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

- (BOOL)_isPrimitiveType:(id)obj {
    Class klass = [obj class];
    
    if ([self.primitiveTypes containsObject:klass]) {
        return YES;
    }
    
    for (Class primitiveClass in self.primitiveTypes) {
        if ([klass isSubclassOfClass:primitiveClass]) {
            return YES;
        }
    }
    
    return NO;
    
}

#pragma mark - API

- (id)modelFromClass:(Class)klass dictionary:(NSDictionary *)dictioary {
    return [self _modelFromClass:klass dictionary:dictioary];
}

- (NSDictionary *)dictionaryFromModel:(NSObject *)model {
    return (NSDictionary *)[self _foundationObjFromModel:model];
}

@end

NS_ASSUME_NONNULL_END
