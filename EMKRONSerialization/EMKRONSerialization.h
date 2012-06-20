//
//  EMKRONSerialization.h
//  RON
//
//  Created by Benedict Cohen on 06/04/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>



typedef enum
{
    EMKRONReadingStrictMode = (0),
    EMKRONReadingPermissiveMode = (1UL << 0),    

    //TODO:
//    EMKRONReadingMutableContainers = (1UL << 1),
//    EMKRONReadingMutableLeaves = (1UL << 2),
//    EMKRONReadingAllowFragments = (1UL << 3)
} EMKRONReadingOptions;



typedef enum
{
    EMKRONWritingFullQuoting = (0),
} EMKRONWritingOptions;

extern NSString * const EMKRONErrorDomain;



@interface EMKRONSerialization : NSObject

//TODO:
//+(BOOL)RONObjectWithStream:(NSInputStream *)stream options:(EMKRONReadingOptions)options error:(NSError *__autoreleasing *)error 
+(id)RONObjectWithData:(NSData *)ronData options:(EMKRONReadingOptions)options error:(NSError *__autoreleasing *)error;

+(BOOL)writeRONObject:(id)object toStream:(NSOutputStream *)stream options:(EMKRONWritingOptions)opt error:(NSError **)error;
+(NSData *)dataWithRONObject:(id)object options:(EMKRONReadingOptions)options error:(NSError *__autoreleasing *)error;

//TODO:
//+ isValidJSONObject: 
@end
