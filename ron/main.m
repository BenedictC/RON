//
//  main.m
//  RON
//
//  Created by Benedict Cohen on 06/04/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "EMKRONSerialization.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        NSString *path = @"/Volumes/Users/ben/Desktop/JSON examples/";
        NSArray *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
        
        for (NSString *filename in filenames)
        {
            //load json data
            NSString *jsonPath = [path stringByAppendingPathComponent:filename];
            NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
            NSLog(@"Original JSON:\n%@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
            
            //convert to json objects            
            id jsonObjects = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL];
            
            //convert to normalized json string
            NSString *normalizedJsonString = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:jsonObjects options:0 error:NULL] encoding:NSUTF8StringEncoding];
            NSLog(@"Normalized JSON:\n%@", normalizedJsonString);
            
            //convert json objects to RON
            NSData *ronData = [EMKRONSerialization dataWithRONObject:jsonObjects options:0 error:NULL];
            NSLog(@"RON:\n%@", [[NSString alloc] initWithData:ronData encoding:NSUTF8StringEncoding]);            
            id ronObjects = [EMKRONSerialization RONObjectWithData:ronData options:0 error:NULL];
            
            //convert ronObjects to JSON objects
            //TODO:!!!
            id derivedJSONObjects = nil;
            
            //compare json objects and RON objects
            NSLog(@"%@:\njsonObjects isEqualTo ronObjects: %i\nronObjects isEqualTo derivedJSONObjects: %i", filename, [jsonObjects isEqualTo:ronObjects], [ronObjects isEqualTo:derivedJSONObjects]);
        }
        
        
    }
    return 0;
}

