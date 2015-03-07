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
    int requests = ceil((double)[[_channels allKeys] count]/chunkSize);
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
                 //update channelList with currently playing title
                 NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                 if (json[@"schedule"]) {
                     for (id item in [json objectForKey: @"schedule"]) {
                         if (item[@"chId"] && item[@"schedules"]) {
                             NSString *chId = [NSString stringWithFormat:@"%05ld", (long)[[item objectForKey:@"chNum"] integerValue]];
                             
                             if (_channels[chId]) {
                                 
                                 NSArray *schedule = [item objectForKey:@"schedules"];
                                 if ([schedule count] > 0) {
                                     
                                     NSDictionary *nowPlaying = schedule[0];
                                     NSMutableDictionary *subdict = [_channels[chId] mutableCopy];
                                     
                                     if (nowPlaying[@"programID"]) {
                                         subdict[@"showId"] = nowPlaying[@"programID"];
                                     }
                                     if (nowPlaying[@"title"]) {
                                         subdict[@"showTitle"] = nowPlaying[@"title"];
                                     }
                                     if (nowPlaying[@"primaryImageUrl"]) {
                                         subdict[@"showCover"] = nowPlaying[@"primaryImageUrl"];
                                     }
                                     if (nowPlaying[@"mainCategory"]) {
                                         subdict[@"showCategory"] = nowPlaying[@"mainCategory"];
                                     }
                                     if (nowPlaying[@"hd"]) {
                                         subdict[@"showHD"] = nowPlaying[@"hd"];
                                     }
                                     if (nowPlaying[@"duration"] && nowPlaying[@"airTime"]) {
                                         
                                         NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
                                         [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
                                         NSDate *startDate = [dateFormatter dateFromString:nowPlaying[@"airTime"]];
                                         NSInteger duration = [nowPlaying[@"duration"] intValue];
                                         
                                         if (startDate && duration) {
                                             
                                             NSDate *endDate = [startDate dateByAddingTimeInterval:duration*60];
                                             [dateFormatter setTimeZone:[NSTimeZone defaultTimeZone]];
                                             NSDate *now = [[NSDate alloc] init];
                                             
                                             double completed = [now timeIntervalSinceDate:startDate] / 60;
                                             double percentage = (completed/duration);
                                             double whole = percentage * 100.0;
                                             NSUInteger rounded = floor((whole+10)/20) * 20;
                                             double eights = percentage * 8;
                                             NSUInteger roundedEights = (NSInteger) roundf(eights);
                                             
                                             /*
                                             NSLog(@"completed: %lu duration: %lu percentage: %lu rounded: %lu eights: %lu" ,
                                                   (unsigned long)completed,
                                                   (unsigned long)duration,
                                                   (unsigned long)percentage,
                                                   rounded,
                                                   roundedEights);
                                             
                                             NSLog(@"Start: %@ End: %@ Completed %ld/%lD", startDate, endDate, (long)completed, (long)duration);
                                             */
                                             
                                             //needs to ignore shows that havent started? (why are there negatives here?)
                                             if (roundedEights < 8) {
                                                 subdict[@"showProgress"] =
                                                    [NSString stringWithFormat:@"progress%lu.png", roundedEights];
                                             }

                                         }

                                     }
                                     _channels[chId] = subdict;
                                 }
                             }
                         }
                     }
                     
                 }
             }
             
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedGuide" object:_channels];
             
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


@end
