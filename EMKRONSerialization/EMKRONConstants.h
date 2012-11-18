//
//  EMKRONConstants.h
//  RON
//
//  Created by Benedict Cohen on 22/06/2012.
//  Copyright (c) 2012 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>


//TODO: This file exists so that we don't have to import EMKRONSerialzation into 'child' classes (and thus prevent depenancy hell)
//Is there a better way to achieve this?


typedef enum {
    EMKRONReadingStrictMode = (0),
    EMKRONReadingPermissiveMode = (1UL << 0),
    
    //TODO:
    //    EMKRONReadingMutableContainers = (1UL << 1),
    //    EMKRONReadingMutableLeaves = (1UL << 2),
    //    EMKRONReadingAllowFragments = (1UL << 3)
} EMKRONReadingOptions;



typedef enum {
    EMKRONWritingFullQuoting = (0),
} EMKRONWritingOptions;


#pragma mark - Error domain (implemented in EMKRONSerialization.m)
extern NSString * const EMKRONErrorDomain;
