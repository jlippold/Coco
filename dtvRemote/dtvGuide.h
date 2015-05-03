//
//  dtvGuide.h
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "dtvChannel.h"
#import "dtvGuideItem.h"

NSDate *guideTime;

@interface dtvGuide : NSObject

+ (NSDictionary *)getDurationForChannel:(dtvGuideItem *)guideItem;

+ (void) refreshGuide:(NSMutableDictionary *)channels
               sorted:(NSMutableDictionary *)sortedChannels
              forTime:(NSDate *)time;

+ (NSString *)getJoinedArrayByProp:(NSString *)propS
                       arrayOffset:(NSInteger)offset
                         chunkSize:(NSInteger)size
                          channels:(NSMutableDictionary *)channels
                    sortedChannels:(NSMutableDictionary *)sortedChannels;

+ (NSMutableDictionary *) getNowPlayingForChannel:(dtvChannel *)channel;
+ (NSDate *)getHalfHourIncrement:(NSDate *)date;

@end
