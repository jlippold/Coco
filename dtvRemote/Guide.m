//
//  Guide.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "Guide.h"
#import "Channels.h"

#include <math.h>

@implementation Guide

+ (void) refreshGuide:(NSMutableDictionary *)channels sorted:(NSMutableDictionary *)sortedChannels forTime:(NSDate *)time {
    
    if ([[channels allKeys] count] == 0) {
        return;
    }
    
    NSDate *dt = [NSDate date];
    if (time != nil) {
        dt = time;
    }
    
    dt = [self getHalfHourIncrement:dt];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageNextGuideRefreshTime"
                                                        object:[dt dateByAddingTimeInterval:(30*60)]];
    
    
    //Download data in 50 channel chunks
    NSUInteger chunkSize = 200;
    __block int completed = 0;
    __block int total = ceil((double)[[channels allKeys] count]/chunkSize);
    __block NSMutableDictionary *guide = [[NSMutableDictionary alloc] init];
    
    
    //add all requests to the queue
    for (NSUInteger i = 0; i < total; i++) {
        
        NSInteger offset = i*chunkSize;
        
        NSString *chNums = [self getJoinedArrayByProp:@"chNum"
                                          arrayOffset:offset
                                            chunkSize:chunkSize
                                             channels:channels
                                       sortedChannels:sortedChannels];
        
        NSString *chIds = [self getJoinedArrayByProp:@"chId"
                                         arrayOffset:offset
                                           chunkSize:chunkSize
                                            channels:channels
                                      sortedChannels:sortedChannels];
        
        NSMutableDictionary *results = [self getGuideDataForChannels:chIds channelNums:chNums forTime:dt];
        [guide addEntriesFromDictionary:results];
        
        completed++;
        
        if (completed >= total) {
            NSLog(@"guide updated");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedGuide" object:guide];
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

    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
    NSString *localDateString = [dateFormatter stringFromDate:time];
    
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
    NSString *cookie = [Channels DTVCookie];
    [mutableRequest addValue:cookie forHTTPHeaderField:@"Cookie"];
    request = [mutableRequest copy];
    
    NSData* data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response error:&connectionError];
    
    NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
    
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
                
                id show = [channelSchedule objectAtIndex:i];
                
                NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
                //[dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
                NSDate *startDate = [dateFormatter dateFromString:show[@"airTime"]];
                NSInteger duration = [show[@"duration"] intValue];
                
                bool isPlaying = [self isNowPlaying:startDate duration:duration];
                if (isPlaying) {
                    
                    if (deDuplicate[chNum]) {
                        //the channel has already been added
                        if ([[[channel objectForKey:@"chHd"] stringValue] isEqualToString:@"1"]) {
                            //and new channel is in HD, overwrite the old with the new
                            [deDuplicate setObject:chId forKey:chNum];
                        }
                    } else {
                        //new channel
                        [deDuplicate setObject:chId forKey:chNum];
                    }
                    
                    NSMutableDictionary *guideItem = [[NSMutableDictionary alloc] init];
                    
                    if (show[@"programID"]) {
                        guideItem[@"programID"] = show[@"programID"];
                    }
                    if (show[@"title"]) {
                        guideItem[@"title"] = show[@"title"];
                    }
                    if (show[@"title"] && show[@"episodeTitle"]) {
                        guideItem[@"title"] = [NSString stringWithFormat:@"%@ - %@",
                                               show[@"title"], show[@"episodeTitle"]];
                    }
                    if (show[@"title"] && show[@"releaseYear"]) {
                        guideItem[@"title"] = [NSString stringWithFormat:@"%@ (%@)",
                                               show[@"title"], show[@"releaseYear"]];
                    }
                    if (show[@"starRatingNum"]) {
                        guideItem[@"starRating"] = show[@"starRatingNum"];
                    }
                    if (show[@"primaryImageUrl"]) {
                        guideItem[@"boxcover"] = show[@"primaryImageUrl"];
                    }
                    if (show[@"mainCategory"]) {
                        guideItem[@"category"] = show[@"mainCategory"];
                    }
                    if (show[@"hd"]) {
                        guideItem[@"hd"] = show[@"hd"];
                    }
                    if (show[@"rating"]) {
                        guideItem[@"mpaaRating"] = show[@"rating"];
                    }
                    
                    guideItem[@"starts"] = startDate;
                    guideItem[@"ends"] = [startDate dateByAddingTimeInterval:duration*60];
                    
                    guideItem[@"upNext"] = @"Not Available";
                    if (i < [channelSchedule count]-1) {
                        id nextShow = [channelSchedule objectAtIndex:i+1];
                        guideItem[@"upNext"] = nextShow[@"title"];
                    }
                    
                    
                    [results setObject:guideItem forKey:deDuplicate[chNum]];
                    
                }
                
            }
            
            
        }
    }
    
    return results;
}

+ (NSMutableDictionary *) getNowPlayingForChannel:(id)channel {
    NSDate *dt = [self getHalfHourIncrement:[NSDate date]];
    return [self getGuideDataForChannels:[channel[@"chId"] stringValue]
                             channelNums:[channel[@"chNum"] stringValue]
                                 forTime:dt];
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
            
            id sectionChannelKey = [sectionChannels objectAtIndex:y];
            id chId = [[sectionData objectForKey:sectionChannelKey] stringValue];
            NSDictionary *channel = channels[chId];
            if (overallCounter <= (offset + size)) {
                [outArray addObject:[channel[prop] stringValue]];
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
    
    return  [calendar dateFromComponents:components];
    
}

+ (BOOL)isNowPlaying:(NSDate *)startDate duration:(NSInteger)duration {
//    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
 //   [dateFormatter setTimeZone:[NSTimeZone defaultTimeZone]];
    NSDate *now = [[NSDate alloc] init];
    if ([startDate timeIntervalSinceDate:now] > 0) {
        return NO;
    }
    NSDate *endDate = [startDate dateByAddingTimeInterval:duration*60];
    return ([endDate timeIntervalSinceDate:now] > 0);
}

+ (NSDictionary *)getDurationForChannel:(id)guideItem {
    
    NSDate *now = [NSDate new];
    NSDate *ends = [guideItem objectForKey:@"ends"];
    NSDate *starts = [guideItem objectForKey:@"starts"];
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
