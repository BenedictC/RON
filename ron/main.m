//
//  main.m
//  RON
//
//  Created by Benedict Cohen on 06/04/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "EMKRONSerialization.h"



BOOL convertRonToJson(NSString *ronPath) {
    //Read
    NSInputStream *inStream = [NSInputStream inputStreamWithFileAtPath:ronPath];
    [inStream open];
    NSError *error;
    id objects = [EMKRONSerialization RONObjectWithStream:inStream options:0 error:&error];
    if (objects == nil) {
        fprintf(stderr, "%s", [[error localizedDescription] UTF8String]);
        return NO;        
    }
    
    //Write
    NSData *json = [NSJSONSerialization dataWithJSONObject:objects options:0 error:&error];
    if (json == nil) {
        fprintf(stderr, "%s", [[error localizedDescription] UTF8String]);
        return NO;        
    }
    
    fprintf(stdout, "%s", [[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] UTF8String]);
    return YES;
}



BOOL convertJsonToRon(NSString *jsonPath) {
    //Read
    NSInputStream *inStream = [NSInputStream inputStreamWithFileAtPath:jsonPath];
    [inStream open];
    NSError *error;
    id objects = [NSJSONSerialization JSONObjectWithStream:inStream options:0 error:&error];
    if (objects == nil) {
        fprintf(stderr, "%s", [[error localizedDescription] UTF8String]);
        return NO;
    }
    
    //Write
    NSData *ron = [EMKRONSerialization dataWithRONObject:objects options:0 error:&error];
    if (ron == nil) {
        fprintf(stderr, "%s", [[error localizedDescription] UTF8String]);
        return NO;        
    }
    
    fprintf(stdout, "%s", [[[NSString alloc] initWithData:ron encoding:NSUTF8StringEncoding] UTF8String]);
    return YES;
}



int main(int argc, const char * argv[]){

    @autoreleasepool {
        NSString *inputPath = [[[NSProcessInfo processInfo] arguments] objectAtIndex:1];
        
        if (convertRonToJson(inputPath)) return 0;
        if (convertJsonToRon(inputPath)) return 0;
    }
    return 1;
}



