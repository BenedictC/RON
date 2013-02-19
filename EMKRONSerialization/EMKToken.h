//
//  EMKRONToken.h
//  RON
//
//  Created by Benedict Cohen on 23/06/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "EMKRONConstants.h"



@interface EMKToken : NSObject
-(id)initWithTokenType:(NSInteger)type value:(id)value sourceText:(NSString *)sourceText;
@property(readonly, nonatomic) NSInteger type;
@property(readonly, nonatomic) id value;
@property(readonly, nonatomic) NSString *sourceText;

+(id)tokenWithType:(NSInteger)type value:(id)value sourceText:(NSString *)sourceText;
@end
