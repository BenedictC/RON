//
//  EMKRONToken.m
//  RON
//
//  Created by Benedict Cohen on 23/06/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import "EMKToken.h"

@implementation EMKToken
@synthesize type = _type;
@synthesize value = _value;



-(id)initWithTokenType:(NSInteger)type value:(id)value {
    self = [super init];
    if (self != nil) {
        _type = type;
        _value = value;
    }
    return self;
}



+(id)tokenWithType:(NSInteger)type value:(id)value {
    return [[self alloc] initWithTokenType:type value:value];
}



-(NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p: type = %lu; value = %@>", NSStringFromClass([self class]), self,  self.type, self.value];
}

@end
