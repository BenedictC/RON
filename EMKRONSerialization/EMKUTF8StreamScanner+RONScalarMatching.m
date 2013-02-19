//
//  EMKUTF8StreamScanner+RONScalarMatching.m
//  RON
//
//  Created by Benedict Cohen on 07/07/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "EMKUTF8StreamScanner+RONScalarMatching.h"

#import "EMKRONTokensAndTypes.h"
#import "EMKToken.h"



@implementation EMKUTF8StreamScanner (RONScalarMatching)

#pragma mark - white space handling
/**
 * Description
 *
 * @see
 *
 * @param
 * @param
 * @return
 */
-(BOOL)lookAheadForWhitespaceOrEndOfStream {
    return [self lookAheadForCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] || [self isAtEnd];
}



/**
 * Description
 *
 * @see 
 *
 * @param
 * @param 
 * @return
 */
-(NSString *)scanWhitespaceAndComments:(BOOL)shouldConsumeNewline {

    NSString *allWhitespace = @"";
    BOOL didScan = NO;
    do {
        didScan = NO;
        NSString *whitespace = [self scanWhitespace:shouldConsumeNewline];
        didScan = (whitespace != nil);
        if (didScan) {
            allWhitespace = [allWhitespace stringByAppendingString:whitespace];
        }
        
        NSString *comment = [self scanComment];
        didScan = didScan || comment != nil;
        
    } while (didScan);
    
    return allWhitespace;
}



/**
 * Description
 *
 * @see 
 *
 * @param
 * @param 
 * @return
 */
-(NSString *)scanWhitespace:(BOOL)shouldConsumeNewline {
    NSCharacterSet *whitespaceCharacters = (shouldConsumeNewline) ? [NSCharacterSet whitespaceAndNewlineCharacterSet] : [NSCharacterSet whitespaceCharacterSet];
    NSString *scannedWhitespace;
    BOOL didScan = [self scanCharactersFromSet:whitespaceCharacters intoString:&scannedWhitespace];
    
    return (didScan) ? scannedWhitespace : nil;
}



/**
 * Description
 *
 * @see 
 *
 * @param
 * @param 
 * @return
 */
-(NSString *)scanComment {
    //scan for inline comments
    BOOL didScanInlineComment = [self scanString:INLINE_COMMENT_TOKEN caseInsensitive:YES intoString:NULL];
    if (didScanInlineComment) {        
        NSString *commentText;
        BOOL didScan = [self scanUpToString:NEW_LINE_TOKEN caseInsensitive:YES intoString:&commentText];
        return (didScan) ? [INLINE_COMMENT_TOKEN stringByAppendingString:commentText] : INLINE_COMMENT_TOKEN;
    }
    
    //scan for block comments
    BOOL didScanCommentOpening = [self scanString:OPENING_BLOCK_COMMENT_TOKEN caseInsensitive:YES intoString:NULL];
    if (!didScanCommentOpening) return nil;
    
    NSString *commentText;
    [self scanUpToString:CLOSING_BLOCK_COMMENT_TOKEN caseInsensitive:YES intoString:&commentText];
    BOOL didScanCommentClosing = [self scanString:CLOSING_BLOCK_COMMENT_TOKEN caseInsensitive:YES intoString:NULL];    
    if (!didScanCommentClosing) {
        NSString *reason = [NSString stringWithFormat:@"Unclosed comment starting at ???"];
        [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
        return nil;
    }
    
    return [NSString stringWithFormat:@"%@%@%@", OPENING_BLOCK_COMMENT_TOKEN, commentText, CLOSING_BLOCK_COMMENT_TOKEN];
}



#pragma mark - bool types
/**
 * Description
 *
 * @see
 *
 * @param
 * @param
 * @return
 */
-(EMKToken *)scanBoolean {
    id result = [self scanTrue];
    if (result != nil) return result;
    
    return [self scanFalse];
}



/**
 * Description
 *
 * @see 
 *
 * @param
 * @param 
 * @return
 */
-(EMKToken *)scanTrue {
    NSString *whitespace = [self scanWhitespaceAndComments:YES];
    NSString *scannedString;
    if (   [self scanString:TRUE_TOKEN caseInsensitive:YES intoString:&scannedString]
        || [self scanString:YES_TOKEN caseInsensitive:YES intoString:&scannedString]) {
        
        if ([self lookAheadForWhitespaceOrEndOfStream]) {
            return [EMKToken tokenWithType:EMKRONBooleanType value:[NSNumber numberWithBool:YES] sourceText:scannedString];
        } else {
            //put back the scanned string because it was a false-positive
            [self unread:scannedString];
        }
    }
    
    [self unread:whitespace];
    
    return nil;
}



/**
 * Description
 *
 * @see 
 *
 * @param
 * @param
 * @return
 */
-(EMKToken *)scanFalse {
    NSString *whitespace = [self scanWhitespaceAndComments:YES];    
    NSString *scannedString;
    if (   [self scanString:FALSE_TOKEN caseInsensitive:YES intoString:&scannedString]
        || [self scanString:NO_TOKEN caseInsensitive:YES intoString:&scannedString]) {
     
        if ([self lookAheadForWhitespaceOrEndOfStream]) {
            return [EMKToken tokenWithType:EMKRONBooleanType value:[NSNumber numberWithBool:NO] sourceText:nil];
        } else {
            //put back the scanned string because it was a false-positive
            [self unread:scannedString];
        }
    }
    
    [self unread:whitespace];
    
    return nil;    
}



#pragma mark - null type
/**
 * Description
 *
 * @see 
 *
 * @param
 * @param 
 * @return
 */
-(EMKToken *)scanNull {
    NSString *whitespace = [self scanWhitespaceAndComments:YES];    
    NSString *scannedString;
    
    if ([self scanString:NULL_TOKEN caseInsensitive:YES intoString:&scannedString]) {
        
        if ([self lookAheadForWhitespaceOrEndOfStream]) {
            return [EMKToken tokenWithType:EMKRONNullType value:[NSNull null]  sourceText:scannedString];
        } else {
            //put back the scanned string because it was a false-positive
            [self unread:scannedString];
        }
    }
    
    [self unread:whitespace];
    
    return nil;    
}



#pragma mark - string type
/**
 * Description
 *
 * @see 
 *
 * @param
 * @param 
 * @return
 */
-(EMKToken *)scanStrictString {
    //vars for keeping track of the result
    NSString *whitespace = [self scanWhitespaceAndComments:YES];
    EMKToken *result = nil;
    
    result = [self scanFixedDelimitedString];
    if (result != nil) return result;
    
    result = [self scanBalancedDelimitedString];
    if (result != nil)  return result;    
    
    result = [self scanDynamicDelimitedString];
    if (result != nil)  return result;        
    
    [self unread:whitespace];
    return nil;
}
 


/**
 * Description
 *
 * @see 
 *
 * @param
 * @param 
 * @return
 */
-(EMKToken *)scanFixedDelimitedString {
    __block NSString *result;
    BOOL (^scanFixedDelimitedString)(NSString *) = ^(NSString *delimiter) {
        BOOL didScanOpenDelimiter = [self scanString:delimiter caseInsensitive:YES intoString:NULL];
        if (didScanOpenDelimiter) {
            BOOL didScanFixedDelimitedString = [self scanUpToString:delimiter caseInsensitive:YES intoString:&result];
            BOOL didScanCloseDelimiter = [self scanString:delimiter caseInsensitive:YES intoString:NULL];
            didScanCloseDelimiter = didScanCloseDelimiter; //silence the compiler warning
            //TODO: if (!didScanCloseQuote) FATAL ERROR!
            
            if (!didScanFixedDelimitedString) result = EMPTY_STRING_TOKEN;
        }
        
        return didScanOpenDelimiter;
    };
    
    BOOL didScanString = scanFixedDelimitedString(STRAIGHT_SINGLE_QUOTE_TOKEN);
    if (didScanString) return [EMKToken tokenWithType:EMKRONStringType value:result sourceText:result]; //TODO: Should sourceText include the quotes?
    
    didScanString = scanFixedDelimitedString(STRAIGHT_DOUBLE_QUOTE_TOKEN);
    if (didScanString) return [EMKToken tokenWithType:EMKRONStringType value:result sourceText:result]; //TODO: Should sourceText include the quotes?

    return nil;
}
 
    

/**
 * Description
 *
 * @see 
 *
 * @param
 * @param 
 * @return
 */
-(EMKToken *)scanBalancedDelimitedString {
    __block NSString *result;
    BOOL (^scanBalancedDelimitedString)(NSString *, NSString *) = ^(NSString *openingDelimiter, NSString *closingDelimiter) {
        BOOL didScanInitialOpenDelimitter = [self scanString:openingDelimiter caseInsensitive:YES intoString:NULL];
        if (didScanInitialOpenDelimitter) {
            NSMutableString *balanceDelimitedResult = [NSMutableString new];
            NSInteger delimiterStack = 1;
            NSCharacterSet *delimiters = [NSCharacterSet characterSetWithCharactersInString:[openingDelimiter stringByAppendingString:closingDelimiter]];
            
            while (delimiterStack > 0) {
                BOOL didScanOpenDelimiter = [self scanString:openingDelimiter caseInsensitive:YES intoString:NULL];
                if (didScanOpenDelimiter) {
                    delimiterStack++;                    
                    [balanceDelimitedResult appendString:openingDelimiter];
                    continue;
                }
                
                BOOL didScanCloseDelimiter = [self scanString:closingDelimiter caseInsensitive:YES intoString:NULL];
                if (didScanCloseDelimiter) {
                    delimiterStack--;                    
                    if (delimiterStack > 0)[balanceDelimitedResult appendString:closingDelimiter];
                    continue;
                }
                
                NSString *fragment;                
                BOOL didScanFragment = [self scanUpToCharacterFromSet:delimiters intoString:&fragment];
                if (didScanFragment) {
                    [balanceDelimitedResult appendString:fragment];
                    continue;
                }
            }
            
            result = [balanceDelimitedResult copy];
        }
        
        return didScanInitialOpenDelimitter;
    };
    
    BOOL didScanString = scanBalancedDelimitedString(OPENING_SMART_SINGLE_QUOTE_TOKEN, CLOSING_SMART_SINGLE_QUOTE_TOKEN);
    if (didScanString) return [EMKToken tokenWithType:EMKRONStringType value:result sourceText:result]; //TODO: Should sourceText include the quotes?
    
    didScanString = scanBalancedDelimitedString(OPENING_SMART_DOUBLE_QUOTE_TOKEN, CLOSING_SMART_DOUBLE_QUOTE_TOKEN);
    if (didScanString) return [EMKToken tokenWithType:EMKRONStringType value:result sourceText:result]; //TODO: Should sourceText include the quotes?
    
    return nil;
}
    
    

/**
 * Description
 *
 * @see 
 *
 * @param
 * @param 
 * @return
 */
-(EMKToken *)scanDynamicDelimitedString {
    __block NSString *result;
    BOOL (^scanDynamicDelimitedString)(NSString *, NSString *) = ^(NSString *openDelimiter, NSString *closeDelimiter) {
        NSString *openingDelimiterSequence;
        BOOL didScanOpeningDelimiterSequence = [self scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:openDelimiter] intoString:&openingDelimiterSequence];
        if (didScanOpeningDelimiterSequence) {
            //create the closing delimiter sequence
            NSMutableString *closingDelimiterSequence = [closeDelimiter mutableCopy];
            for (int i = 1; i < [openingDelimiterSequence length]; i++) [closingDelimiterSequence appendString:closeDelimiter];
            
            //scan past the closingDelimiterSequence (there may still be closing delimiters tokens after the closing sequence)
            BOOL didScanDynamicallyDelimitedString = [self scanUpToString:closingDelimiterSequence caseInsensitive:NO intoString:&result];
            BOOL didScanComposedClosedDelimiter = [self scanString:closingDelimiterSequence caseInsensitive:NO intoString:NULL];
            didScanComposedClosedDelimiter = didScanComposedClosedDelimiter; //silent compiler warning   
            
            //append any remaing close delimiter tokens on to the result
            while ([self scanString:closeDelimiter caseInsensitive:YES intoString:NULL]) result = [result stringByAppendingString:closeDelimiter];
            
            //TODO: if (!didScanCloseQuote) FATAL ERROR!
            if (!didScanDynamicallyDelimitedString) result = EMPTY_STRING_TOKEN;
        }
        
        return didScanOpeningDelimiterSequence;
    };
    
    BOOL didScanString = scanDynamicDelimitedString(OPENING_SQUARE_BRACE_TOKEN, CLOSING_SQUARE_BRACE_TOKEN);
    if (didScanString) return [EMKToken tokenWithType:EMKRONStringType value:result sourceText:result]; //TODO: Should sourceText include the quotes?
    
    didScanString = scanDynamicDelimitedString(OPENING_CURLY_BRACE_TOKEN, CLOSING_CURLY_BRACE_TOKEN);
    if (didScanString) return [EMKToken tokenWithType:EMKRONStringType value:result sourceText:result]; //TODO: Should sourceText include the quotes?

    return nil;
}



/**
 * Description
 *
 * @see 
 *
 * @param
 * @param 
 * @return
 */
-(EMKToken *)scanLinebreakDelimitedString {
    NSString *scannedString;
    if ([self scanUpToString:NEW_LINE_TOKEN caseInsensitive:YES intoString:&scannedString]) {
        return [EMKToken tokenWithType:EMKRONStringType value:scannedString sourceText:scannedString];
    }
    
    //TODO: What about end of file?
    
    return nil;
}



#pragma mark - number type
/**
 * Description
 *
 * @see 
 *
 * @param
 * @param 
 * @return
 */
-(EMKToken *)scanNumber {
    //http://www.json.org/number.gif

    NSString *whitespace = [self scanWhitespaceAndComments:YES];
    NSMutableString *numberString = [NSMutableString new];
    BOOL shouldReturnDouble = NO;
    
    //1. optional negative symbol
    //-?
    if ([self scanString:@"-" caseInsensitive:YES intoString:NULL]) {
        [numberString appendString:@"-"];
    }
    
    //2. Required integer component
    // ( 0 | [1-9][0-9]* )
    NSString *digits = nil;
    if ([self scanString:@"0" caseInsensitive:YES intoString:NULL]) {
        [numberString appendString:@"0"];
    } else if ([self scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"123456789"] intoString:&digits]) {
        [numberString appendString:digits];
        NSString *moreDigits = nil;
        if ([self scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&moreDigits]) {
            [numberString appendString:moreDigits];
        }
    } else {
        //we've failed!        
        goto failed;
    }

    //3. optional fraction component
    //(\.[0-9]*)?
    if ([self scanString:@"." caseInsensitive:YES intoString:NULL]) {
        [numberString appendString:@"."];
        shouldReturnDouble = YES;
        
        NSString *digits = nil;
        if ([self scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&digits]) {
            [numberString appendString:digits];
        }
    }
    
    //4. optional exponent component
    //([e|E][+|-]?[0-9]+)?
    if ([self scanString:@"e" caseInsensitive:YES intoString:NULL]) {
        [numberString appendString:@"e"];
        shouldReturnDouble = YES;
        
        //[+|-]?
        NSString *sign = nil;
        if ([self scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"+-"] intoString:&sign]) {
            [numberString appendString:sign];
        }
        
        
        //[0-9]+
        NSString *exponentValue = nil;
        if ([self scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&exponentValue]) {
            [numberString appendString:exponentValue];
        } else {
            goto failed;
        }
    }
    
    //We've finished scanning the numbers 
    finished: {
        if ([self lookAheadForWhitespaceOrEndOfStream]) {
            if (shouldReturnDouble) {
                double result;
                sscanf([numberString UTF8String], "%lf", &result);
                return [EMKToken tokenWithType:EMKRONNumberType value:[NSNumber numberWithDouble:result] sourceText:numberString];
            } else {
                NSInteger result;
                sscanf([numberString UTF8String], "%li", &result);
                return [EMKToken tokenWithType:EMKRONNumberType value:[NSNumber numberWithDouble:result] sourceText:numberString];
            }        
            
        } else {
            goto failed;
        }
    }
    
    failed:
    [self unread:numberString];    
    [self unread:whitespace];
    return nil;
}



#pragma mark - 'structural' types
/**
 * Description
 *
 * @see
 *
 * @param
 * @param
 * @return
 */
-(EMKToken *)scanContext {
    NSMutableString *scannedWhitespace = [NSMutableString string];
    BOOL didScanWhitespace = NO;
    
    //TODO: Handle comments!
    
    BOOL (^shouldRepeatScan)(void) = ^BOOL(){
        //If the next character is a new line then we may be part of a white space block so continue
        if ([self scanString:@"\n" caseInsensitive:NO intoString:NULL]) {
            [scannedWhitespace appendString:@"\n"];
            return YES;
        }
        return NO;
    };
    
    do { //We assume that we're at the start of the context line
        NSString *possibleContext;
        BOOL didScanLinePrefixWhitespace = [self scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&possibleContext];
        
        BOOL didScanContextTerminal = [self scanString:CONTEXT_TERMINAL_TOKEN caseInsensitive:YES intoString:NULL];
        if (didScanContextTerminal) {
            NSInteger contextSize = (didScanLinePrefixWhitespace) ? [possibleContext length] : 0;
            if (didScanLinePrefixWhitespace) {
                [self self];
            }

            NSNumber *value = [NSNumber numberWithLong:contextSize];
            return [EMKToken tokenWithType:EMKRONContextType value:value sourceText:possibleContext];
        } else if (didScanLinePrefixWhitespace) {
             //What we scanned wasn't a context, it was plain white space
            [scannedWhitespace appendString:possibleContext];
        }
    } while (shouldRepeatScan());
        
    //we failed to scan the context terminal so put back the white space we did scan
    if (didScanWhitespace) [self unread:scannedWhitespace];
    
    return nil;
}



/**
 * Description
 *
 * @see
 *
 * @param
 * @param
 * @return
 */
-(EMKToken *)scanKeyString {
    //[a-z][.|a-z 0-9]*
    
    NSString *openingLetter; //key string must start with a letter
    if (![self scanCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:&openingLetter]) return nil;
    
    NSString *body;
    if (![self scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:&body]) return [EMKToken tokenWithType:EMKRONKeyType value:openingLetter sourceText:openingLetter];
    
    NSString *result = [openingLetter stringByAppendingString:body];
    return [EMKToken tokenWithType:EMKRONKeyType value:result sourceText:result];
}



/**
 * Description
 *
 * @see
 *
 * @param
 * @param
 * @return
 */
-(EMKToken *)scanPairDelimiter {
    NSString *whitespace = [self scanWhitespaceAndComments:YES];
    BOOL didScan = [self scanString:PAIR_DELIMITER_TOKEN caseInsensitive:YES intoString:NULL];
    
    if (didScan) {
        return [EMKToken tokenWithType:EMKRONPairDelimiterType value:PAIR_DELIMITER_TOKEN sourceText:PAIR_DELIMITER_TOKEN];
    }
    
    [self unread:whitespace];
    return nil;
}

@end
