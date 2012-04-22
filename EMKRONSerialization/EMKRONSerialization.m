//
//  EMKRONSerialization.m
//  RON
//
//  Created by Benedict Cohen on 06/04/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "EMKRONSerialization.h"

#pragma mark - token definitions
#define CONTEXT_TERMINAL_TOKEN @"*"
#define PAIR_DELIMITER_TOKEN  @":"
#define NULL_TOKEN @"null"
#define TRUE_TOKEN @"true"
#define YES_TOKEN @"yes"
#define FALSE_TOKEN @"false"
#define NO_TOKEN @"no"
#define NEW_LINE_TOKEN @"\n"
#define EMPTY_STRING_TOKEN @""
#define STRAIGHT_SINGLE_QUOTE_TOKEN @"'"
#define STRAIGHT_DOUBLE_QUOTE_TOKEN @"\"" 
#define OPENING_SMART_SINGLE_QUOTE_TOKEN @"\u2018"
#define CLOSING_SMART_SINGLE_QUOTE_TOKEN @"\u2019"
#define OPENING_SMART_DOUBLE_QUOTE_TOKEN @"\u201c"
#define CLOSING_SMART_DOUBLE_QUOTE_TOKEN @"\u201d"
#define OPENING_SQUARE_BRACE_TOKEN @"["
#define CLOSING_SQUARE_BRACE_TOKEN @"]"
#define OPENING_CURLY_BRACE_TOKEN @"{"
#define CLOSING_CURLY_BRACE_TOKEN @"}"
#define INLINE_COMMENT_TOKEN @"//"
#define OPENING_BLOCK_COMMENT_TOKEN @"/*"
#define CLOSING_BLOCK_COMMENT_TOKEN @"*/"


#pragma mark - Constants
NSString * const EMKRONErrorDomain = @"EMKRonErrorDomain";



#pragma mark - Private classes interfaces
@interface EMKRONParser : NSObject
@property(nonatomic, readonly) NSScanner *scanner;
@property(nonatomic, readonly) EMKRONSerializationOptions parseMode;

-(id)initWithRonString:(NSString *)ron parseMode:(EMKRONSerializationOptions)parseMode;
-(id)parse:(NSError *__autoreleasing *)error;
@end



@interface NSScanner (EMKDebugging)
-(NSString *)EMK_unscannedString;
@end



@interface EMKRONWriter : NSObject
@property(readonly, nonatomic) id object;
@property(readonly, nonatomic) NSMutableData *data;
@property(readwrite, nonatomic) NSUInteger contextSize;

-(id)initWithObject:(id)object;
-(NSData *)write:(NSError *__autoreleasing *)error;
@end



#pragma mark - EMKRONSerialization (facade)
@implementation EMKRONSerialization

+(id)RONObjectWithData:(NSData *)data options:(EMKRONSerializationOptions)options error:(NSError *__autoreleasing *)error;
{
    NSString *ron = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    EMKRONParser *parser = [[EMKRONParser alloc] initWithRonString:ron parseMode:EMKRONReadingStrictMode];
    
    return [parser parse:error];
}



+(NSData *)dataWithRONObject:(id)object options:(EMKRONSerializationOptions)options error:(NSError *__autoreleasing *)error
{
    EMKRONWriter *writer = [[EMKRONWriter alloc] initWithObject:object];
    
    return [writer write:error];    
}

@end



#pragma mark - NSScanner category
@implementation NSScanner (EMKDebugging)

-(NSString *)EMK_unscannedString
{
    return [[self string] substringFromIndex:[self scanLocation]];
}

@end



#pragma mark - strict parser class
@implementation EMKRONParser

#pragma mark properties
@synthesize scanner = _scanner;
@synthesize parseMode = _parseMode;



#pragma mark instance life cycle
-(id)initWithRonString:(NSString *)ron parseMode:(EMKRONSerializationOptions)parseMode
{
    self = [super init];
    if (self != nil)
    {
        _scanner = [NSScanner scannerWithString:ron];
        [_scanner setCharactersToBeSkipped:nil];

        _parseMode = parseMode;
    }
    return self;
}



#pragma mark document parsing
-(id)parse:(NSError *__autoreleasing *)error
{
    NSScanner *scanner = self.scanner;
    id value = nil;
    
    BOOL isDocumentEmpty = [scanner isAtEnd];
    if (!isDocumentEmpty) 
    {
        //a document should contain at most 1 top level value and it must be a collection
        @try 
        {
            value = [self parseCollection];
            if (value == nil)
            {
                NSError *__autoreleasing noRootCollectionError = nil;
                error = &noRootCollectionError;
                return nil;
            }
        }
        @catch (NSException *exception) 
        {
            NSError *__autoreleasing exceptionError = nil;
            error = &exceptionError;
            return nil;
        }
        
        //comments and whitespace are allowed after the root object
        [self consumeWhitespaceAndComments:YES];
        
        BOOL isDocumentParsingComplete = [scanner isAtEnd];
        if (!isDocumentParsingComplete)
        {
            NSError *__autoreleasing exceptionError = nil;
            error = &exceptionError;
            return nil;
        }
    }   
    
    return value;
}



#pragma mark value parsing
-(id)parseValue
{   
    id value = nil;
        
    value = [self parseScalar];
    if (value != nil) return value;

    value = [self parseCollection];
    if (value != nil) return value;
    
    return value;
}



-(id)parseScalar
{
    id value = nil;
    
    value = [self parseNumber];
    if (value != nil) return value;
    
    value = [self parseTrue];
    if (value != nil) return value;
    
    value = [self parseFalse];
    if (value != nil) return value;    
    
    value = [self parseNull];
    if (value != nil) return value;
    
    value = [self parseString];
    if (value != nil) return value;        
    
    return nil;
}



-(id)parseCollection
{
    id value = nil;
    
    value = [self parseObject];
    if (value != nil) return value;
    
    value = [self parseArray];
    if (value != nil) return value;    
            
    return value;
}



#pragma mark collection parsing

-(NSString *)parseContext
{
    //we assume that we're at the start of a line
    NSScanner *scanner = self.scanner;
    NSUInteger contextStartLocation = [scanner scanLocation];
    
    NSCharacterSet *whitespaceCharacters = [NSCharacterSet whitespaceCharacterSet];    
    
    BOOL isAtStartOfNewLine = YES;
    while (isAtStartOfNewLine)
    {
        //scan a valid context
        NSString *whitespace;
        BOOL didScanWhitespace = [scanner scanCharactersFromSet:whitespaceCharacters intoString:&whitespace];
        BOOL didScanBullet = [scanner scanString:CONTEXT_TERMINAL_TOKEN intoString:NULL];
        if (didScanBullet)
        {
            return (didScanWhitespace) ? [whitespace stringByAppendingString:CONTEXT_TERMINAL_TOKEN] : CONTEXT_TERMINAL_TOKEN;
        }
        
        //we didn't scan a valid context so advance through all comments and whitespace 
        //until the next new line
        [self consumeWhitespaceAndComments:NO];
        
        isAtStartOfNewLine = [scanner scanString:NEW_LINE_TOKEN intoString:NULL];
    }
    
    //we failed. reset.
    [scanner setScanLocation:contextStartLocation];
    return nil;
}



-(NSString *)lookAheadContext
{
    NSScanner *scanner = self.scanner;
    NSUInteger scanLocation = [scanner scanLocation];
    NSString *context = [self parseContext];
    [scanner setScanLocation:scanLocation];
    return context;
}



-(NSArray *)parseArray
{   
    NSScanner *scanner = self.scanner;    
    NSUInteger contextStartLocation = [scanner scanLocation];
    
    //get the collecton context (i.e. the first elements context)
    NSString *collectionContext = [self lookAheadContext];
    
    //if we couldn't get a context then we're not in a collection
    if (collectionContext == nil) return nil;
        
    //set up elements
    NSMutableArray *elements = [NSMutableArray array];        
    
    //loop until we encounter a parent context
    NSString *elementContext = [self parseContext];
    BOOL isElementFromAParentCollection = ([elementContext length] < [collectionContext length]);
    BOOL isElementFromAChildCollection = ([elementContext length] > [collectionContext length]);    
    while (!isElementFromAParentCollection) 
    {        
        //TODO: We need to check that we're not parsing an object
        
        id element = (isElementFromAChildCollection) ? [self parseCollection] : [self parseScalar];        
        //store the element if it exists
        //(the context may be there simple to a pop subcollection)
        if (element != nil) [elements addObject:element];
        
        //prep for the next element
        //TODO: What state is the scanner in once it leaves parseCollection and parseScalar?
        //TODO: What state do we want it in?                
        contextStartLocation = [scanner scanLocation];
        elementContext = [self parseContext];
        isElementFromAParentCollection = ([elementContext length] < [collectionContext length]);
        isElementFromAChildCollection = ([elementContext length] > [collectionContext length]);    

        //reset the scanner so the child/parent has access to the current context
        if (isElementFromAChildCollection || isElementFromAParentCollection) [scanner setScanLocation:contextStartLocation];
    }    
    
    return elements;
}



-(NSDictionary *)parseObject
{
    NSScanner *scanner = self.scanner;    
    NSUInteger contextStartLocation = [scanner scanLocation];
    
    //get the collecton context (i.e. the first elements context)
    NSString *collectionContext = [self lookAheadContext];
    
    //if we couldn't get a context then we're not in a collection
    if (collectionContext == nil) return nil;
    
    //set up pairs
    NSMutableDictionary *members = [NSMutableDictionary dictionary];        
    BOOL didParseFirstMemeber = NO;
    
    //loop until we encounter a parent context
    NSString *memberContext = [self parseContext];
    BOOL isMemberFromAParentCollection = ([memberContext length] < [collectionContext length]);
    BOOL isMemberFromAChildCollection  = ([memberContext length] > [collectionContext length]);    
    while (!isMemberFromAParentCollection) 
    {   
        NSString *key = [self parseKey];
        NSString *pairDelimiter = [self parsePairDelimiter];
        BOOL isInvalid = (pairDelimiter == nil);
        if (isInvalid)
        {
            if (didParseFirstMemeber)
            {
                //if we've parsed at least 1 member then we must be an object.
                //Each object must contain a pair delimiter
                NSString *reason = [NSString stringWithFormat:@"Member does not contain a ':' between key and value at %ul.", [scanner scanLocation]];
                [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
                return nil;
            }
            else
            {
                //we're not an object, but we could be an array so simply return nil
                [scanner setScanLocation:contextStartLocation];
                return nil;
            }
        }
        
        BOOL isNonEmptyMember = (key != nil);
        if (isNonEmptyMember)
        {
            //See if the value has a context (which means it's a collection)
            NSUInteger valueContextStartLocation = [scanner scanLocation];
            NSString *valueContext = [self parseContext];
            [scanner setScanLocation:valueContextStartLocation];
            
            //if the value is a collection then check that it's context is valid
            BOOL isValueACollection = (valueContext != nil);
            if (isValueACollection)
            {
                //A sub-collection must have a larger context then the current collection
                BOOL isValueContextValid = [valueContext length] > [collectionContext length];
                if (!isValueContextValid)
                {
                    NSString *reason = [NSString stringWithFormat:@"Collection at %ul has a smaller context than its parent.", [scanner scanLocation]];
                    [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
                    return nil;
                }
            }
            
            //get the value
            id value = (isValueACollection) ? [self parseCollection] : [self parseScalar];
            if (value == nil) 
            {
                NSString *reason = [NSString stringWithFormat:@"Member at %ul does not have a value.", [scanner scanLocation]];
                [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
                return nil;
            }
            
            //store the value
            [members setObject:value forKey:key];            
        }
        
        //Once we have parsed 1 member we know that the collection is certainly a object and not an array
        //we can thus improve subsequent error checks.
        didParseFirstMemeber = YES;
        
        //prep for the next member
        //TODO: What state is the scanner in once it leaves parseCollection and parseScalar?
        //TODO: What state do we want it in?                
        //At the moment it just works, but we should now why that is.
        contextStartLocation = [scanner scanLocation];
        memberContext = [self parseContext];
        isMemberFromAParentCollection = ([memberContext length] < [collectionContext length]);
        isMemberFromAChildCollection = ([memberContext length] > [collectionContext length]);    
        
        //reset the scanner so the child/parent has access to the current context
        if (isMemberFromAChildCollection || isMemberFromAParentCollection) [scanner setScanLocation:contextStartLocation];
    }    
    
    return members;
}



-(NSString *)parseKey
{
    //first try and get the key as a standard string
    NSString *key = [self parseStrictString];
    if (key != nil) return key;
    
    //store location
    NSScanner *scanner = self.scanner;
    NSUInteger startLocation = [scanner scanLocation];
    [self consumeWhitespaceAndComments:YES];
    
    //scan all characters up to the collection delimiters
    NSString *permissiveKey;
    //The compiler won't concat to CONTEXT_TERMINAL_TOKEN & PAIR_DELIMITER_TOKEN in characterSetWithCharactersInString
    //This may be the correct compiler behaviour, but I though it would concat them.
    NSString *collectionDelimitersString = [NSString stringWithFormat:@"%@%@", CONTEXT_TERMINAL_TOKEN, PAIR_DELIMITER_TOKEN];
    NSCharacterSet *collectionDelimiters = [NSCharacterSet characterSetWithCharactersInString:collectionDelimitersString];
    BOOL didScanPermissiveKey = [scanner scanUpToCharactersFromSet:collectionDelimiters intoString:&permissiveKey];
    
    if (didScanPermissiveKey)
    {
        NSString *trimmedPermissiveKey = [permissiveKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if([trimmedPermissiveKey length] > 0) return trimmedPermissiveKey;
    }
    
    //we failed. reset.
    [scanner setScanLocation:startLocation];
    return nil;
}



-(NSString *)parsePairDelimiter
{
    NSScanner *scanner = self.scanner;
    NSUInteger startLocation = [scanner scanLocation];
    [self consumeWhitespaceAndComments:YES];
    
    BOOL didScanPair = [scanner scanString:PAIR_DELIMITER_TOKEN intoString:NULL];
    
    if (didScanPair) return PAIR_DELIMITER_TOKEN;
    
    //we've failed. reset
    [scanner setScanLocation:startLocation];
    return nil;
}



#pragma mark scalar value parsing (these methods consume leading white space and comments)
-(NSNumber *)parseNumber
{
    NSScanner *scanner = self.scanner;
    NSUInteger startLocation = scanner.scanLocation;    
    [self consumeWhitespaceAndComments:YES];
        
    double result;
    BOOL didScanNumber = [scanner scanDouble:&result];
    
    if (didScanNumber) return [NSNumber numberWithDouble:result];
    
    //we've failed. reset
    [scanner setScanLocation:startLocation];
    return nil;    
}



-(NSNumber *)parseTrue
{
    NSScanner *scanner = self.scanner;
    NSUInteger startLocation = scanner.scanLocation;    
    [self consumeWhitespaceAndComments:YES];
    
    BOOL didScanBool = [scanner scanString:YES_TOKEN intoString:NULL] || [scanner scanString:TRUE_TOKEN intoString:NULL];
    
    if (didScanBool) return [NSNumber numberWithBool:YES];
    
    //we've failed. reset
    [scanner setScanLocation:startLocation];
    return nil;    
}



-(NSNumber *)parseFalse
{
    NSScanner *scanner = self.scanner;
    NSUInteger startLocation = scanner.scanLocation;    
    [self consumeWhitespaceAndComments:YES];
    
    BOOL didScanBool = [scanner scanString:NO_TOKEN intoString:NULL] || [scanner scanString:FALSE_TOKEN intoString:NULL];
    
    if (didScanBool) return [NSNumber numberWithBool:NO];
    
    //we've failed. reset
    [scanner setScanLocation:startLocation];
    return nil;    
}



-(NSNull *)parseNull
{
    NSScanner *scanner = self.scanner;
    NSUInteger startLocation = scanner.scanLocation;    
    [self consumeWhitespaceAndComments:YES];
    
    BOOL didScanNull = [scanner scanString:NULL_TOKEN intoString:NULL];
    
    if (didScanNull) return [NSNull null];
    
    //we've failed. reset
    [scanner setScanLocation:startLocation];
    return nil;    
}



-(NSString *)parseString
{
    NSString *string = nil;
    
    string = [self parseStrictString];
    if (string != nil) return string;
    
    if (self.parseMode != EMKRONReadingPermissiveMode) return nil;
    
    string = [self parsePermissiveString];
    if (string != nil) return string;
    
    return nil;
}



-(NSString *)parseStrictString
{
    NSScanner *scanner = self.scanner;
    NSUInteger startLocation = scanner.scanLocation;    
    [self consumeWhitespaceAndComments:YES];    
    
    //vars for keeping track of the result
    __block NSString *result = nil;
    BOOL didScanString = NO;    

    //1. Parse fixed delimited string
    BOOL (^scanFixedDelimitedString)(NSString *) = ^(NSString *delimiter)
    {
        BOOL didScanOpenDelimiter = [scanner scanString:delimiter intoString:NULL];
        if (didScanOpenDelimiter)
        {
            BOOL didScanFixedDelimitedString = [scanner scanUpToString:delimiter intoString:&result];
            BOOL didScanCloseDelimiter = [scanner scanString:delimiter intoString:NULL];
            didScanCloseDelimiter = didScanCloseDelimiter; //silence the compiler warning
            //TODO: if (!didScanCloseQuote) FATAL ERROR!
            
            if (!didScanFixedDelimitedString) result = EMPTY_STRING_TOKEN;
        }

        return didScanOpenDelimiter;
    };
    
    didScanString = scanFixedDelimitedString(STRAIGHT_SINGLE_QUOTE_TOKEN);
    if (didScanString) return result;
    
    didScanString = scanFixedDelimitedString(STRAIGHT_DOUBLE_QUOTE_TOKEN);
    if (didScanString) return result;
    
    //2. Parse balanced string
    BOOL (^scanBalancedDelimitedString)(NSString *, NSString *) = ^(NSString *openingDelimiter, NSString *closingDelimiter)
    {
        BOOL didScanInitialOpenDelimitter = [scanner scanString:openingDelimiter intoString:NULL];
        if (didScanInitialOpenDelimitter)
        {
            NSMutableString *balanceDelimitedResult = [NSMutableString new];
            NSInteger delimiterStack = 1;
            NSCharacterSet *delimiters = [NSCharacterSet characterSetWithCharactersInString:[openingDelimiter stringByAppendingString:closingDelimiter]];
            
            while (delimiterStack > 0) 
            {
                BOOL didScanOpenDelimiter = [scanner scanString:openingDelimiter intoString:NULL];
                if (didScanOpenDelimiter)
                {
                    delimiterStack++;                    
                    [balanceDelimitedResult appendString:openingDelimiter];
                    continue;
                }

                BOOL didScanCloseDelimiter = [scanner scanString:closingDelimiter intoString:NULL];
                if (didScanCloseDelimiter)
                {
                    delimiterStack--;                    
                    if (delimiterStack > 0)[balanceDelimitedResult appendString:closingDelimiter];
                    continue;
                }
                
                NSString *fragment;                
                BOOL didScanFragment = [scanner scanUpToCharactersFromSet:delimiters intoString:&fragment];
                if (didScanFragment)
                {
                    [balanceDelimitedResult appendString:fragment];
                    continue;
                }
            }
            
            result = [balanceDelimitedResult copy];
        }
        
        return didScanInitialOpenDelimitter;
    };
    
    didScanString = scanBalancedDelimitedString(OPENING_SMART_SINGLE_QUOTE_TOKEN, CLOSING_SMART_SINGLE_QUOTE_TOKEN);
    if (didScanString) return result;

    didScanString = scanBalancedDelimitedString(OPENING_SMART_DOUBLE_QUOTE_TOKEN, CLOSING_SMART_DOUBLE_QUOTE_TOKEN);
    if (didScanString) return result;

    //3.Parse dynamic delimited string
    BOOL (^scanDynamicDelimitedString)(NSString *, NSString *) = ^(NSString *openDelimiter, NSString *closeDelimiter)
    {
        BOOL didScanInitalOpeningDelimiter = [scanner scanString:openDelimiter intoString:NULL];
        if (didScanInitalOpeningDelimiter)
        {
            NSMutableString *composedCloseDelimiter = [closeDelimiter mutableCopy];
            while ([scanner scanString:openDelimiter intoString:NULL])
            {
                [composedCloseDelimiter appendString:closeDelimiter];
            }
            
            BOOL didScanDynamicallyDelimitedString = [scanner scanUpToString:composedCloseDelimiter intoString:&result];
            BOOL didScanComposedClosedDelimiter = [scanner scanString:composedCloseDelimiter intoString:NULL];
            didScanComposedClosedDelimiter = didScanComposedClosedDelimiter; //silent compiler warning   
            //TODO: if (!didScanCloseQuote) FATAL ERROR!
            if (!didScanDynamicallyDelimitedString) result = EMPTY_STRING_TOKEN;
        }
        
        return didScanInitalOpeningDelimiter;
    };
    
    didScanString = scanDynamicDelimitedString(OPENING_SQUARE_BRACE_TOKEN, CLOSING_SQUARE_BRACE_TOKEN);
    if (didScanString) return result;

    didScanString = scanDynamicDelimitedString(OPENING_CURLY_BRACE_TOKEN, CLOSING_CURLY_BRACE_TOKEN);
    if (didScanString) return result;
    
    //we failed. reset.
    [scanner setScanLocation:startLocation];
    return result;
}



-(NSString *)parsePermissiveString
{
    [self consumeWhitespaceAndComments:YES];    
    
    NSScanner *scanner = self.scanner;
    NSString *result;
    BOOL didScanString = [scanner scanUpToString:NEW_LINE_TOKEN intoString:&result];
    [scanner scanString:NEW_LINE_TOKEN intoString:NULL];
    
    return (didScanString) ? result : EMPTY_STRING_TOKEN;    
}



#pragma mark consuming non-data characters
-(void)consumeWhitespaceAndComments:(BOOL)shouldConsumeNewline
{
    //the work is done in the conditions
    while ([self consumeWhitespace:shouldConsumeNewline] || [self consumeComment]);
}



-(BOOL)consumeWhitespace:(BOOL)shouldConsumeNewline
{
    NSCharacterSet *whitespace = (shouldConsumeNewline) ? [NSCharacterSet whitespaceAndNewlineCharacterSet] : [NSCharacterSet whitespaceCharacterSet];
    return [self.scanner scanCharactersFromSet:whitespace intoString:NULL];
}



-(BOOL)consumeComment
{
    NSScanner *scanner = self.scanner;
    NSUInteger startLocation = [scanner scanLocation];
    
    //scan for inline comments
    BOOL didScanInlineComment = [scanner scanString:INLINE_COMMENT_TOKEN intoString:NULL];
    if (didScanInlineComment) 
    {
        [scanner scanUpToString:NEW_LINE_TOKEN intoString:NULL];
        return YES;
    }
    
    //scan for block comments
    BOOL didScanCommentOpening = [scanner scanString:OPENING_BLOCK_COMMENT_TOKEN intoString:NULL];
    if (!didScanCommentOpening) return NO;
    [scanner scanUpToString:CLOSING_BLOCK_COMMENT_TOKEN intoString:NULL];
    BOOL didScanCommentClosing = [scanner scanString:CLOSING_BLOCK_COMMENT_TOKEN intoString:NULL];    
    if (!didScanCommentClosing)
    {
        NSString *reason = [NSString stringWithFormat:@"Comment starting at %ul does not close.", startLocation];
        [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
        return NO;        
    }
    
    return YES;
}

@end



#pragma mark - EMKRONWriter
@implementation EMKRONWriter
{
    NSMutableString *_string;
}
#pragma mark properties
@synthesize object = _object;
@synthesize data = _data;
@synthesize contextSize = _contextSize;



#pragma mark instance life cycle
-(id)initWithObject:(id)object
{
    self = [super init];
    if (self != nil)
    {
        _object = object;
        _data = [NSMutableData data];
        _string = [NSMutableString new];
    }
    return self;
}



#pragma mark context
-(void)pushContext
{
    self.contextSize = self.contextSize + 4;
}



-(void)popContext
{
    self.contextSize = self.contextSize - 4;
}



-(NSString *)context
{
    NSString *format = [NSString stringWithFormat:@"\n%%%us", self.contextSize];
    NSString *result = [NSString stringWithFormat:format, CONTEXT_TERMINAL_TOKEN];
    //    NSLog(@"'%@'", result);
    return result;
}



#pragma mark append to data
-(void)appendString:(NSString *)string
{
//    NSLog(@"Appending string: %@", string);
    [_string appendString:string];
    [self.data appendData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}
 


#pragma mark writing
-(NSData *)write:(NSError *__autoreleasing *)error
{
    BOOL didWriteCollection = NO;    
    @try 
    {
        didWriteCollection = [self writeCollection:self.object];
    }
    @catch (NSException *exception) 
    {
        NSError *__autoreleasing exceptionError = nil;
        error = &exceptionError;
        return nil;
    }
    
    if (!didWriteCollection) 
    {
        NSError *__autoreleasing objectNotACollectionError = nil;
        error = &objectNotACollectionError;
        return nil;        
    }
    
    //return an immutable copy
    return [self.data copy];
}



-(BOOL)writeValue:(id)value
{
    BOOL didWriteValue = NO;
    
    didWriteValue = [self writeScalar:value];
    if (didWriteValue) return YES;
    
    didWriteValue = [self writeCollection:value];
    if (didWriteValue) return YES;    
    
    NSString *reason = [NSString stringWithFormat:@"Could not write object of type %@", [value class]];
    [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
    return NO;
}



-(BOOL)writeScalar:(id)scalar
{
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



-(BOOL)writeCollection:(id)collection
{
    BOOL didWriteCollection = NO;
    
    didWriteCollection = [self writeObject:collection];
    if (didWriteCollection) return YES;
    
    didWriteCollection = [self writeArray:collection];
    if (didWriteCollection) return YES;
    
    return NO;
}



#pragma mark collection writing
-(BOOL)writeObject:(NSDictionary *)object
{
    if (![object isKindOfClass:[NSDictionary class]]) return NO;
    
    NSString *context = [self context];
    
    __block NSUInteger elementCount = 0;
    __block BOOL wasPreviousElementACollection = NO;    
    __block BOOL didWriteFirstElement = NO;
    
    [object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) 
    {
        //write context
        [self appendString:context];
        
        //write key
        [self writeString:key];
        
        //write split
        [self appendString:PAIR_DELIMITER_TOKEN];
        
        
        //write value
        BOOL didWriteValue = [self writeScalar:value];
        if (didWriteValue)
        {
            wasPreviousElementACollection = NO;
        }
        else
        {   
            [self pushContext];
            didWriteValue = [self writeCollection:value];            
            if (didWriteValue) wasPreviousElementACollection = YES;            
            [self popContext];
        }
        
        if (!didWriteValue) 
        {
            NSString *reason = [NSString stringWithFormat:@"Could not write object of type %@", [value class]];
            [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
            return;            
        }
        else
        {
            didWriteFirstElement = YES;
        }
        
        elementCount++;
    }];
    
    //there has to be some artifact that this array existed!
    if (!didWriteFirstElement)
    {
        [self appendString:context];    
        [self appendString:PAIR_DELIMITER_TOKEN];            
    }
    
    return YES;    
}



-(BOOL)writeArray:(NSArray *)array
{
    if (![array isKindOfClass:[NSArray class]]) return NO;
    
    NSString *context = [self context];
    
    NSUInteger elementCount = 0;
    BOOL wasPreviousElementACollection = NO;    
    
    for (id value in array) 
    {
        [self appendString:context];
        
        BOOL didWriteValue = [self writeScalar:value];
        if (didWriteValue)
        {
            wasPreviousElementACollection = NO;
        }
        else
        {           
            [self pushContext];
            didWriteValue = [self writeCollection:value];            
            if (didWriteValue) wasPreviousElementACollection = YES;            
            [self popContext];
        }
        
        if (!didWriteValue) 
        {
            NSString *reason = [NSString stringWithFormat:@"Could not write object of type %@", [value class]];
            [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
            return NO;            
        }
        
        elementCount++;
    }
    
    //there has to be some artifact that this array existed!
    BOOL didWriteFirstElement = elementCount > 0;
    if (!didWriteFirstElement)
    {
        [self appendString:context];    
    }
    
    return YES;    
}



#pragma mark scalar writing
-(BOOL)writeNumber:(NSNumber *)number
{
    if (![number isKindOfClass:[NSNumber class]]) return NO;
    
    [self appendString:[number description]];
    return YES;
}



-(BOOL)writeTrue:(NSNumber *)number
{
    if (![number isKindOfClass:[NSNumber class]]) return NO;
    
    //TODO: is this best way to determine if the value is a bool?
    if (number == [NSNumber numberWithBool:YES]) 
    {
        [self appendString:TRUE_TOKEN];
        return YES;
    }
    
    return NO;
}



-(BOOL)writeFalse:(NSNumber *)number
{
    if (![number isKindOfClass:[NSNumber class]]) return NO;
    
    //TODO: is this best way to determine if the value is a bool?
    if (number == [NSNumber numberWithBool:NO]) 
    {
        [self appendString:FALSE_TOKEN];
        return YES;        
    }
    
    return NO;
}



-(BOOL)writeNull:(NSNumber *)null
{
    if (![null isKindOfClass:[NSNull class]]) return NO;
    
    [self appendString:NULL_TOKEN];
    return YES;        
}



-(BOOL)writeString:(NSString *)string
{
    if (![string isKindOfClass:[NSString class]]) return NO;
    
    BOOL (^doesStringContainSubstringFromArray)(NSArray *) = ^(NSArray *subStrings)
    {
        for (NSString *substring in subStrings)
        {
            NSRange substringRange = [string rangeOfString:substring];
            if (substringRange.location != NSNotFound) return YES;
        }
        return NO;  
    };
    
    NSArray *square  = [NSArray arrayWithObjects: OPENING_SQUARE_BRACE_TOKEN, CLOSING_SQUARE_BRACE_TOKEN, nil];
    NSArray *curly   = [NSArray arrayWithObjects: OPENING_CURLY_BRACE_TOKEN, CLOSING_CURLY_BRACE_TOKEN, nil];
    NSArray *pairs = [NSArray arrayWithObjects:square, curly, nil];
    
    NSUInteger quoteLength = 1;
    while (true)
    {
        for (NSArray *pair in pairs)
        {
            NSString *openDelimiter  = [pair objectAtIndex:0];
            NSString *closeDelimiter = [pair lastObject];            
            
            NSMutableString *openComposedDelimiter = [openDelimiter mutableCopy];
            NSMutableString *closeComposedDelimiter = [closeDelimiter mutableCopy];
            for (NSInteger i = 1; i < quoteLength; i++)
            {
                [openComposedDelimiter appendString:openDelimiter];
                [closeComposedDelimiter appendString:closeDelimiter];
            }
            
            NSArray *delimiters = [NSArray arrayWithObjects:openComposedDelimiter, closeComposedDelimiter, nil];
            
            if (!doesStringContainSubstringFromArray(delimiters))
            {
                NSString *delimittedString = [NSString stringWithFormat:@"%@%@%@", openComposedDelimiter, string, closeComposedDelimiter];
                [self appendString:delimittedString];
                return YES;
            }
        }
        quoteLength++;
    }
    
    return NO;
}

@end
