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

@end

@implementation SZModelTests

- (void)setUp {
    [super setUp];

    NSString *filePath = [[NSBundle bundleForClass:SZJSONAdaptor.class] pathForResource:@"sample" ofType:@"json"];
    NSError *error;
    _jsonDictionary = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:filePath] options:0 error:&error];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDictionary2Object {
    SZJSONAdaptor *adaptor = [SZJSONAdaptor new];
    SZModelSample *model = [adaptor modelFromClass:[SZModelSample class] dictionary:_jsonDictionary];
    
    XCTAssert([model.someInt isEqual:@42]);
    XCTAssert([model.someFloat isEqual:@4.2]);
    XCTAssert([model.someString isEqualToString:@"string"]);
    XCTAssert(model.someTrue == YES);
    XCTAssert(model.someFalse == NO);
    XCTAssert(model.someNull == [NSNull null]);
    XCTAssert(model.someArray.count == 3);
    XCTAssert([model.someArray.firstObject isEqual:@1]);
    XCTAssert([model.nestedObject isKindOfClass:[NSObject class]]);
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
    XCTAssert([model.mixArray[2] isKindOfClass:[NSDictionary class]]);
}

@end
