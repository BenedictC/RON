//
//  EMKRONSerialization.h
//  RON
//
//  Created by Benedict Cohen on 06/04/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "EMKRONConstants.h"



@interface EMKRONSerialization : NSObject

+(id)RONObjectWithStream:(NSInputStream *)stream options:(EMKRONReadingOptions)options error:(NSError *__autoreleasing *)error;
+(id)RONObjectWithData:(NSData *)ronData options:(EMKRONReadingOptions)options error:(NSError *__autoreleasing *)error;

+(BOOL)writeRONObject:(id)object toStream:(NSOutputStream *)stream options:(EMKRONWritingOptions)opt error:(NSError **)error;
+(NSData *)dataWithRONObject:(id)object options:(EMKRONReadingOptions)options error:(NSError *__autoreleasing *)error;

//TODO:
//+ isValidJSONObject: 
@end
