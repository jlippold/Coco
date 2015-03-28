//
//  Commands.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "Commands.h"

@implementation Commands

+ (void)changeChannel:(NSString *)chNum device:(NSMutableDictionary *)client  {
    NSLog(@"%@ set to channel %@", client, chNum);
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://%@:8080/tv/tune?major=%@&%@",
                   client[@"address"], chNum, client[@"appendage"] ]];
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
             NSLog(@"Channel change error");
         }
         
     }];
}

+ (void)whatsOnDevice:(NSDictionary *) client {
    
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://%@:8080/tv/getTuned?%@",
                   client[@"address"], client[@"appendage"] ]];
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
