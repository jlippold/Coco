//
//  Commands.h
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Commands : NSObject

+ (void)changeChannel:(NSString *)chNum device:(NSMutableDictionary *)device;
+ (void)whatsOnDevice:(NSDictionary *) device;

@end
