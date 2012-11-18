//
//  EMKUTF8StreamScanner.h
//  RON
//
//  Created by Benedict Cohen on 23/06/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    EMKUTF8StreamScannerStatusOpen,
    EMKUTF8StreamScannerStatusAtEnd,
    EMKUTF8StreamScannerStatusError
} EMKUTF8StreamScannerStatus;



extern NSString * const EMKUTF8StreamScannerErrorDomain;
extern NSString * const EMKUTF8StreamScannerErrorStreamErrorKey;

enum {
    EMKUTF8StreamScannerInvalidDataError,
    EMKUTF8StreamScannerStreamError
};



@interface EMKUTF8StreamScanner : NSObject
//init
-(id)initWithStream:(NSInputStream *)stream;

//accessors
-(NSInputStream *)stream;

//status
-(EMKUTF8StreamScannerStatus)status;
-(NSError *)error;
-(NSString *)buffer;
-(NSInteger)readCharacterCount;
-(BOOL)isAtEnd;

//stream manipulation
-(NSString *)read:(NSUInteger)maxLength;
-(void)unread:(NSString *)streamHead;


//token scanning
-(BOOL)scanCharactersFromSet:(NSCharacterSet *)characterSet intoString:(NSString * __autoreleasing *)outString;
-(BOOL)scanUpToCharacterFromSet:(NSCharacterSet *)characterSet intoString:(NSString * __autoreleasing *)outString;
-(BOOL)scanString:(NSString *)pattern caseInsensitive:(BOOL)caseInsensitive intoString:(NSString * __autoreleasing *)outString;
-(BOOL)scanUpToString:(NSString *)pattern caseInsensitive:(BOOL)caseInsensitive intoString:(NSString * __autoreleasing *)outString;

-(BOOL)lookAheadForString:(NSString *)string caseInsensitive:(BOOL)caseInsensitive;
-(BOOL)lookAheadForCharacterFromSet:(NSCharacterSet *)characterSet;

@end
