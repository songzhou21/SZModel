//
//  SZJSONAdaptor.m
//  SZModel
//
//  Created by songzhou on 2018/6/30.
//  Copyright © 2018年 songzhou. All rights reserved.
//

#import "SZJSONAdaptor.h"
#import <objc/runtime.h>
#import "SZCodable.h"

NS_ASSUME_NONNULL_BEGIN
static NSSet<NSString *> *SZInternalProperties(void) {
    static NSSet<NSString *> *ret;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ret = [NSSet setWithArray:@[
                                    @"description",
                                    @"debugDescription",
                                    @"hash",
                                    @"superclass",
                                    ]];
    });
    
    return ret;
}

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

void SZCleanEnumerateClassProperty(Class klass, void(^block)(NSString *property_name, NSString *type_attribute)){
    SZEnumerateClassProperty(klass, ^(NSString * _Nonnull property_name, NSString * _Nonnull type_attribute) {
        if ([SZInternalProperties() containsObject:property_name]) {
            return;
        }
        
        block(property_name, type_attribute);
    });
}

void SZEnumerateAllClassProperty(Class klass, void(^block)(NSString *property_name, NSString *type_attribute)){
    Class currentClass = klass;
    while (currentClass != [NSObject class]) {
        SZCleanEnumerateClassProperty(currentClass, block);
        
        currentClass = [currentClass superclass];
    }
}

@interface SZJSONAdaptor ()

/// primitive types, can be converted to JSON directly, treat NSDictionary as primitive type
@property (nonatomic, copy) NSSet<Class> *primitiveTypes;
/// primitive types, can be converted to JSON directly, not including NSDictioanry
@property (nonatomic, copy) NSSet<Class> *modelPrimitiveTypes;

@end

@implementation SZJSONAdaptor

/**
 create object from Foundation obj

 @param klass the Class of Dictionary, maybe nil if obj is primitieve Foundation obj
 @param obj the Foundation obj
 @return custom obj
 */
- (id)_modelFromClass:(nullable Class)klass foundationObj:(NSObject *)obj {
    if ([self _isKindOfType:obj container:self.modelPrimitiveTypes]) {
        return obj;
    } else if ([obj isKindOfClass:[NSArray class]]) {
        NSArray *objArray = (NSArray *)obj;
        NSMutableArray *retArray = [NSMutableArray arrayWithCapacity:objArray.count];
        
        for (int i = 0; i < objArray.count; i++) {
            id value = objArray[i];
            retArray[i] = [self _modelFromClass:klass foundationObj:value];
        }
        
        return retArray;
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        if (!klass) { // when not conforming `SZCodable` or `propertyClassDictionary` return nil
            return obj;
        }
        
        NSObject *model = [klass new];
        
        NSDictionary<NSString *, NSString *> * propertyClassMap = [self _propertyClassMapForClass:klass];
        NSDictionary *dictionary = (NSDictionary *)obj;
        for (NSString *propertyName in dictionary) {
            NSObject *propertyValue = dictionary[propertyName];
            Class propertyClass = NSClassFromString(propertyClassMap[propertyName]);
            
            if ([propertyValue isKindOfClass:[NSArray class]] &&
                [klass conformsToProtocol:@protocol(SZCodable)]) { // return NSArray<ObjectType>
                NSDictionary<NSString *, Class > * modelClassMap = [klass propertyClassDictionary];

                [model setValue:[self _modelFromClass:modelClassMap[propertyName] foundationObj:propertyValue] forKey:propertyName];
            } else {
                [model setValue:[self _modelFromClass:propertyClass foundationObj:propertyValue] forKey:propertyName];
            }
        }
        
        return model;
    } else {
        return [NSNull null];
    }
}

- (NSDictionary<NSString *, NSString *> *)_propertyClassMapForClass:(Class)klass{
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    SZEnumerateAllClassProperty(klass, ^(NSString * _Nonnull property_name, NSString * _Nonnull typeAttribute) {
        if ([typeAttribute hasPrefix:@"T@"]) {
            NSString *typeClassName = [typeAttribute substringWithRange:NSMakeRange(3, [typeAttribute length] - 4)];
            ret[property_name] = typeClassName;
        }
    });

    return ret;
}

- (NSObject *)_foundationObjFromModel:(NSObject *)model {
    if (model == nil) {
        return [NSNull null];
    } else if ([self _isKindOfType:model container:self.primitiveTypes]) {
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
        SZEnumerateAllClassProperty([model class], ^(NSString * _Nonnull property_name, NSString * _Nonnull type_attribute) {
            id obj = [model valueForKey:property_name];
            [ret setObject:[self _foundationObjFromModel:obj] forKey:property_name];
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

- (BOOL)_isKindOfType:(id)obj container:(NSSet<Class> *)container {
    Class klass = [obj class];
    
    if ([container containsObject:klass]) {
        return YES;
    }
    
    for (Class klassInContainer in container) {
        if ([klass isSubclassOfClass:klassInContainer]) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Getter
- (NSSet<Class> *)primitiveTypes {
    if (!_primitiveTypes) {
        _primitiveTypes =
        [NSSet setWithArray:@[
                              NSNull.class,
                              NSNumber.class,
                              NSString.class,
                              NSDictionary.class,
                              ]];
    }
    
    return _primitiveTypes;
}

- (NSSet<Class> *)modelPrimitiveTypes {
    if (!_modelPrimitiveTypes) {
        _modelPrimitiveTypes =
        [NSSet setWithArray:@[
                              NSNull.class,
                              NSNumber.class,
                              NSString.class,
                              ]];
    }
    
    return _modelPrimitiveTypes;
}

#pragma mark - API
- (id)modelFromClass:(Class)klass dictionary:(NSDictionary *)dictioary {
    return [self _modelFromClass:klass foundationObj:dictioary];
}

- (id)foundationObjFromModel:(NSObject *)model {
    return [self _foundationObjFromModel:model];
}

@end

NS_ASSUME_NONNULL_END
