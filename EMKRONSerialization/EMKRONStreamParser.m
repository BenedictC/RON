//
//  EMKRONStreamParser.m
//  RON
//
//  Created by Benedict Cohen on 22/06/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "EMKRONStreamParser.h"


#import "EMKUTF8StreamScanner+RONScalarMatching.h"
#import "EMKRONTokensAndTypes.h"
#import "EMKToken.h"


#pragma mark - context function
typedef enum {
    EMKRONContextTokenIsChild = NSOrderedAscending,
    EMKRONContextTokenIsSibling = NSOrderedSame,
    EMKRONContextTokenIsParent = NSOrderedDescending,
    EMKRONContextTokenIsInvalid,
    EMKRONReferenceContextTokenIsInvalid,
} EMKRONContextTokenComparisonResult;

static EMKRONContextTokenComparisonResult compareContextTokens(EMKToken *referenceContextToken, EMKToken *contextToken) {
    //TODO: if contextToken is not a context then the input is invalid
    if (referenceContextToken == nil || referenceContextToken.type != EMKRONContextType)  return EMKRONReferenceContextTokenIsInvalid;
    if (contextToken == nil          || contextToken.type != EMKRONContextType)           return EMKRONContextTokenIsInvalid;
    
    return ([referenceContextToken.value compare:contextToken.value]);
}



static EMKToken * reinturpretTokenAsString(EMKToken *token) {
    return [EMKToken tokenWithType:EMKRONStringType value:token.sourceText sourceText:token.sourceText];
}



static NSString * const EMKRONParsingException = @"EMKRONParsingException";
#define RAISE_PARSING_EXCEPTION(format...) { \
    NSString *reason = [NSString stringWithFormat:format]; \
    [[NSException exceptionWithName:EMKRONParsingException reason:reason userInfo:nil] raise]; \
}



#pragma mark - EMKRONStreamParser
@interface EMKRONStreamParser ()
@property(readonly, nonatomic) EMKUTF8StreamScanner *stream;
@property(readonly, nonatomic) EMKRONReadingOptions parseMode;
@property(readonly, nonatomic) NSMutableArray *tokenQueue;
@end



@implementation EMKRONStreamParser

#pragma mark instance life cycle
-(id)initWithStream:(NSInputStream *)stream parseMode:(EMKRONReadingOptions)parseMode {
    self = [super init];
    if (self != nil) {
        if (stream == nil || [stream streamStatus] == NSStreamStatusNotOpen) {
            NSString *reason = [NSString stringWithFormat:@"Stream <%@> is not open", stream];
            [[NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil] raise];
            return nil;
        }
        
        _stream = [[EMKUTF8StreamScanner alloc] initWithStream:stream];
        _parseMode = parseMode;
        _tokenQueue = [NSMutableArray new];
    }
    return self;
}



#pragma mark document parsing
-(id)parse:(NSError *__autoreleasing *)error {
    id value = nil;

    BOOL (^isParsingComplete)(void) = ^BOOL(void) {
        return ([self lookAtNextToken] == nil && [self.stream isAtEnd]);
    };
    
    if (!isParsingComplete()) {
        //a document should contain at most 1 top level value and it must be a collection
        @try {
            value = [self parseCollection];
            
            if (value == nil) {
                //TODO: Implement the error value                
                NSError *__autoreleasing noRootCollectionError = [NSError errorWithDomain:EMKRONErrorDomain code:0 userInfo:nil];
                error = &noRootCollectionError;
                return nil;
            }
        }
        @catch (NSException *exception) {
            if (exception.name == EMKRONParsingException) {
                //TODO: Implement the error value
                NSError *__autoreleasing exceptionError = [NSError errorWithDomain:EMKRONErrorDomain code:0 userInfo:nil];
                error = &exceptionError;
                return nil;
            }
            
            [exception raise];
        }
        
        if (!isParsingComplete()) {
            //TODO: Implement the error value
            NSError *__autoreleasing extraneousDataError = [NSError errorWithDomain:EMKRONErrorDomain code:0 userInfo:nil];
            error = &extraneousDataError;
            return nil;
        }
    }   
    
    return value;
}



#pragma mark - queue methods
-(EMKToken *)consumeNextToken {
    EMKToken *token = [self lookAtNextToken];
    if (token != nil) {
        [self.tokenQueue removeObjectAtIndex:0];
    }
        
    EMKRONTypes type = token.type;
    NSString *typeDescription = (type == EMKRONNumberType)        ? @"EMKRONNumberType" :
    (type == EMKRONNullType)          ? @"EMKRONNullType" :
    (type == EMKRONBooleanType)       ? @"EMKRONBooleanType" :
    (type == EMKRONStringType)        ? @"EMKRONStringType" :
    
    //Structural types (i.e. not data, but explicitly stated in the input stream)
    (type == EMKRONContextType)       ? @"EMKRONContextType" :
    (type == EMKRONKeyType)           ? @"EMKRONKeyType" :
    (type == EMKRONPairDelimiterType) ? @"EMKRONPairDelimiterType" :
    
    //Pseudo/implied types
    (type == EMKRONArrayOpenType)     ? @"EMKRONArrayOpenType" :
    (type == EMKRONArrayCloseType)    ? @"EMKRONArrayCloseType" :
    (type == EMKRONObjectOpenType)    ? @"EMKRONObjectOpenType" :
    (type == EMKRONObjectCloseType)   ? @"EMKRONObjectCloseType" :
    @"INVALID TOKEN TYPE";
    
//    NSLog(@"<%@ %p: type = %@; value = %@>", NSStringFromClass([token class]), token,  typeDescription, token.value);
    return token;
}



-(EMKToken *)lookAtNextToken {
    return [self lookAtTokenAtIndex:0];
}



-(EMKToken *)lookAtTokenAtIndex:(NSInteger)index {
    return ([self fillTokenQueueToLength:index+1]) ? [self.tokenQueue objectAtIndex:index] : nil;
}



-(BOOL)fillTokenQueueToLength:(NSInteger)length {
    BOOL shouldScanLinebreakDelimitedString = (self.parseMode & EMKRONReadingPermissiveMode) == EMKRONReadingPermissiveMode;
    NSMutableArray *tokenQueue = self.tokenQueue;
    EMKUTF8StreamScanner *stream = self.stream;
    
    BOOL (^storeToken)(EMKToken *) = ^BOOL(EMKToken *token) {
        if (token == nil) return NO;
        [tokenQueue addObject:token];
        return YES;
    };

    while ([tokenQueue count] < length) {
        //TODO: Is the order of these is important? What's the correct order?

        if (storeToken([stream scanNumber])) continue;
        if (storeToken([stream scanNull])) continue;
        if (storeToken([stream scanBoolean])) continue;
//        if ([self.stream.buffer rangeOfString:@"],s"].location != NSNotFound) {
//            static int count = 0;
//            if (count > 0) {
//                NSLog(@"%s", [self.stream.buffer UTF8String]);
//            }
//            count++;
//        }
        if (storeToken([stream scanStrictString])) continue;
        
        if (shouldScanLinebreakDelimitedString && storeToken([stream scanLinebreakDelimitedString])) continue;

        if (storeToken([stream scanContext])) continue;        
        if (storeToken([stream scanPairDelimiter])) continue;
        if (storeToken([stream scanKeyString])) continue;
        
        //failed to fetch a token
        return NO;
    }

    return YES;
}



#pragma mark value parsing
-(id)parseValue {   
    id value = nil;
    
    value = [self parseCollection];
    if (value != nil) return value;
    
    value = [self parseScalar];
    if (value != nil) return value;        
    
    return value;
}



-(id)parseScalar {
    EMKToken *token = [self lookAtNextToken];

    if (token == nil) return nil;
    
    switch (token.type) {
        case EMKRONNumberType:
        case EMKRONNullType:
        case EMKRONBooleanType:
        case EMKRONStringType:
            [self consumeNextToken];
            return token.value;
            break;
            
        default:
            break;
    }
    
    return nil;
}



-(id)parseCollection {
    id value = nil;
    
    value = [self parseObject];
    if (value != nil) return value;
    
    value = [self parseArray];
    if (value != nil) return value;    
    
    return value;
}



#pragma mark collection parsing
-(NSDictionary *)parseObject {
    //check the stream is an object
    EMKToken *referenceContextToken = [self lookAtTokenAtIndex:0];
    if (referenceContextToken == nil || referenceContextToken.type != EMKRONContextType) return nil;

    EMKToken *keyOrStringOrPairDelimiterToken = [self lookAtTokenAtIndex:1];
    if (keyOrStringOrPairDelimiterToken == nil) return nil; //TODO: Why?
    
    if (keyOrStringOrPairDelimiterToken.type == EMKRONKeyType) {
        
        EMKToken *pairDelimiterToken = [self lookAtTokenAtIndex:2];
        //We're not in an object (probably an array)
        if (pairDelimiterToken.type != EMKRONPairDelimiterType) return nil;
        
    } else if (keyOrStringOrPairDelimiterToken.type == EMKRONStringType) {

        EMKToken *pairDelimiterToken = [self lookAtTokenAtIndex:2];
        //We're not in an object (probably an array)
        if (pairDelimiterToken.type != EMKRONPairDelimiterType) return nil;
        
    } else if (keyOrStringOrPairDelimiterToken.type == EMKRONPairDelimiterType) {
        //We're definitly in an object
    } else {
        //It's not a match
        return nil;
    }

    //From now on we throw an exception if the stream doesn't make sense
    NSMutableDictionary *object = [NSMutableDictionary dictionary];
        
    NSString *key;
    id value;
    while ([self parseObjectPairMatchingReferenceContext:referenceContextToken key:&key value:&value]) {
        if (value == nil) continue;
        [object setObject:value forKey:key];
//        NSLog(@"setObjectForKey: %@", key);
    }

    return [object copy];
}



-(BOOL)parseObjectPairMatchingReferenceContext:(EMKToken *)referenceContextToken key:(NSString *__autoreleasing *)outKey value:(id __autoreleasing *)outValue {
    //reset the output args
    *outKey = nil;
    *outValue = nil;
    
    EMKToken *contextToken = [self lookAtNextToken];
    EMKRONContextTokenComparisonResult tokenComparison = compareContextTokens(referenceContextToken, contextToken);
    
    if (tokenComparison == EMKRONReferenceContextTokenIsInvalid) {
        //TODO: Figure out where the error is in the input stream.
        RAISE_PARSING_EXCEPTION(@"Invalid data in object at <???>");
        return NO;
    }
    
    if (tokenComparison == EMKRONContextTokenIsInvalid) {
        if (contextToken != nil) {
            //TODO: Figure out where the error is in the input stream.
            RAISE_PARSING_EXCEPTION(@"Invalid data in object at <???>");
        }
        return NO;
    }
    
    if (tokenComparison == EMKRONContextTokenIsChild) {
        //TODO: Figure out where the error is in the input stream.
        RAISE_PARSING_EXCEPTION(@"Invalid indentation in object at <???>");
        return NO;
    }
    
    if (tokenComparison == EMKRONContextTokenIsParent) {
        return NO;
    }

    [self consumeNextToken]; //the token is valid - consume it and move on to the key.

    //is the pair likely to be valid?
    EMKToken *keyOrPairDelimiter = [self lookAtNextToken];
    if (keyOrPairDelimiter == nil) {
        //TODO: Figure out where the error is in the input stream.
        RAISE_PARSING_EXCEPTION(@"Expected key or pair delimiter but found ??? at <???>");
        return NO;
    }

    //it's an empty pair
    if (keyOrPairDelimiter.type == EMKRONPairDelimiterType) {
        [self consumeNextToken]; //consume the delimiter
        return YES;
    }
    
    //it's a normal pair
    EMKToken *keyToken = reinturpretTokenAsString(keyOrPairDelimiter);
    if (keyToken != nil) {
        [self consumeNextToken]; //consume the key
        EMKToken *pairDelimiterToken = [self consumeNextToken];
        if (pairDelimiterToken == nil || pairDelimiterToken.type != EMKRONPairDelimiterType) {
            //TODO: Figure out where the error is in the input stream.
            RAISE_PARSING_EXCEPTION(@"Expected pair delimitter, but found ??? at <???>");
            return NO;
        }
        
        id value = [self parseValue];
        if (value == nil) {
            //TODO: Figure out where the error is in the input stream.
            RAISE_PARSING_EXCEPTION(@"No value for key at <???>");
            return NO;
        }
        
        //set the
        *outKey = keyToken.value;
        *outValue = value;
        return YES;
    }
    
    //It doesn't make sense!
    //TODO: Figure out where the error is in the input stream.
    RAISE_PARSING_EXCEPTION(@"No value for key at <???>");
    return NO;
}



-(NSArray *)parseArray {
    //check the stream is an array
    EMKToken *referenceContextToken = [self lookAtTokenAtIndex:0];
    if (referenceContextToken == nil || referenceContextToken.type != EMKRONContextType) return nil;
    
    //From now on we throw an exception if the stream doesn't make sense
    NSMutableArray *array = [NSMutableArray array];
    
    id value;
    while ([self parseArrayElementMatchingReferenceContext:referenceContextToken value:&value]) {
        if (value == nil) continue;
        [array addObject:value];
    }
    
    return [array copy];
}



-(BOOL)parseArrayElementMatchingReferenceContext:(EMKToken *)referenceContextToken value:(id __autoreleasing*)outValue {
    //reset the output arg
    *outValue = nil;
    
    EMKToken *contextToken = [self lookAtNextToken];
    EMKRONContextTokenComparisonResult tokenComparison = compareContextTokens(referenceContextToken, contextToken);
    
    if (tokenComparison == EMKRONReferenceContextTokenIsInvalid) {
        //TODO: Figure out where the error is in the input stream.
        RAISE_PARSING_EXCEPTION(@"Invalid data in object at <???>");
        return NO;
    }
    
    if (tokenComparison == EMKRONContextTokenIsInvalid) {
        if (contextToken != nil) {
            //TODO: Figure out where the error is in the input stream.
            RAISE_PARSING_EXCEPTION(@"Invalid data in object at <???>");
        }
        return NO;
    }
    
    //it's a child collection
    if (tokenComparison == EMKRONContextTokenIsChild) {
        id collection = [self parseCollection];
        if (collection == nil) {
            //TODO: Figure out where the error is in the input stream.
            RAISE_PARSING_EXCEPTION(@"Invalid indentation in object at <???>");
            return NO;
        }
        *outValue = collection;
        return YES;
    }
    
    if (tokenComparison == EMKRONContextTokenIsParent) {
        return NO;
    }

    //The element is a sibling of the matches the reference context
    [self consumeNextToken]; //the token is valid - consume it and move on to the value.    

    //TODO: Check for empty
    //If the next token is a parent context then this element is empty
    EMKToken *possibleParentContext = [self lookAtNextToken];
    if (EMKRONContextTokenIsParent == compareContextTokens(contextToken, possibleParentContext)) {
        return YES;
    }

    //It's a normal element
    id value = [self parseValue];
    if (value == nil) {
        //TODO: Figure out where the error is in the input stream.
        RAISE_PARSING_EXCEPTION(@"No value for key at <???>");
        return NO;
    }
    
    //done!
    *outValue = value;
    return YES;
}

@end
