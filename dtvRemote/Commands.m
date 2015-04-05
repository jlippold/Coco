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
    
    if (client) {
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
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageSetNowPlayingChannel" object:chNum];
    }

}

+ (NSString *)getChannelOnClient:(NSDictionary *) client {
    
    NSString *chNum = @"";
                                 
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://%@:8080/tv/getTuned?%@",
                   client[@"address"], client[@"appendage"] ]];
    
    NSURLResponse* response;
    NSError *connectionError;
    NSData* data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url]
                                           returningResponse:&response error:&connectionError];
    
    if (data.length > 0 && connectionError == nil) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        NSNumber *statusCode = json[@"status"][@"code"];
        if ([statusCode isEqualToNumber:[NSNumber numberWithInt:200]]){
            chNum = [json[@"major"] stringValue];
        }
    }
    
    return chNum;
}

+ (BOOL) sendCommand:(NSString *)command client:(NSDictionary *) client {

    if ([[client allKeys] count] == 0) {
        NSLog(@"You must choose a device, llamah");
        return NO;
    }
    
    NSArray *validCommands = [NSArray arrayWithObjects:
                      @"power",@"poweron",@"poweroff",@"format",@"pause",@"rew",@"replay",@"stop",@"advance",@"ffwd",@"record",@"play",@"guide",@"active",@"list",@"exit",@"back",@"menu",@"info",@"up",@"down",@"left",@"right",@"select",@"red",@"green",@"yellow",@"blue",@"chanup",@"chandown",@"prev",@"0",@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"dash",@"enter", nil];
    
    if (![validCommands containsObject:command]) {
        NSLog(@"Unknown Command: %@", command);
        return NO;
    }
    
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://%@:8080/remote/processKey?key=%@&%@",
                   client[@"address"], command, client[@"appendage"] ]];
    
    NSURLResponse* response;
    NSError *connectionError;
    NSData* data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url]
                                         returningResponse:&response error:&connectionError];
    
    if (data.length > 0 && connectionError == nil) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        NSNumber *statusCode = json[@"status"][@"code"];
        if ([statusCode isEqualToNumber:[NSNumber numberWithInt:200]]){
            NSLog(@"Command %@ sent", command);
            return YES;
        } else {
            return NO;
        }
    }
    
    return NO;
}

@end
