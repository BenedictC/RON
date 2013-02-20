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

//This is a very coarse test (it's almost and integration test). We could/(should?) test the individual methods of EMKRONSerialization but:
//1. The 'interesting' methods of EMKRONSerialization are private
//2. This approach has been affective
- (void)testJSONCorpus {
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
        
        //Save the objects as RON
        NSData *ronData = [EMKRONSerialization dataWithRONObject:jsonObjects options:0 error:NULL];
        [ronData writeToFile:[@"/tmp/ron.txt" stringByExpandingTildeInPath] atomically:YES];
        
        //Load the objects from RON
        id ronObjects  = [EMKRONSerialization RONObjectWithData:ronData options:0 error:NULL];
        
        //Compare the JSON and RON objects (do so in such that it doesn't log the objects).
        //if the RON objects don't match the JSON objects then we may have found a RON bug
        BOOL isJsonEqualToRon = [jsonObjects isEqual:ronObjects];
        STAssertTrue(isJsonEqualToRon, @"%@ failed.", jsonFilename /*, [NSString stringWithFormat:@"%s", [ronData bytes]]*/);                        
    }
}



- (void)testJSONFile {
    
    NSString *corpusPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"JSON_TEST_CORPUS_PATH"];    
    NSString *path = [corpusPath stringByAppendingPathComponent:@"sample.json"];
    
    //Load objects from JSON
    NSData *jsonData = [NSData dataWithContentsOfFile:path];
    id jsonObjects = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL];
    
    //Save objects to RON
    [[EMKRONSerialization dataWithRONObject:jsonObjects options:0 error:NULL] writeToFile:@"/tmp/ron.txt" atomically:YES];

    //Load objects from RON
    NSData *ronData = [NSData dataWithContentsOfFile:[@"/tmp/ron.txt" stringByExpandingTildeInPath]];
    id ronObjects = [EMKRONSerialization RONObjectWithData:ronData options:0 error:NULL];

    //Compare JSON and RON objects
    STAssertEqualObjects(ronObjects, jsonObjects, @"ronObjects are not equal");
    
    //Save RON objects as JSON (so we can compare them in a text editor)
//    NSData *loopedJson = [NSJSONSerialization dataWithJSONObject:ronObjects options:0 error:NULL];
//    [loopedJson writeToFile:@"/tmp/ronLoop.json" atomically:NO];
}



- (void)testRONCorpus {
    NSString *corpusPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"RON_TEST_CORPUS_PATH"];
    NSError *error;
    NSArray *corpusFilenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:corpusPath error:&error];
    if (corpusFilenames == nil) STFail(@"Error reading test corpus: %@", error);
    
    
    for (NSString *ronFilename in corpusFilenames) {
        //we're only interested in .ron files
        if (![[ronFilename pathExtension] isEqualToString:@"ron"]) continue;
        
        //log the test subject
        NSLog(@"Testing %@", ronFilename);
        
        //Load JSON object (we use the object to feed create the RON data and verify RON output)
        NSString *path = [corpusPath stringByAppendingPathComponent:ronFilename];
        NSData *ronData = [NSData dataWithContentsOfFile:path];
        id ronObjects = [EMKRONSerialization RONObjectWithData:ronData options:0 error:NULL];
        NSLog(@"%@", ronObjects);
        STAssertNotNil(ronObjects, @"Failed to created RON objects.");

//        NSOutputStream *stream = [NSOutputStream outputStreamToFileAtPath:[@"~/ronloop.json" stringByExpandingTildeInPath] append:NO];
//        [stream open];
//        [NSJSONSerialization writeJSONObject:ronObjects toStream:stream options:0 error:NULL];        
    }
}

@end
