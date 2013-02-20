//
//  EMKRONStreamParser.m
//  RON
//
//  Created by Benedict Cohen on 22/06/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "EMKRONStreamParser.h"


#import "EMKUTF8StreamScanner+RONTokenizer.h"
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



#pragma mark - token stream methods
-(EMKToken *)consumeNextToken {
    EMKToken *token = [self lookAtNextToken];
    if (token != nil) {
        [self.tokenQueue removeObjectAtIndex:0];
    }
        
//    EMKRONTypes type = token.type;
//    NSString *typeDescription = (type == EMKRONNumberType)        ? @"EMKRONNumberType" :
//    (type == EMKRONNullType)          ? @"EMKRONNullType" :
//    (type == EMKRONBooleanType)       ? @"EMKRONBooleanType" :
//    (type == EMKRONStringType)        ? @"EMKRONStringType" :
//    
//    //Structural types (i.e. not data, but explicitly stated in the input stream)
//    (type == EMKRONContextType)       ? @"EMKRONContextType" :
//    (type == EMKRONKeyStringType)     ? @"EMKRONKeyStringType" :
//    (type == EMKRONPairDelimiterType) ? @"EMKRONPairDelimiterType" :
//    
//    //Pseudo/implied types
//    (type == EMKRONArrayOpenType)     ? @"EMKRONArrayOpenType" :
//    (type == EMKRONArrayCloseType)    ? @"EMKRONArrayCloseType" :
//    (type == EMKRONObjectOpenType)    ? @"EMKRONObjectOpenType" :
//    (type == EMKRONObjectCloseType)   ? @"EMKRONObjectCloseType" :
//    @"INVALID TOKEN TYPE";
//    
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



-(BOOL)matchTokenStream:(EMKRONTypes)tokenStream, ... {
    va_list ap;    
    va_start(ap, tokenStream);
    EMKRONTypes tokenType = tokenStream;
    
    BOOL didMatch = NO;
    //Note that the exit condition is not related to tokenIndex. It's odd, but better than
    //having to prepare the for the next iteration of the loop inside the loop body
    for (NSInteger tokenIndex = 0; tokenType != EMKRONSentinalType; tokenIndex++, tokenType = va_arg(ap, EMKRONTypes)) {

        EMKToken *token = [self lookAtTokenAtIndex:tokenIndex];

        if (token == nil) goto exit;
        BOOL isTokenUninteresting = ((token.type & tokenType) == 0);
        if (isTokenUninteresting) goto exit;
    }
    
    didMatch = YES;
    
    exit:
    va_end(ap);
    return didMatch;
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
    if (![self matchTokenStream:EMKRONNumberType | EMKRONNullType | EMKRONBooleanType | EMKRONStringType, EMKRONSentinalType]) return nil;
    
    EMKToken *token = [self consumeNextToken];
    return token.value;
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
    if (![self matchTokenStream:EMKRONContextType, EMKRONKeyTypes, EMKRONPairDelimiterType, EMKRONSentinalType] &&
        ![self matchTokenStream:EMKRONContextType, EMKRONPairDelimiterType, EMKRONSentinalType]) return nil;

    
    //From now on we throw an exception if the stream doesn't make sense
    NSMutableDictionary *object = [NSMutableDictionary dictionary];

    EMKToken *referenceContextToken = [self lookAtNextToken];
    NSString *key;
    id value;
    while ([self parseObjectPairMatchingReferenceContext:referenceContextToken key:&key value:&value]) {
        if (value != nil) { //Watch out for empty pairs
            [object setObject:value forKey:key];
//            NSLog(@"setObjectForKey: %@", key);
        }
    }

    return [object copy];
}



-(BOOL)parseObjectPairMatchingReferenceContext:(EMKToken *)referenceContextToken key:(NSString *__autoreleasing *)outKey value:(id __autoreleasing *)outValue {
    //reset the output args
    *outKey = nil;
    *outValue = nil;
    
    //Check the context is valid
    EMKToken *contextToken = [self lookAtNextToken];
    switch (compareContextTokens(referenceContextToken, contextToken)) {
        case EMKRONReferenceContextTokenIsInvalid:
            //TODO: Figure out where the error is in the input stream.
            RAISE_PARSING_EXCEPTION(@"Invalid data in object at <???>");
            return NO;
            
        case EMKRONContextTokenIsInvalid:
            if (contextToken != nil) {
                //TODO: Figure out where the error is in the input stream.
                RAISE_PARSING_EXCEPTION(@"Invalid data in object at <???>");
            }
            return NO;
            
        case EMKRONContextTokenIsChild: {
            //TODO: Figure out where the error is in the input stream.
            RAISE_PARSING_EXCEPTION(@"Invalid indentation in object at <???>");
            return NO;

        }
            
        case EMKRONContextTokenIsParent:
            return NO;
            
        case EMKRONContextTokenIsSibling:
            [self consumeNextToken]; //the context is valid, consume it.
            break;
    }
    
    //Is it an empty pair?
    if ([self matchTokenStream:EMKRONPairDelimiterType, EMKRONSentinalType]) {
        [self consumeNextToken]; //consume the delimiter
        return YES;
    }
    
    //is the pair valid?
    if (![self matchTokenStream:EMKRONKeyTypes, EMKRONPairDelimiterType, EMKRONSentinalType]) {
        //TODO: Figure out where the error is in the input stream.
        RAISE_PARSING_EXCEPTION(@"Expected key or pair delimiter but found ??? at <???>");
        return NO;
    }
    
    EMKToken *keyToken = reinturpretTokenAsKey([self consumeNextToken]);
    [self consumeNextToken]; //consume the delimiter
    id value = [self parseValue];
    if (value == nil) {
        //TODO: Figure out where the error is in the input stream.
        RAISE_PARSING_EXCEPTION(@"No value for key at <???>");
        return NO;
    }
        
    //set the output
    *outKey = keyToken.value;
    *outValue = value;
    return YES;
}



-(NSArray *)parseArray {
    //check the stream is an array
    if (![self matchTokenStream:EMKRONContextType, EMKRONSentinalType]) return nil;
    
    //From now on we throw an exception if the stream doesn't make sense
    NSMutableArray *array = [NSMutableArray array];
    
    EMKToken *referenceContextToken = [self lookAtNextToken];
    id value;
    while ([self parseArrayElementMatchingReferenceContext:referenceContextToken value:&value]) {
        if (value != nil) { //Watch out for empty elements
            [array addObject:value];
        }
    }
    
    return [array copy];
}



-(BOOL)parseArrayElementMatchingReferenceContext:(EMKToken *)referenceContextToken value:(id __autoreleasing*)outValue {
    //reset the output arg
    *outValue = nil;
        
    //Check the context is valid
    EMKToken *contextToken = [self lookAtNextToken];
    switch (compareContextTokens(referenceContextToken, contextToken)) {
        case EMKRONReferenceContextTokenIsInvalid:
            //TODO: Figure out where the error is in the input stream.
            RAISE_PARSING_EXCEPTION(@"Invalid data in object at <???>");
            return NO;
            
        case EMKRONContextTokenIsInvalid:
            if (contextToken != nil) {
                //TODO: Figure out where the error is in the input stream.
                RAISE_PARSING_EXCEPTION(@"Invalid data in object at <???>");
            }
            return NO;
            
        case EMKRONContextTokenIsChild: {
            id collection = [self parseCollection];
            if (collection == nil) {
                //TODO: Figure out where the error is in the input stream.
                RAISE_PARSING_EXCEPTION(@"Invalid indentation in object at <???>");
                return NO;
            }
            *outValue = collection;
            return YES;
        }
            
        case EMKRONContextTokenIsParent:
            return NO;
            
        case EMKRONContextTokenIsSibling:
            [self consumeNextToken]; //the context is valid, consume it.
            break;
    }
    
    //If the next token is a parent context then this element is empty 
    EMKToken *possibleParentContext = [self lookAtNextToken];
    if (EMKRONContextTokenIsParent == compareContextTokens(contextToken, possibleParentContext)) return YES;

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
