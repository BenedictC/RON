//
//  EMKUTF8StreamScannerTest.m
//  RON
//
//  Created by Benedict Cohen on 05/07/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "EMKUTF8StreamScannerTest.h"

#import "EMKUTF8StreamScanner.h"
#import "EMKUTF8StreamScanner+RONScalarMatching.h"
#import "EMKToken.h"



@implementation EMKUTF8StreamScannerTest

//-(void)testStringReaderData
//{
//    NSString *path = [@"~/arf.txt" stringByExpandingTildeInPath];    
//    NSData *referenceBytes = [NSData dataWithContentsOfFile:path];    
//    
//    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
//    [stream open];
//    
//    EMKUTF8StreamReader *stringReader = [[EMKUTF8StreamReader alloc] initWithStream:stream];
//    
//    STAssertTrue([stringReader compareStreamToData:referenceBytes], @"Stream data not equal to reference data!");
//}
//
//
//
//-(void)testStringReaderString
//{
//    NSString *path = [@"~/arf.txt" stringByExpandingTildeInPath];    
//    NSString *referenceString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
//    
//    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
//    [stream open];
//    
//    EMKUTF8StreamReader *stringReader = [[EMKUTF8StreamReader alloc] initWithStream:stream];
//    
//    STAssertTrue([stringReader compareStreamToString:referenceString], @"Stream data not equal to reference string!");
//}



-(EMKUTF8StreamScanner *)scannerWithString:(NSString *)string {
    NSInputStream *stream = [NSInputStream inputStreamWithData:[string dataUsingEncoding:NSUTF8StringEncoding]];
    [stream open];
    
    return [[EMKUTF8StreamScanner alloc] initWithStream:stream];
}



-(void)testScanCharactersFromSet {
    EMKUTF8StreamScanner *reader = [self scannerWithString:@"123abc"];
    NSString *result = nil;
        
    STAssertTrue([reader scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&result], @"scanCharacterFromSet failed to scan");    
    STAssertEqualObjects(@"123", result, @"scanCharacterFromSet return incorrect value");
    STAssertEqualObjects(@"a", [reader read:1], @"reader left in incorrect state");
    
    //reset reader and result
    reader = [self scannerWithString:@"123abc"];    
    result = nil;    
    STAssertFalse([reader scanCharactersFromSet:[NSCharacterSet uppercaseLetterCharacterSet] intoString:&result], @"scanCharacterFromSet failed to scan");    
    STAssertEqualObjects(@"1", [reader read:1], @"reader left in incorrect state");
    
    //reset reader and result
    reader = [self scannerWithString:@"123abc"];    
    result = nil;        
    STAssertFalse([reader scanCharactersFromSet:[NSCharacterSet lowercaseLetterCharacterSet] intoString:&result], @"scanCharacterFromSet failed to scan");    
    STAssertEqualObjects(@"1", [reader read:1], @"reader left in incorrect state");    
}



-(void)testScanUpToCharactersFromSet {
    //TODO:    
}



-(void)testScanString {
    //TODO:    
}



-(void)testScanUpToString {
    //TODO:    
}



-(void)testLookAheadForString {
    //TODO:
}



-(void)testLookAheadForCharacterFromSet {
    //TODO:
}



-(void)testScanNumber {
    [self subTestScanInteger:@"12345"];
    [self subTestScanInteger:@"-12345"];

    [self subTestScanDouble:@"1.5"];
    [self subTestScanDouble:@"-1.5"];
    [self subTestScanDouble:@"1.5e60"];
    [self subTestScanDouble:@"-1.5e60"];
    [self subTestScanDouble:@"-1.5e-60"];
}



-(void)subTestScanInteger:(NSString *)num {
    id scanner = [self scannerWithString:num];
    NSNumber *actual = [scanner scanNumber].value;
    NSNumber *expected = [NSNumber numberWithInteger:[num integerValue]];
    STAssertEqualObjects(actual, expected, @"integer scanning failed");
}



-(void)subTestScanDouble:(NSString *)num {
    id scanner = [self scannerWithString:num];
    NSNumber *actual = [scanner scanNumber].value;
    NSNumber *expected = [NSNumber numberWithDouble:[num doubleValue]];
    STAssertEqualObjects(actual, expected, @"double scanning failed");
}



-(void)testScanContext {
    [self subTestScanContext:@"    - " length:4];
    [self subTestScanContext:@"\n \n\n\n   \n    - " length:4];
}


-(void)subTestScanContext:(NSString *)context length:(NSUInteger)length {
    id scanner = [self scannerWithString:context];
    NSNumber *actual = [scanner scanContext].value;
    NSNumber *expected = [NSNumber numberWithUnsignedInteger:length];
    STAssertEqualObjects(actual, expected, @"double scanning failed");
}



-(void)testScanContextAfterFailedScanNumber {
    NSString *testString = @"   \n    - 'arf'";
    id scanner = [self scannerWithString:testString];
    [scanner scanNumber];
    EMKToken *result = [scanner scanContext].value;
    NSNumber *expect = [NSNumber numberWithInt:4];
    
    STAssertEqualObjects(result, expect, @" Failed to scan context after unsucessful scan number. Expect: %@, result: %@", expect, result);
}



-(void)testScanContextAfterFailedScanNull {
    NSString *testString = @"   \n    - 'arf'";
    id scanner = [self scannerWithString:testString];
    [scanner scanNull];
    EMKToken *result = [scanner scanContext].value;
    NSNumber *expect = [NSNumber numberWithInt:4];
    
    STAssertEqualObjects(result, expect, @" Failed to scan context after unsucessful scan null. Expect: %@, result: %@", expect, result);
}



-(void)testScanContextAfterFailedScanBoolean {
    NSString *testString = @"   \n    - 'arf'";
    id scanner = [self scannerWithString:testString];
    [scanner scanBoolean];
    EMKToken *result = [scanner scanContext].value;
    NSNumber *expect = [NSNumber numberWithInt:4];
    
    STAssertEqualObjects(result, expect, @" Failed to scan context after unsucessful scan boolean. Expect: %@, result: %@", expect, result);
}



-(void)testScanContextAfterFailedScanStrictString {
    NSString *testString = @"   \n    - 'arf'";
    id scanner = [self scannerWithString:testString];
    [scanner scanStrictString];
    EMKToken *result = [scanner scanContext].value;
    NSNumber *expect = [NSNumber numberWithInt:4];
    
    STAssertEqualObjects(result, expect, @" Failed to scan context after unsucessful scan strict string. Expect: %@, result: %@", expect, result);
}



-(void)testScanContextAfterFailedKeyString {
    NSString *testString = @"   \n    - 'arf'";
    id scanner = [self scannerWithString:testString];
    [scanner scanKeyString];
    EMKToken *result = [scanner scanContext].value;
    NSNumber *expect = [NSNumber numberWithInt:4];
    
    STAssertEqualObjects(result, expect, @" Failed to scan context after unsucessful scan key string. Expect: %@, result: %@", expect, result);
}



-(void)testScanContextAfterFailedScanPairDelimiter {
    NSString *testString = @"   \n    - 'arf'";
    id scanner = [self scannerWithString:testString];
    [scanner scanPairDelimiter];
    EMKToken *result = [scanner scanContext].value;
    NSNumber *expect = [NSNumber numberWithInt:4];
    
    STAssertEqualObjects(result, expect, @" Failed to scan context after unsucessful scan pair delimter. Expect: %@, result: %@", expect, result);
}


-(void)disabled_testRead {
    NSString *corpusPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"JSON_TEST_CORPUS_PATH"];
    NSString *path = [corpusPath stringByAppendingPathComponent:@"sample.json"];

    NSString *actual = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    
    NSInputStream *stream = [[NSInputStream alloc] initWithFileAtPath:path];
    [stream open];
    EMKUTF8StreamScanner *scanner = [[EMKUTF8StreamScanner alloc] initWithStream:stream];
    
    NSMutableString *scannedString = [NSMutableString string];
    while (![scanner isAtEnd]) {
        [scannedString appendString:[scanner read:1]];
    }
    
    STAssertEqualObjects(actual, [scannedString copy], @"Scanned string is incorrect!");
}

@end
