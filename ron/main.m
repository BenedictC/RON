//
//  main.m
//  RON
//
//  Created by Benedict Cohen on 06/04/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "EMKRONSerialization.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool 
    {
        //Read
        NSString *ronPath = [[[NSProcessInfo processInfo] arguments] objectAtIndex:1];
        
        NSInputStream *inStream = [NSInputStream inputStreamWithFileAtPath:ronPath];
        [inStream open];
        NSError *error;
        id objects = [EMKRONSerialization RONObjectWithStream:inStream options:0 error:&error];
        if (objects == nil) {
            fprintf(stderr, "%s", [[error localizedDescription] UTF8String]);
        }
        
        //Write
        NSData *json = [NSJSONSerialization dataWithJSONObject:objects options:0 error:&error];
        if (json == nil) {
            fprintf(stderr, "%s", [[error localizedDescription] UTF8String]);
        }

        fprintf(stdout, "%s", [[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] UTF8String]);
        
        //TODO: 
        // Implicition conversions
        // JSON -> RON
        // RON  -> JSON
        //
        // - Add switches for explict conversion
    }
    return 0;
}

