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
    EMKRONSentinalType      = 0,
    //Data types
    EMKRONNumberType        = 1 << 1,
    EMKRONNullType          = 1 << 2,
    EMKRONBooleanType       = 1 << 3,
    EMKRONStringType        = 1 << 4,
    
    //Structural types (i.e. not data, but explicitly stated in the input stream)
    EMKRONContextType       = 1 << 5,
    EMKRONKeyType           = 1 << 6,
    EMKRONPairDelimiterType = 1 << 7,
    
    //Pseudo/implied types
    EMKRONArrayOpenType     = 1 << 8,
    EMKRONArrayCloseType    = 1 << 9,
    EMKRONObjectOpenType    = 1 << 10,
    EMKRONObjectCloseType   = 1 << 11,
}  EMKRONTypes;
