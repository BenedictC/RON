//
//  EMKRONStreamParser.h
//  RON
//
//  Created by Benedict Cohen on 22/06/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "EMKRONConstants.h"



@interface EMKRONStreamParser : NSObject
-(id)initWithStream:(NSInputStream *)stream parseMode:(EMKRONReadingOptions)parseMode;
-(id)parse:(NSError *__autoreleasing *)error;
@end
