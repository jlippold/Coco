//
//  Guide.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "Guide.h"

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
    
    ///This should only post complete when all requests are completed
    
    if ([[_channels allKeys] count] == 0) {
        return;
    }
    
    [_whatsPlayingQueue cancelAllOperations];
    

    NSDate *dt = [NSDate date];
    if (_guideTime != nil) {
        dt = _guideTime;
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
    NSString *localDateString = [dateFormatter stringFromDate:dt];
    
    //build a base URL for all now playing requests
    NSString *builder = @"https://www.directv.com/json/channelschedule";
    builder = [builder stringByAppendingString:@"?channels=%@"];
    builder = [builder stringByAppendingString:@"&startTime=%@"];
    builder = [builder stringByAppendingString:@"&hours=4"];
    builder = [builder stringByAppendingString:@"&chIds=%@"];
    
    NSLog(@"Base URL: %@", builder);
    
    
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
                                 if ([schedule count]> 0) {
                                     NSDictionary *nowPlaying = schedule[0];
                                     if (nowPlaying[@"title"]) {
                                         NSMutableDictionary *subdict = [_channels[chId] mutableCopy];
                                         subdict[@"title"] = nowPlaying[@"title"];
                                         _channels[chId] = subdict;
                                     }
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


@end
