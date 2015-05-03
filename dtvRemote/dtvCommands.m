//
//  Commands.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "dtvCommands.h"
#import "dtvCommand.h"
#import "dtvChannel.h"
#import "dtvDevice.h"

@implementation dtvCommands


- (id) init {
    return self;
}

+ (NSArray *) getArrayOfCommands {

    NSArray *someList = [NSArray arrayWithObjects: @"power",@"poweron",@"poweroff",@"format",@"pause",@"rew",@"replay",@"stop",@"advance",@"ffwd",@"record",@"play",@"guide",@"active",@"list",@"exit",@"back",@"menu",@"info",@"up",@"down",@"left",@"right",@"select",@"red",@"green",@"yellow",@"blue",@"chanup",@"chandown",@"prev",@"0",@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"dash",@"enter", nil];
    
    NSMutableArray *someList2 = [[NSMutableArray alloc] init];
    for (NSString *val in someList) {
        dtvCommand *command = [[dtvCommand alloc] init];
        command.description = val;
        command.action = val;
        [someList2 addObject:command];
    }
    return someList2;

}

+ (void)changeChannel:(dtvChannel *)channel device:(dtvDevice *)device  {
    NSLog(@"%@ set to channel %d", device.address, channel.number);
    
    if (device) {
        NSURL *url = [NSURL URLWithString:
                      [NSString stringWithFormat:@"http://%@:8080/tv/tune?major=%d&%@",
                       device.address, channel.number, device.appendage]];
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
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageSetNowPlayingChannel"
                                                            object:@(channel.number).stringValue];
    }

}

+ (NSString *)getChannelOnDevice:(dtvDevice *)device {
    
    NSString *chNum = @"";
                                 
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://%@:8080/tv/getTuned?%@",
                   device.address, device.appendage ]];
    
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

+ (BOOL) sendCommand:(NSString *)command device:(dtvDevice *)device {

    if (device) {
        NSLog(@"You must choose a device, llamah");
        return NO;
    }
    
    NSArray *commands = [self getArrayOfCommands];

    if (![commands containsObject:command]) {
        NSLog(@"Unknown Command: %@", command);
        return NO;
    }
    
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://%@:8080/remote/processKey?key=%@&%@",
                   device.address, command, device.appendage ]];
    
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
