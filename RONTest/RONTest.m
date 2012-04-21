//
//  RONTest.m
//  RONTest
//
//  Created by Benedict Cohen on 10/04/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "RONTest.h"

#import "EMKRONSerialization.h"

@implementation RONTest

- (void)setUp
{
    [super setUp];    
    // Set-up code here.
}



- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}



- (void)testJSONCorpus
{

    NSString *corpusPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"JSON_TEST_CORPUS_PATH"];
    NSArray *corpusFilenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:corpusPath error:NULL];
    
    for (NSString *jsonFilename in corpusFilenames)
    {
        if (![[jsonFilename pathExtension] isEqualToString:@"json"]) continue;                
        
        NSLog(@"Testing %@", jsonFilename);
        NSString *path = [corpusPath stringByAppendingPathComponent:jsonFilename];
        
        NSData *jsonData = [NSData dataWithContentsOfFile:path];
        id jsonObjects = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL];
        
        NSData *ronData = [EMKRONSerialization dataWithRONObject:jsonObjects options:0 error:NULL];
//        NSLog(@"\n%@",[NSString stringWithFormat:@"%s", [ronData bytes]]);
        id ronObjects  = [EMKRONSerialization RONObjectWithData:ronData options:0 error:NULL];
        
        STAssertEqualObjects(jsonObjects, ronObjects, @"%@ failed:\n%@", jsonFilename, [NSString stringWithFormat:@"%s", [ronData bytes]]);        
    }    
}

@end
