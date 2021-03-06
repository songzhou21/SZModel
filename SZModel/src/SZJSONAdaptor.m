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

static NSSet<NSString *> *SZAllClassProperty(Class klass) {
    NSMutableArray *ret = [NSMutableArray array];
    SZEnumerateAllClassProperty(klass, ^(NSString * _Nonnull property_name, NSString * _Nonnull type_attribute) {
        [ret addObject:property_name];
    });
    
    return [NSSet setWithArray:ret];
}


NSString * _Nullable SZClassNameFromType(NSString *type_attribute) {
    NSScanner *scanner = [NSScanner scannerWithString:type_attribute];
    
    NSString *quote = @"\"";
    NSString *result;
    if ([scanner scanUpToString:quote intoString:nil] && scanner.scanLocation < type_attribute.length) {
        scanner.scanLocation += 1;
        if ([scanner scanUpToString:quote intoString:&result]) {
            return result;
        }
    }
    
    return nil;
}

@interface SZJSONAdaptor ()

/// primitive types, can be converted to JSON directly, treat NSDictionary as primitive type
@property (nonatomic, copy) NSSet<Class> *primitiveTypes;
/// primitive types, can be converted to JSON directly, not including NSDictioanry
@property (nonatomic, copy) NSSet<Class> *modelPrimitiveTypes;

@property (nonatomic, copy) NSDictionary<NSString *, id> *objInitailValueMap;

@end

@implementation SZJSONAdaptor

- (instancetype)init
{
    self = [super init];
    if (self) {
        _ignoreNilValue = NO;
    }
    return self;
}

/**
 create object from Foundation obj
 
 @param klass the Class of Dictionary, maybe nil if obj is primitive Foundation obj
 @param obj the Foundation obj
 @return custom obj
 */
- (id)_modelFromClass:(nullable Class)klass foundationObj:(NSObject *)obj {
    if (klass == nil) {
        return obj;
    } else if ([obj isEqual:[NSNull null]]) {
        return nil;
    } else if ([self canConvertToFoundationObjFromClass:klass obj:obj]) {
        return [self convertObj:obj toType:klass];
    } else if ([obj isKindOfClass:[NSArray class]]) {
        NSArray *objArray = (NSArray *)obj;
        NSMutableArray *retArray = [NSMutableArray arrayWithCapacity:objArray.count];
        
        for (int i = 0; i < objArray.count; i++) {
            retArray[i] = [self _modelFromClass:klass foundationObj:objArray[i]];
        }
        
        return retArray;
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = (NSDictionary *)obj;
        NSDictionary<NSString *, NSString *> * propertyClassMap = [self _propertyClassMapForClass:klass];
        NSMutableSet<NSString *> *propertyNames = [SZAllClassProperty(klass) mutableCopy];
        [propertyNames intersectSet:[NSSet setWithArray:dictionary.allKeys]];
        
        NSObject *model = [klass new];
        
        for (NSString *propertyName in propertyNames) {
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
        return nil;
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

- (NSObject *)_makeFoundationObjectFromModel:(NSObject *)model type:(NSString *)type maker:(NSObject *(^)(NSObject * _Nullable obj, NSString *type))maker {
    if (model == nil ||
        [self _isKindOfType:model container:self.primitiveTypes]) {
        return maker(model, type);
    } else if ([model isKindOfClass:[NSArray class]]) {
        NSArray *objArray = (NSArray *)model;
        NSMutableArray *retArray = [NSMutableArray arrayWithCapacity:objArray.count];
        
        for (int i = 0; i < objArray.count; i++) {
            NSObject *obj = objArray[i];
            NSString *type = NSStringFromClass([obj class]);
            id ret = [self _makeFoundationObjectFromModel:obj type:type maker:maker];
            if (self.ignoreNilValue && [ret isEqual:[NSNull null]]) {

            } else {
                retArray[i] = ret;
            }
        }
        
        return retArray;
    } else {
        NSMutableDictionary *ret = [NSMutableDictionary dictionary];
        SZEnumerateAllClassProperty([model class], ^(NSString * _Nonnull property_name, NSString * _Nonnull type_attribute) {
            id obj = [model valueForKey:property_name];
            id retObj = [self _makeFoundationObjectFromModel:obj type:SZClassNameFromType(type_attribute) maker:maker];
            
            if (self.ignoreNilValue && [retObj isEqual:[NSNull null]]) {
                
            } else {
                [ret setObject:retObj forKey:property_name];
            }
        });
        
        return ret;
    }
}

- (NSObject *)_foundationObjFromModel:(NSObject *)model {
    return
    [self _makeFoundationObjectFromModel:model
                                    type:NSStringFromClass(model.class)
                                   maker:^NSObject * _Nonnull(NSObject * _Nullable obj, NSString * _Nonnull type) {
                                       if (obj == nil) {
                                           return [NSNull null];
                                       } else {
                                           return obj;
                                       }
                                   }];
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

- (BOOL)canConvertToFoundationObjFromClass:(nullable Class)klass obj:(NSObject *)obj {
    return
    [klass isSubclassOfClass:[NSDictionary class]] ||
    [self _isKindOfType:obj container:self.modelPrimitiveTypes];
}

- (NSObject *)convertObj:(NSObject *)obj toType:(Class)result {
    Class source = [obj class];
    
    if ([result isSubclassOfClass:[NSDictionary class]]) {
        return obj;
    }
    
    if ([source isSubclassOfClass:[NSNumber class]] &&
        [result isSubclassOfClass:[NSDecimalNumber class]]) {
        return [NSDecimalNumber decimalNumberWithDecimal:[(NSNumber *)obj decimalValue]];
    }
    
    return obj;
}

- (nullable id)initailValueForType:(NSString *)type {
    Class typeClass = NSClassFromString(type);
    __auto_type types = [self objInitailValueMap].allKeys;
    
    NSString *foundType;
    for (NSString *initalType in types) {
        if ([typeClass isSubclassOfClass:NSClassFromString(initalType)]) {
            foundType = initalType;
        }
    }
    
    return [self objInitailValueMap][foundType];
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
                              NSNumber.class,
                              NSString.class,
                              ]];
    }
    
    return _modelPrimitiveTypes;
}

- (NSDictionary<NSString *,id> *)objInitailValueMap {
    if (!_objInitailValueMap) {
        _objInitailValueMap =
        @{
          NSStringFromClass([NSNumber class]): @0,
          NSStringFromClass([NSString class]) : @"",
          NSStringFromClass([NSArray class]) : @[],
          NSStringFromClass([NSDictionary class]) : @{}
          };
    }
    
    return _objInitailValueMap;
}

#pragma mark - API
- (id)modelFromClass:(Class)klass dictionary:(NSDictionary *)dictioary {
    return [self _modelFromClass:klass foundationObj:dictioary];
}

- (id)foundationObjFromModel:(NSObject *)model {
    return [self _foundationObjFromModel:model];
}

- (id)foundationObjNoNullFromModel:(NSObject *)model {
    return
    [self _makeFoundationObjectFromModel:model
                                    type:NSStringFromClass(model.class)
                                   maker:^NSObject * _Nonnull(NSObject * _Nullable obj, NSString * _Nonnull type) {
                                       if (obj == nil) {
                                           if (self.ignoreNilValue) {
                                               return [NSNull null];
                                           } else {
                                               return [self initailValueForType:type] ?: [NSNull null];
                                           }
                                       } else {
                                           return obj;
                                       }
                                   }];
}

@end

NS_ASSUME_NONNULL_END
