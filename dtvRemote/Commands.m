//
//  Commands.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "Commands.h"

@implementation Commands


-(id) init {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageChangeChannel:)
                                                 name:@"messageChangeChannel" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageRefreshNowPlaying:)
                                                 name:@"messageRefreshNowPlaying" object:nil];
    
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) messageChangeChannel:(NSNotification *)notification {
    NSDictionary *obj = [notification object];
    [self changeChannel:obj[@"chNum"] device:obj[@"device"]];
}

- (void) messageRefreshNowPlaying:(NSNotification *)notification {
    NSDictionary *device = [notification object];
    [self whatsOn:device];
}


-(void)changeChannel:(NSString *)chNum device:(NSMutableDictionary *)device  {
    NSLog(@"%@ set to channel %@", device, chNum);
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://%@:8080/tv/tune?major=%@&%@",
                   device[@"address"], chNum, device[@"appendage"] ]];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil) {
             //slight delay
             dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.5);
             dispatch_after(delay, dispatch_get_main_queue(), ^(void){
                [[NSNotificationCenter defaultCenter] postNotificationName:@"messageChannelChanged" object:nil];
             });
             
         } else {
             
         }
         
     }];
}

-(void)whatsOn:(NSDictionary *) device {
    
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://%@:8080/tv/getTuned?%@",
                   device[@"address"], device[@"appendage"] ]];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil) {
             NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
             NSNumber *statusCode = json[@"status"][@"code"];
             if ([statusCode isEqualToNumber:[NSNumber numberWithInt:200]]){
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedNowPlaying" object:json[@"major"]];
             }
         }
         
     }];
    
 
}
@end
