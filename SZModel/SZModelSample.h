// SZModelSample.h
// 
// Created by songzhou on 2018/06/30
// Model file Generated using objc_export https://github.com/gogozs/objc_export

#import <Foundation/Foundation.h>

#import "SZNestedObject.h"
#import "SZCodable.h"

NS_ASSUME_NONNULL_BEGIN

@interface SZModelSample : NSObject <SZCodable>

@property (nonatomic) NSInteger somePrimitiveInt;
@property (nullable, nonatomic) NSNumber* someInt;
@property (nonatomic) NSNumber* someFloat;
@property (nonatomic, copy) NSString* someString;
@property (nonatomic) BOOL someTrue;
@property (nonatomic) BOOL someFalse;
@property (nullable, nonatomic) NSString* someNull;
@property (nonatomic, copy) NSArray* someArray;

@property (nonatomic) SZNestedObject *nestedObject;
@property (nonatomic, copy) NSArray<SZNestedObject *> *nestedArray;
@property (nonatomic, copy) NSArray* mixArray;

@property (nonatomic, copy) NSDictionary* dict;

@end

@interface SZModelSampleChild : SZModelSample

@property (nonatomic, copy) NSString* childName;

@end

NS_ASSUME_NONNULL_END
