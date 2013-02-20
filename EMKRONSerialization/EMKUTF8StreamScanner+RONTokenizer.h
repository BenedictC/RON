//
//  EMKUTF8StreamScanner+RONTokenizer.h
//  RON
//
//  Created by Benedict Cohen on 07/07/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "EMKUTF8StreamScanner.h"

#import "EMKToken.h"
#import "EMKRONTokensAndTypes.h"



/*
 
 This class is a bit of a mutant. It is actually parser logic as it is comprenending seqences of tokens. However, it is 
 implemented as a category on the scanner as it's convientent to do so. It means that the actual parser class only has to 
 handling the logical arrangment of data rather than the minution of what the data looks like.
 
 */


@interface EMKUTF8StreamScanner (RONTokenizer)

-(EMKToken *)scanNumber;
-(EMKToken *)scanNull;
-(EMKToken *)scanBoolean;
-(EMKToken *)scanStrictString;
-(EMKToken *)scanLinebreakDelimitedString;

//TODO: Figure out how to handle whitespace and comments
-(EMKToken *)scanContext;
-(EMKToken *)scanKeyString;
-(EMKToken *)scanPairDelimiter;

@end



static inline EMKToken * reinturpretTokenAsKey(EMKToken *token) {
    return [EMKToken tokenWithType:EMKRONKeyStringType value:token.sourceText sourceText:token.sourceText];
}
