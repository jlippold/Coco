//
//  Guide.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "Guide.h"
#include <math.h>

@implementation Guide


-(id) init {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedChannels:)
                                                 name:@"messageUpdatedChannels" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageSetGuideTime:)
                                                 name:@"messageSetGuideTime" object:nil];
    
    
    _whatsPlayingQueue = [[NSOperationQueue alloc] init];
    _whatsPlayingQueue.name = @"Whats Playing";
    _whatsPlayingQueue.maxConcurrentOperationCount = 3;
    
    [self startTimer];
    
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) messageUpdatedChannels:(NSNotification *)notification {
    _channels = [notification object];
    [self refreshGuide];
}

- (void) messageSetGuideTime:(NSNotification *)notification {
    _guideTime = [notification object];
    [self refreshGuide];
}

-(void)startTimer {
    [self refreshGuide];
    if (!_whatsPlayingTimer) {
        _whatsPlayingTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(fireTimer:) userInfo:nil repeats:YES];
    }
}

-(void)stopTimer {
    [_whatsPlayingTimer invalidate];
    _whatsPlayingTimer = nil;
}

- (void)fireTimer:(NSTimer *)timer {
    [self refreshGuide];
}

- (void) refreshGuide {
    
    NSMutableDictionary *guide = [[NSMutableDictionary alloc] init];
    
    if ([[_channels allKeys] count] == 0) {
        return;
    }
    
    [_whatsPlayingQueue cancelAllOperations];
    

    NSDate *dt = [NSDate date];
    if (_guideTime != nil) {
        dt = _guideTime;
    }
    
    dt = [self getHalfHourIncrement:dt];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
    NSString *localDateString = [dateFormatter stringFromDate:dt];

    NSLog(@"DT: %@", localDateString);
    
    //build a base URL for all now playing requests
    NSString *builder = @"https://www.directv.com/json/channelschedule";
    builder = [builder stringByAppendingString:@"?channels=%@"];
    builder = [builder stringByAppendingString:@"&startTime=%@"];
    builder = [builder stringByAppendingString:@"&hours=4"];
    builder = [builder stringByAppendingString:@"&chIds=%@"];
    
    
    //Download data in 50 channel chunks
    NSUInteger chunkSize = 50;
    __block int requests = ceil((double)[[_channels allKeys] count]/chunkSize);
    __block int completed = 0;
    
    NSLog(@"Total Channels: %lu", (unsigned long)[[_channels allKeys] count]);
    NSLog(@"Requests to make: %d", requests);
    
    //add all requests to the queue
    for (NSUInteger i = 0; i < requests; i++) {
        
        NSInteger offset = i*chunkSize;
        NSString *strUrl = [NSString stringWithFormat:builder,
                            [self getJoinedArrayByProp:@"chNum" arrayOffset:offset chunkSize:chunkSize],
                            [localDateString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                            [self getJoinedArrayByProp:@"chId" arrayOffset:offset chunkSize:chunkSize]
                            ];
        
        //NSLog(@"Request #%lu Fired", (unsigned long)i);
        
        NSURL *url = [NSURL URLWithString:strUrl];
        
        
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                           queue:_whatsPlayingQueue
                               completionHandler:^(NSURLResponse *response,
                                                   NSData *data,
                                                   NSError *connectionError)
         {
             
             if (data.length > 0 && connectionError == nil) {

                 NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                 
                 for (id channel in [json objectForKey: @"schedule"]) {
                     
                     
                     NSArray *channelSchedule = [channel objectForKey:@"schedules"];
                     NSString *chId = [[channel objectForKey:@"chId"] stringValue];
                     
                     int i;
                     for (i = 0; i < [channelSchedule count]; i++) {

                         id show = [channelSchedule objectAtIndex:i];
                         
                         NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
                         [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
                         NSDate *startDate = [dateFormatter dateFromString:show[@"airTime"]];
                         NSInteger duration = [show[@"duration"] intValue];
                         
                         bool isPlaying = [self isNowPlaying:startDate duration:duration];
                         bool isAdded = [[guide allKeys] containsObject:chId];
                         
                         if (isPlaying && !isAdded) {
                             
                             NSMutableDictionary *guideItem = [[NSMutableDictionary alloc] init];
                             
                             
                             if (show[@"programID"]) {
                                 guideItem[@"programID"] = show[@"programID"];
                             }
                             if (show[@"title"]) {
                                 guideItem[@"title"] = show[@"title"];
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
                             
                             guideItem[@"starts"] = startDate;
                             guideItem[@"ends"] = [startDate dateByAddingTimeInterval:duration*60];
                             
                             guideItem[@"upNext"] = @"Not Available";
                             if (i < [channelSchedule count]-1) {
                                 id nextShow = [channelSchedule objectAtIndex:i+1];
                                 guideItem[@"upNext"] = nextShow[@"title"];
                             }
                             
                             [guide setObject:guideItem forKey:chId];
                             
                         }
                         
                     }
                     
                     
                 }

             }
             completed++;
             
             if (completed > requests) {
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedGuide" object:guide];
             }
             
         }];
        
    }
}

- (NSString *)getJoinedArrayByProp:(NSString *)prop arrayOffset:(NSInteger)offset chunkSize:(NSInteger)size  {
    //returns a csv list of some property in _channels for url building
    NSMutableArray *outArray = [[NSMutableArray alloc] init];
    
    NSArray *keys = [_channels allKeys];
    NSUInteger totalPossible = [keys count];
    
    for (NSUInteger i = offset; i < totalPossible; i++) {
        id key = [keys objectAtIndex: i];
        id item = _channels[key];
        if (i <= (offset + size)) {
            [outArray addObject:[item[prop] stringValue]];
        }
    }
    
    return [outArray componentsJoinedByString:@","];
}

- (NSDate *)getHalfHourIncrement:(NSDate *)date {

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

- (BOOL)isNowPlaying:(NSDate *)startDate duration:(NSInteger)duration {
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    NSDate *endDate = [startDate dateByAddingTimeInterval:duration*60];
    [dateFormatter setTimeZone:[NSTimeZone defaultTimeZone]];
    NSDate *now = [[NSDate alloc] init];
    return ([endDate timeIntervalSinceDate:now] > 0);
}


@end
