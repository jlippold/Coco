//
//  WatchKitCache.h
//  dtvRemote
//
//  Created by Jed Lippold on 7/14/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "dtvChannel.h"

@interface WatchKitCache : NSObject

+ (NSMutableDictionary *) loadChannels;
+ (NSMutableDictionary *) loadAllChannels;

@end
