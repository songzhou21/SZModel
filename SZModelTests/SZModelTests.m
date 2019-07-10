//
//  SZModelTests.m
//  SZModelTests
//
//  Created by songzhou on 2018/6/30.
//  Copyright © 2018年 songzhou. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SZJSONAdaptor.h"
#import "SZModelSample.h"
#import "SZNestedObject.h"

@interface SZModelTests : XCTestCase

@property (nonatomic, copy) NSDictionary *jsonDictionary;
@property (nonatomic, copy) NSDictionary *validDictionary;

@end

@implementation SZModelTests

- (void)setUp {
    [super setUp];

    NSString *filePath = [[NSBundle bundleForClass:SZJSONAdaptor.class] pathForResource:@"sample" ofType:@"json"];
    NSError *error;
    _jsonDictionary = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:filePath] options:0 error:&error];
    
    NSMutableDictionary *dict = [_jsonDictionary mutableCopy];
    [dict removeObjectForKey:@"notExistsProperty"];
    
    _validDictionary = dict;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDictionary2Object {
    SZJSONAdaptor *adaptor = [SZJSONAdaptor new];
    SZModelSample *model = [adaptor modelFromClass:[SZModelSample class] dictionary:_jsonDictionary];
    
    XCTAssert(_jsonDictionary[@"notExistsProperty"]);
    XCTAssert(model.somePrimitiveInt == 42);
    XCTAssert([model.someInt isEqual:@42]);
    XCTAssert([model.someFloat isEqual:@4.2]);
    XCTAssert([model.someString isEqualToString:@"string"]);
    XCTAssert(model.someTrue == YES);
    XCTAssert(model.someFalse == NO);
    XCTAssertNil(model.someNull);
    XCTAssert(model.someArray.count == 3);
    XCTAssert([model.someArray.firstObject isEqual:@1]);
    XCTAssert([model.nestedObject isKindOfClass:[NSObject class]]);
    
    XCTAssert([model.decimal isKindOfClass:[NSDecimalNumber class]]);
}

- (void)testNestedDictionary2Ojbect {
    SZJSONAdaptor *adaptor = [SZJSONAdaptor new];
    SZModelSample *model = [adaptor modelFromClass:[SZModelSample class] dictionary:_jsonDictionary];
    
    XCTAssert([model.nestedObject isKindOfClass:[SZNestedObject class]]);
    XCTAssert([model.nestedObject.name isEqualToString:@"name"]);
    XCTAssert([model.nestedObject.nestedObject isKindOfClass:[SZNestedObject2 class]]);
    XCTAssert([model.nestedObject.nestedObject.name isEqualToString:@"name2"]);
}

- (void)testNestedArray {
    SZJSONAdaptor *adaptor = [SZJSONAdaptor new];
    SZModelSample *model = [adaptor modelFromClass:[SZModelSample class] dictionary:_jsonDictionary];
    
    XCTAssert([model.nestedArray.firstObject.name isEqualToString:@"name"]);
    XCTAssert([model.nestedArray.firstObject.nestedObject.name isEqualToString:@"name2"]);
    
    XCTAssert([model.mixArray.firstObject isEqual:@1]);
    /// not support mix array contains object
    XCTAssert([model.mixArray[2] isKindOfClass:[NSDictionary class]]);
}

#pragma mark - Foundation to JSON
- (void)testObj2Dictionary {
    SZJSONAdaptor *adaptor = [SZJSONAdaptor new];
    SZModelSample *model = [adaptor modelFromClass:[SZModelSample class] dictionary:_validDictionary];
    NSDictionary *dict = [adaptor foundationObjFromModel:model];
    
    XCTAssert([_validDictionary isEqualToDictionary:dict]);
    
}

- (void)testNilPropertyToJSON {
    SZModelSample *o = [SZModelSample new];
    o.someString = @"string";
    o.someInt = nil;
    
    SZJSONAdaptor *adaptor = [SZJSONAdaptor new];
    NSDictionary *ret = [adaptor foundationObjFromModel:o];
    
    XCTAssert([ret[@"someInt"] isEqual:[NSNull null]]);
    XCTAssert([ret[@"someString"] isEqualToString:@"string"]);
}

- (void)testNilPropertyNoNullToJSON {
    SZModelSample *o = [SZModelSample new];
    
    SZJSONAdaptor *adaptor = [SZJSONAdaptor new];
    NSDictionary *ret = [adaptor foundationObjNoNullFromModel:o];
    
    XCTAssert([ret[@"someInt"] isEqual:@0]);
    XCTAssert([ret[@"decimal"] isEqual:@0]);
    XCTAssert([ret[@"someString"] isEqualToString:@""]);
    XCTAssert([ret[@"someNull"] isEqualToString:@""]);
    XCTAssert([ret[@"nestedObject"] isEqual:[NSNull null]]);
}

- (void)testIgnoreNilPropertyToJSON {
    SZModelSample *o = [SZModelSample new];
    o.someString = @"string";
    o.someArray = @[@1];
    
    SZJSONAdaptor *adaptor = [SZJSONAdaptor new];
    adaptor.ignoreNilValue = YES;
    NSDictionary *ret = [adaptor foundationObjFromModel:o];
    NSDictionary *noNullRet = [adaptor foundationObjNoNullFromModel:o];
    
    // properties assigned value
    XCTAssert([ret[@"someString"] isEqualToString:@"string"]);
    XCTAssert([ret[@"someArray"] isEqualToArray:@[@1]]);
    
    // primitive properties have inital value
    XCTAssert([ret[@"someTrue"] isEqual:@(NO)]);
    XCTAssert([ret[@"someFalse"] isEqual:@(NO)]);
    XCTAssert([ret[@"somePrimitiveInt"] isEqual:@(0)]);
    
    // properties are not convertedeeee
    XCTAssertNil(ret[@"someNull"]);
    
    XCTAssert([ret isEqualToDictionary:noNullRet]);
}

- (void)testSubclassToJSON {
    SZModelSampleChild *o = [SZModelSampleChild new];
    o.someString = @"string";
    o.childName = @"child";
    
    SZJSONAdaptor *adaptor = [SZJSONAdaptor new];
    NSDictionary *ret = [adaptor foundationObjFromModel:o];
    
    XCTAssert([ret[@"someString"] isEqualToString:@"string"]);
    XCTAssert([ret[@"childName"] isEqualToString:@"child"]);
}

@end
