//
//  EMKRONStreamWriter.m
//  RON
//
//  Created by Benedict Cohen on 22/06/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "EMKRONStreamWriter.h"

#import "EMKRONTokensAndTypes.h"
#define CONTEXT_WIDTH 1


@implementation EMKRONStreamWriter
#pragma mark properties
@synthesize object = _object;
@synthesize stream = _stream;
@synthesize contextSize = _contextSize;



#pragma mark instance life cycle
-(id)initWithStream:(NSOutputStream *)stream object:(id)object {
    self = [super init];
    if (self != nil) {
        _stream = stream;
        _object = object;
    }
    return self;
}



#pragma mark context
-(void)pushContext {
    self.contextSize = self.contextSize + CONTEXT_WIDTH;
}



-(void)popContext {
    self.contextSize = self.contextSize - CONTEXT_WIDTH;
}



-(NSString *)context {
    NSString *format = [NSString stringWithFormat:@"\n%%%lus ", (unsigned long)(self.contextSize + [CONTEXT_TERMINAL_TOKEN length])];
    NSString *result = [NSString stringWithFormat:format, [CONTEXT_TERMINAL_TOKEN UTF8String]];
    //    NSLog(@"'%@'", result);
    return result;
}



#pragma mark append to data
-(void)appendString:(NSString *)string {
//    NSLog(@"Appending string: %@", string);
    //Fetch the bytes to write as UTF8
    //TODO: This is wrong because the string may contain a BOM and a terminating \0
    const u_int8_t * bytes = (const u_int8_t *)[string UTF8String];    
    const NSUInteger length = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    
    //loop until we write all the bytes
    NSUInteger remainingBytes = length;
    while (remainingBytes != 0) {
        const u_int8_t *offsetBytes = bytes + (length-remainingBytes);
        NSInteger result = [[self stream] write:offsetBytes maxLength:remainingBytes];
        
        if (result == 0) { //0 means that the stream is full
            NSString *reason = @"Cannot write to stream. Stream is full.";
            [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
            return;
        }
        else if (result == -1) { //-1 means general error
            NSString *reason = [NSString stringWithFormat:@"Error writing to stream: %@.", [[_stream streamError] localizedDescription]];
            [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
            return;        
        }
        else { //result == number of bytes written
            remainingBytes -= result;
        }
    }
}



#pragma mark writing
-(BOOL)write:(NSError *__autoreleasing *)error {
    BOOL didWriteCollection = NO;    
    @try {
        didWriteCollection = [self writeCollection:self.object];
    }
    @catch (NSException *exception) {
        NSError *__autoreleasing exceptionError = nil;
        error = &exceptionError;
        return NO;
    }
    
    if (!didWriteCollection) {
        NSError *__autoreleasing objectNotACollectionError = nil;
        error = &objectNotACollectionError;
        return NO;        
    }
    
    //return an immutable copy
    //TODO: This is strictly correct, but is it sane?
    return YES;
}



-(BOOL)writeValue:(id)value {
    BOOL didWriteValue = NO;
    
    didWriteValue = [self writeScalar:value];
    if (didWriteValue) return YES;
    
    didWriteValue = [self writeCollection:value];
    if (didWriteValue) return YES;    
    
    NSString *reason = [NSString stringWithFormat:@"Could not write object of type %@", [value class]];
    [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
    return NO;
}



-(BOOL)writeScalar:(id)scalar {
    BOOL didWriteScalar = NO;
    
    didWriteScalar = [self writeTrue:scalar];
    if (didWriteScalar) return YES;
    
    didWriteScalar = [self writeFalse:scalar];
    if (didWriteScalar) return YES;
    
    didWriteScalar = [self writeNumber:scalar];
    if (didWriteScalar) return YES;
    
    didWriteScalar = [self writeNull:scalar];
    if (didWriteScalar) return YES;
    
    didWriteScalar = [self writeString:scalar];
    if (didWriteScalar) return YES;
    
    return NO;
}



-(BOOL)writeCollection:(id)collection {
    BOOL didWriteCollection = NO;
    
    didWriteCollection = [self writeObject:collection];
    if (didWriteCollection) return YES;
    
    didWriteCollection = [self writeArray:collection];
    if (didWriteCollection) return YES;
    
    return NO;
}



#pragma mark collection writing
-(BOOL)writeObject:(NSDictionary *)object {
    if (![object isKindOfClass:[NSDictionary class]]) return NO;
    
    NSString *context = [self context];
    
    __block NSUInteger elementCount = 0;
    __block BOOL wasPreviousElementACollection = NO;    
    __block BOOL didWriteFirstElement = NO;
    
    [object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
         //write context
         [self appendString:context];
         
         //write key
         [self writeString:key];
         
         //write split
         [self appendString:PAIR_DELIMITER_TOKEN];
         
         
         //write value
         BOOL didWriteValue = [self writeScalar:value];
         if (didWriteValue) {
             wasPreviousElementACollection = NO;
         } else {
             [self pushContext];
             didWriteValue = [self writeCollection:value];            
             if (didWriteValue) wasPreviousElementACollection = YES;            
             [self popContext];
         }
         
         if (!didWriteValue) {
             NSString *reason = [NSString stringWithFormat:@"Could not write object of type %@", [value class]];
             [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
             return;            
         } else {
             didWriteFirstElement = YES;
         }
         
         elementCount++;
     }];
    
    //there has to be some artifact that this array existed!
    if (!didWriteFirstElement) {
        [self appendString:context];    
        [self appendString:PAIR_DELIMITER_TOKEN];            
    }
    
    return YES;    
}



-(BOOL)writeArray:(NSArray *)array {
    if (![array isKindOfClass:[NSArray class]]) return NO;
    
    NSString *context = [self context];
    
    NSUInteger elementCount = 0;
    BOOL wasPreviousElementACollection = NO;    
    
    for (id value in array) {
        [self appendString:context];
        
        BOOL didWriteValue = [self writeScalar:value];
        if (didWriteValue) {
            wasPreviousElementACollection = NO;
        } else {
            [self pushContext];
            didWriteValue = [self writeCollection:value];            
            if (didWriteValue) wasPreviousElementACollection = YES;            
            [self popContext];
        }
        
        if (!didWriteValue) {
            NSString *reason = [NSString stringWithFormat:@"Could not write object of type %@", [value class]];
            [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
            return NO;            
        }
        
        elementCount++;
    }
    
    //there has to be some artifact that this array existed!
    BOOL didWriteFirstElement = elementCount > 0;
    if (!didWriteFirstElement) {
        [self appendString:context];
    }
    
    return YES;    
}



#pragma mark scalar writing
-(BOOL)writeNumber:(NSNumber *)number {
    if (![number isKindOfClass:[NSNumber class]]) return NO;
    
    double value = [number doubleValue];
    
    [self appendString:[NSString stringWithFormat:@"%.20g", value]];
    return YES;
}



-(BOOL)writeTrue:(NSNumber *)number {
    if (![number isKindOfClass:[NSNumber class]]) return NO;
    
    //TODO: is this best way to determine if the value is a bool?
    if (number == [NSNumber numberWithBool:YES]) {
        [self appendString:TRUE_TOKEN];
        return YES;
    }
    
    return NO;
}



-(BOOL)writeFalse:(NSNumber *)number {
    if (![number isKindOfClass:[NSNumber class]]) return NO;
    
    //TODO: is this best way to determine if the value is a bool?
    if (number == [NSNumber numberWithBool:NO]) {
        [self appendString:FALSE_TOKEN];
        return YES;        
    }
    
    return NO;
}



-(BOOL)writeNull:(NSNumber *)null {
    if (![null isKindOfClass:[NSNull class]]) return NO;
    
    [self appendString:NULL_TOKEN];
    return YES;        
}



-(BOOL)writeString:(NSString *)string {
    if (![string isKindOfClass:[NSString class]]) return NO;
    
    NSMutableArray *pairs = [NSMutableArray array];
    if ([string length] == 0 || ![[string substringToIndex:1] isEqualToString:OPENING_SQUARE_BRACE_TOKEN]) {
        [pairs addObject:[NSArray arrayWithObjects:OPENING_SQUARE_BRACE_TOKEN, CLOSING_SQUARE_BRACE_TOKEN, nil]];
    }

    if ([string length] == 0 || ![[string substringToIndex:1] isEqualToString:OPENING_CURLY_BRACE_TOKEN]) {
        [pairs addObject:[NSArray arrayWithObjects:OPENING_CURLY_BRACE_TOKEN, CLOSING_CURLY_BRACE_TOKEN, nil]];
    }
    
    NSUInteger delimitterLength = 1;
    while (true) {
        for (NSArray *pair in pairs) {
            //get the delimter tokens
            NSString *openDelimiterToken  = [pair objectAtIndex:0];
            NSString *closeDelimiterToken = [pair lastObject];
            
            //build up the delimiters
            NSMutableString *openDelimiter = [openDelimiterToken mutableCopy];
            NSMutableString *closeDelimiter = [closeDelimiterToken mutableCopy];
            for (NSInteger i = 1; i < delimitterLength; i++) {
                [openDelimiter appendString:openDelimiterToken];
                [closeDelimiter appendString:closeDelimiterToken];
            }
            
            //Can we use these delimiter to quote the string?
            const char *haystack = [string UTF8String];
            size_t haystackLength = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            const char *needle = [closeDelimiter UTF8String];
            size_t needleLength = [closeDelimiter lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            
            BOOL isCloseDelimitterAbscentFromString = memmem(haystack, haystackLength, needle, needleLength) == NULL;
            if (isCloseDelimitterAbscentFromString) {
                NSString *delimitedString = [NSString stringWithFormat:@"%@%@%@", openDelimiter, string, closeDelimiter];
                [self appendString:delimitedString];
                return YES;
            }
        }
        
        // neither pair was usable, increase delimiter size and try again
        delimitterLength++;
    }
    
    return NO;
}

@end
