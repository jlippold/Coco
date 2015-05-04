//
//  dtvGuide.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "dtvGuide.h"
#import "dtvGuideItem.h"
#import "dtvChannels.h"
#import "dtvChannel.h"
#include <math.h>

@implementation dtvGuide

+ (void) refreshGuide:(NSMutableDictionary *)channels sorted:(NSMutableDictionary *)sortedChannels forTime:(NSDate *)time {
    
    if ([[channels allKeys] count] == 0) {
        return;
    }
    
    BOOL refreshingFutureDate = YES;
    NSDate *dt = [self getHalfHourIncrement:time];
    NSDate *now = [self getHalfHourIncrement:[NSDate date]];
    
    if ([dt isEqualToDate:now]) {
        refreshingFutureDate = NO;
    }
    
    //Download data in channel chunks
    NSUInteger chunkSize = 75;
    __block int completed = 0;
    __block int total = ceil((double)[[channels allKeys] count]/chunkSize);
    __block NSMutableDictionary *guide = [[NSMutableDictionary alloc] init];
    
    
    //add all requests to the queue
    for (NSUInteger i = 0; i < total; i++) {
        
        NSInteger offset = i*chunkSize;
        
        NSString *chNums = [self getJoinedArrayByProp:@"number"
                                          arrayOffset:offset
                                            chunkSize:chunkSize
                                             channels:channels
                                       sortedChannels:sortedChannels];
        
        NSString *chIds = [self getJoinedArrayByProp:@"id"
                                         arrayOffset:offset
                                           chunkSize:chunkSize
                                            channels:channels
                                      sortedChannels:sortedChannels];
        
        NSMutableDictionary *results = [self getGuideDataForChannels:chIds channelNums:chNums forTime:dt];
        [guide addEntriesFromDictionary:results];
        
        completed++;
        
        if (completed >= total) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedGuideProgress"
                                                                object:[NSNumber numberWithDouble:1.0]];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedGuide" object:guide];
            if (!refreshingFutureDate) {
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedGuide" object:guide];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"messageNextGuideRefreshTime"
                                                                object:[dt dateByAddingTimeInterval:(30*60)]];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedFutureGuide" object:guide];
            }
        } else {
            long double progress =(completed*1.0/total*1.0);
            //NSLog(@"progress %Lf", progress);
            NSNumber *nsprogress = [NSNumber numberWithDouble:progress];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedGuideProgress"
                                                                object:nsprogress];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedGuidePartial"
                                                                object:guide];
        }
        
        
    }
}

+ (NSMutableDictionary *) getGuideDataForChannels:(NSString *)channelIds
                     channelNums:(NSString *)channelNums forTime:(NSDate *)time {

    BOOL refreshingFutureDate = YES;
    if ([time isEqualToDate:[self getHalfHourIncrement:[NSDate date]]]) {
        refreshingFutureDate = NO;
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
    NSString *localDateString = [dateFormatter stringFromDate:time];

    [dateFormatter setDateFormat:@"MMM, d h:mm a"];
    NSString *dt = [dateFormatter stringFromDate:time];

    
    NSString *builder = @"https://www.directv.com/json/channelschedule";
    builder = [builder stringByAppendingString:@"?channels=%@"];
    builder = [builder stringByAppendingString:@"&startTime=%@"];
    builder = [builder stringByAppendingString:@"&hours=4"];
    builder = [builder stringByAppendingString:@"&chIds=%@"];
    
    
    NSString *strUrl = [NSString stringWithFormat:builder, channelNums,
                        [localDateString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], channelIds];

    NSURLResponse* response;
    NSError *connectionError;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:strUrl]];
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    NSString *cookie = [dtvChannels DTVCookie];
    [mutableRequest addValue:cookie forHTTPHeaderField:@"Cookie"];
    request = [mutableRequest copy];
    
    NSData* data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response error:&connectionError];
    
    NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
    
    if (connectionError) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageAPIDown" object:nil];
    }
    
    
    if (data.length > 0 && connectionError == nil) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];

        NSMutableDictionary *deDuplicate = [[NSMutableDictionary alloc] init];
        
        for (id channel in [json objectForKey: @"schedule"]) {
            
            if ( ![[channel objectForKey:@"chId"] isKindOfClass:[NSNumber class]] ) {
                continue;
            }
            
            NSArray *channelSchedule = [channel objectForKey:@"schedules"];
            NSString *chId = [[channel objectForKey:@"chId"] stringValue];
            NSString *chNum = [[channel objectForKey:@"chNum"] stringValue];
            
            int i;
            for (i = 0; i < [channelSchedule count]; i++) {
                
                NSDictionary *show = [channelSchedule objectAtIndex:i];
                dtvGuideItem *guideItem = [[[dtvGuideItem alloc]init] initWithJSON:show];
                
                if ((guideItem.onAir || refreshingFutureDate) && guideItem.starts) {
                    
                    if (deDuplicate[chNum]) {
                        if ([[[channel objectForKey:@"chHd"] stringValue] isEqualToString:@"1"]) {
                            [deDuplicate setObject:chId forKey:chNum];
                        }
                    } else {
                        [deDuplicate setObject:chId forKey:chNum];
                    }
                    
                    
                    if (refreshingFutureDate) {
                        guideItem.futureAiring = dt;
                    } else {
                        if (i < [channelSchedule count]-1) {
                            id nextShow = [channelSchedule objectAtIndex:i+1];
                            guideItem.upNext = nextShow[@"title"];
                        }
                    }

                    [results setObject:guideItem forKey:deDuplicate[chNum]];
                }
            }
        }
    }
    
    return results;
}

+ (NSMutableDictionary *) getNowPlayingForChannel:(dtvChannel *) channel {
    NSDate *dt = [self getHalfHourIncrement:[NSDate date]];
    NSMutableDictionary *guideData = [self getGuideDataForChannels: @(channel.identifier).stringValue
                                                       channelNums: @(channel.number).stringValue
                                                           forTime:dt];
    return guideData;
}

+ (NSString *)getJoinedArrayByProp:(NSString *)prop
                       arrayOffset:(NSInteger)offset
                         chunkSize:(NSInteger)size
                          channels:(NSMutableDictionary *)channels
                    sortedChannels:(NSMutableDictionary *)sortedChannels {
    
    //returns a csv list of some property in _channels for url building
    NSMutableArray *outArray = [[NSMutableArray alloc] init];
    
    NSUInteger overallCounter = 0;
    
    NSArray *sections = [[sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    for (NSUInteger x = 0; x < [sections count]; x++) {
        
        NSString *sectionKey = [sections objectAtIndex:x];
        NSMutableDictionary *sectionData = [sortedChannels objectForKey:sectionKey];
        NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
        
        for (NSUInteger y = 0; y < [sectionChannels count]; y++) {
            
            NSString *chId = [sectionChannels objectAtIndex:y];
            dtvChannel *channel = channels[chId];
            if (overallCounter <= (offset + size)) {
                if ([prop isEqualToString:@"number"]) {
                    [outArray addObject:@(channel.number).stringValue];
                }
                if ([prop isEqualToString:@"id"]) {
                    [outArray addObject:@(channel.identifier).stringValue];
                }
            }
            overallCounter++;
        }
    }
    
    return [outArray componentsJoinedByString:@","];
}

+ (NSDate *)getHalfHourIncrement:(NSDate *)date {
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    [calendar setTimeZone:[NSTimeZone localTimeZone]];
    NSDateComponents *components = [calendar componentsInTimeZone:[NSTimeZone localTimeZone] fromDate:date];
    NSInteger minute = [components minute];
    [components setValue:0 forComponent:NSCalendarUnitSecond];
    
    if (minute < 30) { //round down to hour
        [components setValue:0 forComponent:NSCalendarUnitMinute];
    } else { //round down to half hour
        [components setValue:30 forComponent:NSCalendarUnitMinute];
    }
    [components setValue:0 forComponent:NSCalendarUnitSecond];
    [components setValue:0 forComponent:NSCalendarUnitNanosecond];
    return  [calendar dateFromComponents:components];
    
}



+ (NSDictionary *)getDurationForChannel:(dtvGuideItem *)guideItem {
    
    NSDate *now = [NSDate new];
    NSDate *ends = guideItem.ends;
    NSDate *starts = guideItem.starts;
    BOOL showIsEndingSoon = NO;
    
    NSTimeInterval duration = [ends timeIntervalSinceDate:starts];
    NSTimeInterval elasped = [now timeIntervalSinceDate:starts];
    double percentage = (elasped/duration)*100;
    
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    [calendar setTimeZone:[NSTimeZone localTimeZone]];
    NSUInteger unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute;
    NSDateComponents *components = [calendar components:unitFlags
                                               fromDate: now
                                                 toDate: ends
                                                options:0];
    
    NSString *timeLeft = [NSString stringWithFormat:@"%02ld:%02ld", [components hour], [components minute]];
    
    if ([components hour] == 0 && [components minute] <= 10) {
        showIsEndingSoon = YES;
    }
    
    NSDictionary *props = @{
                            @"duration": @(duration),
                            @"elasped": @(elasped),
                            @"percentage" : @(percentage),
                            @"showIsEndingSoon": @(showIsEndingSoon),
                            @"timeLeft": timeLeft
                            };
    
    return props;
}

@end
