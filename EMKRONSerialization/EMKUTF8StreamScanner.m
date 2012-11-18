//
//  EMKUTF8StreamScanner.m
//  RON
//
//  Created by Benedict Cohen on 23/06/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "EMKUTF8StreamScanner.h"


#pragma mark UTF8 byte conformance macros
#define UTF8_IS_SINGLE_BYTE_CHAR(byte)   ( (byte & 0x80) == 0x00) //has 0 at first position
#define UTF8_IS_FIRST_BYTE_OF_CHAR(byte) (((byte & 0x80) == 0x00) || ((byte & 0xC0) == 0xC0))
#define UTF8_IS_DATA_BYTE_CHAR(byte)     (((byte & 0x80) == 0x80) && ((byte & 0x40) == 0x00))

#pragma mark constants
NSString * const EMKUTF8StreamScannerErrorDomain = @"EMKUTF8StreamScannerStatusErrorDomain";
NSString * const EMKUTF8StreamScannerErrorStreamErrorKey = @"EMKUTF8StreamScannerErrorStreamErrorKey";



#pragma mark EMKUTF8StreamScanner implementation
@implementation EMKUTF8StreamScanner {
#pragma mark ivars    
    NSInputStream *_stream;
    u_char _leftoverBytes[6];
    NSUInteger _leftoverBytesLength;
    NSMutableString *_string;
    NSError *_error;
    NSInteger _readCharacterCount;
}



#pragma mark life cycle methods
-(id)init {
    return [self initWithStream:nil];
}



-(id)initWithStream:(NSInputStream *)stream {
    self = [super init];
    if (self != nil) {
        if (stream == nil) {
            NSString *reason = @"Attempted to init with nil stream";
            [[NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil] raise];
            return nil;
        }
        
        _stream = stream;
        _string = [NSMutableString stringWithCString:"" encoding:NSUTF8StringEncoding];
    }
    return self;
}



#pragma mark accessors
-(NSInputStream *)stream {
    return _stream;
}



#pragma mark status reporting methods
-(EMKUTF8StreamScannerStatus)status {
    NSStreamStatus status = [_stream streamStatus];
    if (status == NSStreamStatusOpen) return EMKUTF8StreamScannerStatusOpen;
    if (status == NSStreamStatusAtEnd) return EMKUTF8StreamScannerStatusAtEnd;    
    
    return EMKUTF8StreamScannerStatusError;
}



-(NSError *)error {
    if (_error != nil) return _error;
    
    NSError *streamError = [_stream streamError];
    
    if (streamError != nil) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:streamError forKey:EMKUTF8StreamScannerErrorStreamErrorKey];
        NSError *error = [NSError errorWithDomain:EMKUTF8StreamScannerErrorDomain code:EMKUTF8StreamScannerStreamError userInfo:userInfo];
        return error;
    }
    
    return nil;
}



#pragma mark stream manipulation
-(NSString *)read:(NSUInteger)maxLength {
    //if we have previously errored then do nothing
    if ([self error] != nil) {
        return nil;
    }
    
    //ensure we have enough string
    if (maxLength > [_string length]) {
        [self topupString:maxLength];
    }
    
    NSString *result = nil;
    if ([_string length] < maxLength) {
        //return all of _string and start a new string
        result = [_string copy];
        _string = [NSMutableString new];
    } else {
        //return the requested length and remove it from _string
        result = [_string substringToIndex:maxLength];
        [_string replaceCharactersInRange:NSMakeRange(0, maxLength) withString:@""];
    }
    
    _readCharacterCount += [result length];
    return result;
}



-(void)topupString:(NSUInteger)maxLength {
    u_int8_t *buffer = malloc(sizeof(&buffer) * MAX_INPUT);

    while ([_stream hasBytesAvailable] && [_string length] < maxLength) {
        //copy the left over bytes from the last read to the start of buffer
        for (NSInteger i = 0; i < _leftoverBytesLength; i++) buffer[i] = _leftoverBytes[i];
        
        //read the stream into the buffer (starting at the end of the left over bytes which we copied in)
        NSInteger readLength = [_stream read:(buffer + _leftoverBytesLength) maxLength:MAX_INPUT-_leftoverBytesLength];
        NSInteger actualLength = _leftoverBytesLength + readLength;
        
        //reset leftoverBytesLength
        _leftoverBytesLength = 0;        
        
        //check that the tail bytes are not a multipart character
        BOOL isTailPossiblyIncompleteCharacter = !UTF8_IS_SINGLE_BYTE_CHAR(buffer[actualLength-1]);
        BOOL isAtEndOfStream = [_stream streamStatus] == NSStreamStatusAtEnd;
        if (isTailPossiblyIncompleteCharacter && !isAtEndOfStream) {
            //walk backwards through the buffer until we find the open byte of a character
            while (!UTF8_IS_FIRST_BYTE_OF_CHAR(buffer[(actualLength-1) - _leftoverBytesLength])) _leftoverBytesLength++;
            //we also want to include the first byte
            _leftoverBytesLength++;
            
            //update actualLength
            actualLength -= _leftoverBytesLength;
            
            //copy the bytes into leftoverBytes
            for (NSInteger i = 0; i < _leftoverBytesLength; i++) _leftoverBytes[i] = buffer[actualLength + i];
        }        
        
        NSString *subString = [[NSString alloc] initWithBytes:buffer length:actualLength encoding:NSUTF8StringEncoding];        
        
        //if substring is nil then there must have been an error in the UTF8 stream
        if (subString == nil) {
            _error = [NSError errorWithDomain:EMKUTF8StreamScannerErrorDomain code:EMKUTF8StreamScannerInvalidDataError userInfo:nil];
            break;
        }
        [_string appendString:subString];
    }
    
    free(buffer);
}



-(void)unread:(NSString *)streamHead {
    [_string insertString:streamHead atIndex:0];
    _readCharacterCount -= [streamHead length];
}



#pragma mark token scanning
/**
 * Scans input stream as long a characters are in characterSet. Scanned characters are placed in outString.
 *
 * @see scanUpToCharacterFromSet:intoString: (same implementation except predicate in while loop is inverted)
 (
 * @param characterSet characters to match
 * @param outString on return contains the scanned characters. Invoke with NULL to scan past characters.
 * @return Returns YES if at least 1 character was scanned, else returns NO.
 */
-(BOOL)scanCharactersFromSet:(NSCharacterSet *)characterSet intoString:(NSString * __autoreleasing *)outString {
    //read first character
    NSString *character = [self read:1];
    NSMutableString *result = [NSMutableString new];
    
    while ([character rangeOfCharacterFromSet:characterSet].location != NSNotFound) {
        //store charater
        [result appendString:character];
        
        //prep for the next loop
        character = [self read:1];
    }
    
    //put back the last character because it didn't match
    [self unread:character];
    
    //if we matched anything return success and result
    if ([result length] > 0) {
        if (outString != NULL) *outString = [result copy];
        return YES;
    }
    
    //we didn't match
    return NO;
}



/**
 * Scans input stream as long a characters are not in characterSet. Scanned characters are placed in outString.
 *
 * @see scanCharactersFromSet:intoString: (same implementation except predicate in while loop is inverted)
 *
 * @param characterSet characters to not match
 * @param outString on return contains the scanned characters. Invoke with NULL to scan past characters.
 * @return Returns YES if at least 1 character was scanned, else returns NO.
 */
-(BOOL)scanUpToCharacterFromSet:(NSCharacterSet *)characterSet intoString:(NSString * __autoreleasing *)outString {
    //read first character
    NSString *character = [self read:1];
    NSMutableString *result = [NSMutableString new];
    
    while ([character rangeOfCharacterFromSet:characterSet].location == NSNotFound) {
        //store charater
        [result appendString:character];
        
        //prep for the next loop
        character = [self read:1];
    }
    
    //put back the last character because it didn't match
    [self unread:character];
    
    //if we matched anything return success and result
    if ([result length] > 0) {
        if (outString != NULL) *outString = [result copy];
        return YES;
    }
    
    //we didn't match
    return NO;
}



/**
 * Matches the head of the stream.
 *
 * @see scanCharactersFromSet:intoString: (same implementation except predicate in while loop is inverted)
 *
 * @param
 * @param 
 * @return
 */
-(BOOL)scanString:(NSString *)pattern caseInsensitive:(BOOL)caseInsensitive intoString:(NSString * __autoreleasing *)outString {
    //get the possible match
    NSString *result = [self read:[pattern length]];
    
    NSStringCompareOptions options = (caseInsensitive) ? NSCaseInsensitiveSearch : 0;
    if ([result compare:pattern options:options] == NSOrderedSame) {
        //we matched!        
        if (outString != NULL) *outString = result;
        return YES;
    }
    
    //it didn't match so we don't want it
    [self unread:result];
    
    return NO;
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
-(BOOL)scanUpToString:(NSString *)pattern caseInsensitive:(BOOL)caseInsensitive intoString:(NSString *__autoreleasing *)outString {
    //we need at least enough string to match the buffer
    NSMutableString *buffer = [[self read:[pattern length]] mutableCopy];
    
    //if the buffer matches then we've not matched anything
    if ([buffer isEqualToString:pattern]) {
        [self unread:buffer];
        return NO;
    }
    
    //TODO: search backwards until we find the last character of the string then fill the buffer so
    //that range from tail match location to end = [pattern length]
    BOOL didFindPattern = NO;
    NSStringCompareOptions options = (caseInsensitive) ? NSCaseInsensitiveSearch : 0;
    NSInteger searchStartPosition = 0;
    do {
        //TODO: Figure out how many characters to add to the buffer
        NSInteger minLengthForPossibleMatch = [pattern length];
        //get some more string
        NSString *freshString = [self read:minLengthForPossibleMatch];
        
        //if we failed to fetch any string then we're at the end of the file and haven't found pattern
        if ([freshString length] == 0) {
            [self unread:buffer];
            return NO;
        }
        
        //add string to the buffer
        [buffer appendString:freshString];
        
        //check the buffer to see if it contains pattern        
        NSRange searchRange = NSMakeRange(searchStartPosition, [buffer length] - searchStartPosition);
        didFindPattern = [buffer rangeOfString:pattern options:options range:searchRange].location != NSNotFound;
        
        //TODO: prepare for the next loop
        //searchStartPosition = ???;
        
    } while (!didFindPattern);
    
    //if we've got past the while loop then we have definately matched pattern
    
    //create a new string containing the result
    NSRange patternRange = [buffer rangeOfString:pattern];
    if (outString != NULL) *outString = [buffer substringToIndex:patternRange.location];
    
    //remove the section we want from the buffer and put the rest back
    [buffer replaceCharactersInRange:NSMakeRange(0, patternRange.location) withString:@""];
    [self unread:buffer];
    
    return YES;
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
-(BOOL)lookAheadForString:(NSString *)pattern caseInsensitive:(BOOL)caseInsensitive {
    //store the result of a success scan so we can put it back    
    NSString *scannedString;
    if ([self scanString:pattern caseInsensitive:caseInsensitive intoString:&scannedString]) {
        //put back the string because we're only looking ahead
        [self unread:scannedString];
        return YES;
    }
    
    return NO;
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
-(BOOL)lookAheadForCharacterFromSet:(NSCharacterSet *)characterSet {
    //store the result of a success scan so we can put it back
    NSString *scannedString;
    if ([self scanCharactersFromSet:characterSet intoString:&scannedString]) {
        [self unread:scannedString];
        return YES;
    }
    
    return NO;
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
-(BOOL)isAtEnd {
    NSString *testString = [self read:1];
    BOOL didRead = testString != nil && [testString length] > 0;
    if (didRead) [self unread:testString];
    
    return !didRead;
}



-(NSString *)buffer {
    return [_string copy];
}



-(NSInteger)readCharacterCount {
    return _readCharacterCount;
}

@end
