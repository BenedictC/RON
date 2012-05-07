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


//This is a very coarse unit test (it's almost and integration test). We could/(should?) test
//the individual methods of EMKRONSerialization but:
//1. The 'interesting' methods of EMKRONSerialization are private
//2. This approach has been affective
- (void)testJSONCorpus
{
    NSString *corpusPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"JSON_TEST_CORPUS_PATH"];
    NSArray *corpusFilenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:corpusPath error:NULL];
        
    for (NSString *jsonFilename in corpusFilenames)
    {
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
        id ronObjects  = [EMKRONSerialization RONObjectWithData:ronData options:0 error:NULL];
        
        //if the RON objects don't match the JSON objects then we may have found a RON bug
        BOOL isJsonEqualToRon = [jsonObjects isEqual:ronObjects];
        STAssertTrue(isJsonEqualToRon, @"%@ failed.", jsonFilename /*, [NSString stringWithFormat:@"%s", [ronData bytes]]*/);                

        //Note that RON has laxer parsing rules for numbers than JSON
        
        
        //Figure out what to do when a test fails
        if (!isJsonEqualToRon)
        {
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



//-(void)testNumbers
//{
//    return;
//    //[-130142114406915000] [1.1217523390167132e-19] [-5514085325291784739] [-1501399301447081980] [-7271305752851720826] [-130142114406914976] [-4573719180530212900] [3808159498143417627] [-2226135764510113982]
//    NSArray *numberStrings = [@"[-1.755521549112845e-19] [.0000000000000000000569437448157756] [-.000000000000000000175552154911284] [.0000000000000000000638577973698933] [-.000000000000000000689194621146233] [-.000000000000000000356875010196769]" componentsSeparatedByString:@" "];
//    
//    for(NSString *numberString in numberStrings)
//    {
//        NSNumber *jsonNumber = [[NSJSONSerialization JSONObjectWithData:[numberString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL] lastObject];
//        NSNumber *scannedNumber = [self scanNumberString:numberString];
//        BOOL areEqual = jsonNumber != nil && scannedNumber != nil && [scannedNumber isEqualToNumber:jsonNumber];
//
//        STAssertTrue(areEqual, @"\nstr : %@\n=============\njson: %@ \nron : %@ \n\n", numberString, jsonNumber, scannedNumber);
//    }
//}
//
//
//-(NSNumber *)scanNumberString:(NSString *)numberString
//{
//    NSScanner *scanner = [[NSScanner alloc] initWithString:[numberString substringWithRange:NSMakeRange(1, [numberString length]-2)]];
//    [scanner setCharactersToBeSkipped:nil];
//
//    double scannedDouble;
//    return ([scanner scanDouble:&scannedDouble]) ? [NSNumber numberWithDouble:scannedDouble] : nil;
//    
////    long long scannedLongLong;
////    return ([scanner scanLongLong:&scannedLongLong]) ? [NSNumber numberWithLongLong:scannedLongLong] : nil;
//    
////-----------    
////    NSNumberFormatter *formatter = [NSNumberFormatter new];
////    return [formatter numberFromString:[numberString substringWithRange:NSMakeRange(1, [numberString length]-2)]];
//}

@end
