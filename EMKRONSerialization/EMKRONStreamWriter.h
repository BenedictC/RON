//
//  EMKRONStreamWriter.h
//  RON
//
//  Created by Benedict Cohen on 22/06/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "EMKRONConstants.h"



@interface EMKRONStreamWriter : NSObject
@property(readonly, nonatomic) id object;
@property(readonly, nonatomic) NSOutputStream *stream;
@property(readwrite, nonatomic) NSUInteger contextSize;

-(id)initWithStream:(NSOutputStream *)stream object:(id)object;
-(BOOL)write:(NSError *__autoreleasing *)error;
@end


