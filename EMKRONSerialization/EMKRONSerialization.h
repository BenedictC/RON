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
    EMKRONReadingMutableContainers = (1UL << 1),
    EMKRONReadingMutableLeaves = (1UL << 2),
    EMKRONReadingAllowFragments = (1UL << 3)
} EMKRONSerializationOptions;

extern NSString * const EMKRONErrorDomain;



@interface EMKRONSerialization : NSObject

+(id)RONObjectWithData:(NSData *)ronData options:(EMKRONSerializationOptions)options error:(NSError *__autoreleasing *)error;
+(NSData *)dataWithRONObject:(id)object options:(EMKRONSerializationOptions)options error:(NSError *__autoreleasing *)error;

//TODO:
//+ JSONObjectWithStream:options:error:
//+ writeJSONObject:toStream:options:error:
//+ isValidJSONObject:
@end
