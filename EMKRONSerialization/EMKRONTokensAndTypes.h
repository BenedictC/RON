//
//  EMKRONTokensAndTypes.h
//  RON
//
//  Created by Benedict Cohen on 22/06/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//



#pragma mark - token definitions
#define CONTEXT_TERMINAL_TOKEN @"-"
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



#pragma mark - types
typedef enum : NSInteger {
    //Data types
    EMKRONNumberType,
    EMKRONNullType,
    EMKRONBooleanType,
    EMKRONStringType,
    
    //Structural types (i.e. not data, but explicitly stated in the input stream)
    EMKRONContextType,
    EMKRONKeyType,
    EMKRONPairDelimiterType,
    
    //Pseudo/implied types
    EMKRONArrayOpenType,
    EMKRONArrayCloseType,
    EMKRONObjectOpenType,
    EMKRONObjectCloseType,
}  EMKRONTypes;
