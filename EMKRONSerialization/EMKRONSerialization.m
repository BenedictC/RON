//
//  EMKRONSerialization.m
//  RON
//
//  Created by Benedict Cohen on 06/04/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "EMKRONSerialization.h"

#import "EMKRONConstants.h"
#import "EMKRONStreamParser.h"
#import "EMKRONStreamWriter.h"



#pragma mark - EMKRONSerialization (facade)
@implementation EMKRONSerialization

//reading methods
+(id)RONObjectWithStream:(NSInputStream *)stream options:(EMKRONReadingOptions)options error:(NSError *__autoreleasing *)error
{
    EMKRONStreamParser *parser = [[EMKRONStreamParser alloc] initWithStream:stream parseMode:options];
    return [parser parse:error];
}



+(id)RONObjectWithData:(NSData *)data options:(EMKRONReadingOptions)options error:(NSError *__autoreleasing *)error
{
    //create and open a stream
    NSInputStream *stream = [NSInputStream inputStreamWithData:data];
    [stream open];
    
    return [self RONObjectWithStream:stream options:options error:error];
}



//writing methods
+(BOOL)writeRONObject:(id)object toStream:(NSOutputStream *)stream options:(EMKRONWritingOptions)opt error:(NSError **)error
{
    EMKRONStreamWriter *writer = [[EMKRONStreamWriter alloc] initWithStream:stream object:object];    
    return [writer write:error];
}



+(NSData *)dataWithRONObject:(id)object options:(EMKRONReadingOptions)options error:(NSError *__autoreleasing *)error
{
    //create and open an stream which we can get an NSData from
    NSOutputStream *outStream = [NSOutputStream outputStreamToMemory];
    [outStream open];
    
    BOOL success = [self writeRONObject:object toStream:outStream options:options error:error];
    
    return success ? [outStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] : nil;
}

@end
