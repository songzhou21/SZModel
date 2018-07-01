// SZModelSample.h
// 
// Created by songzhou on 2018/06/30
// Model file Generated using objc_export https://github.com/gogozs/objc_export

#import <Foundation/Foundation.h>
#import "SZModel.h"

#import "SZNestedObject.h"

@interface SZModelSample : SZModel

@property (nonatomic) NSNumber* someInt;
@property (nonatomic) NSNumber* someFloat;
@property (nonatomic, copy) NSString* someString;
@property (nonatomic) BOOL someTrue;
@property (nonatomic) BOOL someFalse;
@property (nonatomic) NSNull* someNull;
@property (nonatomic, copy) NSArray* someArray;

@property (nonatomic) SZNestedObject *nestedObject;
@property (nonatomic, copy) NSArray<SZNestedObject *> *nestedArray;
@property (nonatomic, copy) NSArray* mixArray;

@end
