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

+ (NSMutableDictionary *) getCommandsForNumberPad {
    NSMutableDictionary *output = [[NSMutableDictionary alloc] init];
    NSArray *commands = [self getCommands];
    
    for (dtvCommand *command in commands) {
        if (command.showInNumberPad) {
            if (!output[command.numberPadPageName]) {
                [output setObject:[[NSMutableArray alloc] init] forKey:command.numberPadPageName];
            }
            
            [output[command.numberPadPageName] addObject:command];
        }
    }
    
    return output;
}

+ (NSMutableDictionary *) getCommandsForSidebar {

    NSMutableDictionary *output = [[NSMutableDictionary alloc] init];
    NSArray *commands = [self getCommands];
    
    for (dtvCommand *command in commands) {
        if (command.showInSideBar == YES) {
            if (!output[command.sideBarCategory]) {
                [output setObject:[[NSMutableArray alloc] init] forKey:command.sideBarCategory];
            }
            
            [output[command.sideBarCategory] addObject:command];
        }
    }
    
    return output;
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

+ (dtvCommand *) getCommandAtnumberPadPagePosition:(NSMutableDictionary *) commands
                                              page:(NSString *)page
                                          position:(NSString *)position {
    
    dtvCommand *command;
    if (commands[page]) {
        for (dtvCommand *thisCommand in commands[page]) {
            NSString *thisPosition = thisCommand.numberPadPagePosition;
            if ([position isEqualToString:thisPosition]) {
                command = thisCommand;
            }
        }
    }

    return command;
}

+ (NSArray *) getCommands {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"commands" withExtension:@"plist"];
    NSArray *commands = [[NSDictionary dictionaryWithContentsOfURL:url] objectForKey: @"Commands"];
    
    NSMutableArray *output = [[NSMutableArray alloc] init];
    
    for (NSMutableDictionary *entry in commands) {
        
        dtvCommand *command = [[dtvCommand alloc] init];
        command.dtvCommandText = entry[@"dtvCommandText"];
        command.commandDescription = entry[@"commandDescription"];
        command.sideBarCategory = entry[@"sideBarCategory"];
        command.sideBarSortIndex = entry[@"sideBarSortIndex"];
        command.showInNumberPad = [entry[@"showInNumberPad"] boolValue];
        command.showInSideBar = [entry[@"showInSideBar"] boolValue];
        command.numberPadPagePosition = entry[@"numberPadPagePosition"];
        command.numberPadPageName = entry[@"numberPadPageName"];
        command.shortName = entry[@"shortName"];

        [output addObject:command];
        
    }
    
    return output;
}

+ (BOOL) sendCommand:(NSString *)command device:(dtvDevice *)device {
    
    if (!device) {
        NSLog(@"You must choose a device, llamah");
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
