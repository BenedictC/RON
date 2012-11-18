//
//  RONTest.m
//  RONTest
//
//  Created by Benedict Cohen on 10/04/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "RONTest.h"

#import "EMKRONSerialization.h"
#import "EMKUTF8StreamScanner.h"



@implementation RONTest

//This is a very coarse unit test (it's almost and integration test). We could/(should?) test
//the individual methods of EMKRONSerialization but:
//1. The 'interesting' methods of EMKRONSerialization are private
//2. This approach has been affective
- (void)disabled_testJSONCorpus {
    NSString *corpusPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"JSON_TEST_CORPUS_PATH"];
    NSError *error;
    NSArray *corpusFilenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:corpusPath error:&error];
    if (corpusFilenames == nil) STFail(@"Error reading test corpus: %@", error);
    
        
    for (NSString *jsonFilename in corpusFilenames) {
        //we're only interested in .json files
        if (![[jsonFilename pathExtension] isEqualToString:@"json"]) continue;                
        
        //log the test subject
        NSLog(@"Testing %@", jsonFilename);
        
        //Load JSON object (we use the object to feed create the RON data and verify RON output)
        NSString *path = [corpusPath stringByAppendingPathComponent:jsonFilename];
        NSData *jsonData = [NSData dataWithContentsOfFile:path];
        id jsonObjects = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL];
        
        //Did we successfully load the JSON?
        BOOL isJsonObjectsValid = jsonObjects != nil;
        STAssertTrue(isJsonObjectsValid, @"%@ does not contain valid JSON", jsonFilename);        
        if (!isJsonObjectsValid) continue;
        
        //Loop the RON data
        NSData *ronData = [EMKRONSerialization dataWithRONObject:jsonObjects options:0 error:NULL];
        [ronData writeToFile:[@"/tmp/ron.txt" stringByExpandingTildeInPath] atomically:YES];
        id ronObjects  = [EMKRONSerialization RONObjectWithData:ronData options:0 error:NULL];
        
        //if the RON objects don't match the JSON objects then we may have found a RON bug
        BOOL isJsonEqualToRon = [jsonObjects isEqual:ronObjects];
        STAssertTrue(isJsonEqualToRon, @"%@ failed.", jsonFilename /*, [NSString stringWithFormat:@"%s", [ronData bytes]]*/);                
        
        //Figure out what to do when a test fails
        if (!isJsonEqualToRon) {
//            [ronObjects EMK_logDifferences:jsonObjects];
//            NSData *faultyJsonObjectsData = [NSJSONSerialization dataWithJSONObject:ronObjects options:0 error:NULL];
//            [faultyJsonObjectsData writeToFile:@"/Volumes/Users/ben/faultyRonObjects.json" atomically:YES];
            
            //TODO: set this to $(BUILD_PRODUCTS) using an enivornment var
            //    NSString *failedRonDataDirectory = @"/Volumes/Users/ben/";            
//            //TODO: On failure write RON data to BUILD_PRODUCTS and include failure line number & position in title.
//            int lineNumber, charNumber;
//            NSString *failedRonDataFilename = [NSString stringWithFormat:@"%@ (failed at %i, %i).ron", jsonFilename, lineNumber, charNumber];            
//            NSString *failedRonDataPath     = [failedRonDataDirectory stringByAppendingPathComponent:ronFilename];
//            [ronData writeToFile:failedRonDataPath atomically:NO];
        }
    }
}



- (void)testRONFile {
    NSString *corpusPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"JSON_TEST_CORPUS_PATH"];    
    NSString *path = [corpusPath stringByAppendingPathComponent:@"sample.json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:path];
    id jsonObjects = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL];
    [[NSJSONSerialization dataWithJSONObject:jsonObjects options:0 error:NULL] writeToFile:@"/tmp/looped.json" atomically:YES];
    [[EMKRONSerialization dataWithRONObject:jsonObjects options:0 error:NULL] writeToFile:@"/tmp/ron.txt" atomically:YES];

    NSData *ronData = [NSData dataWithContentsOfFile:[@"/tmp/ron.txt" stringByExpandingTildeInPath]];
    id ronObjects = [EMKRONSerialization RONObjectWithData:ronData options:0 error:NULL];
    
    NSData *loopedJson = [NSJSONSerialization dataWithJSONObject:ronObjects options:0 error:NULL];
    [loopedJson writeToFile:@"/tmp/ronLoop.json" atomically:NO];
    STAssertEqualObjects(ronObjects, jsonObjects, @"ronObjects are not equal");
}

@end
