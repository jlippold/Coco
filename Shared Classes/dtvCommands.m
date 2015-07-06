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
#import "dtvCustomCommand.h"
#import "Util.h"

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

+ (NSMutableDictionary *) getCommandsForSidebar:(dtvDevice *) currentDevice {

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
    
    NSMutableArray *customs = [self loadSavedCustoms];
    for (dtvCustomCommand *command in customs) {
        if (!output[@"Customs"]) {
            [output setObject:[[NSMutableArray alloc] init] forKey:@"Customs"];
        }
        if ([command.networkName isEqualToString:currentDevice.ssid] &&
            [command.deviceName isEqualToString:currentDevice.name]) {
            
            [output[@"Customs"] addObject:command];
        }
    }
    
    return output;
}

+ (void)changeChannel:(dtvChannel *)channel device:(dtvDevice *)device  {
    NSLog(@"%@ set to channel %d", device.address, channel.number);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageSetNowPlayingChannel"
                                                        object:@(channel.number).stringValue];
    
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
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url
                                                  cachePolicy:1
                                              timeoutInterval:2];
    

    NSData* data = [NSURLConnection sendSynchronousRequest:request
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
        command.isCustomCommand = NO;
        [output addObject:command];
        
    }
    
    return output;
}

+ (void) sendCustomCommand:(dtvCustomCommand *)command {
     
    NSString *url = command.url;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    if ([[command.method uppercaseString] isEqualToString:@"GET"]) {
        if (![command.data isEqualToString:@""]) {
            url = [NSString stringWithFormat:@"%@?%@", url, command.data];
        }
    } else {
        [request setHTTPMethod:[command.method uppercaseString]];
        if (![command.data isEqualToString:@""]) {
            
            [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[command.data length]]
           forHTTPHeaderField:@"Content-length"];
            
            [request setHTTPBody:[command.data dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    request.URL = [NSURL URLWithString:url];

    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:
     ^(NSURLResponse *response, NSData *data, NSError *error) {
         if (!error && command.onCompleteURIScheme ) {
            #ifndef WATCH_KIT_EXTENSION_TARGET
            #else
             NSURL *uri = [NSURL URLWithString:command.onCompleteURIScheme];
             [[UIApplication sharedApplication] openURL:uri];
            #endif
             
         }
     }];

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

+ (void) loadCustomCommandsFromUrl:(NSString *) strUrl {
    //@"https://jed.bz/settings.json"
    
    NSURL *url = [NSURL URLWithString:strUrl];
    NSURLResponse* response;
    NSError *connectionError;
    NSData* data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url]
                                         returningResponse:&response error:&connectionError];
   
    NSMutableArray *output = [[NSMutableArray alloc] init];
    int networkCount = 0;
    int commandCount = 0;
    NSString *errMessage;

    if (data.length > 0 && connectionError == nil) {
        NSError *jsonError;
        NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (!jsonError){
            for (id item in json) {
                if (item[@"networkName"] && item[@"deviceName"] && item[@"commands"]) {
                    
                    if ([item[@"networkName"] isKindOfClass:[NSString class]] &&
                        [item[@"deviceName"] isKindOfClass:[NSString class]]) {
                        
                        NSString *networkName = item[@"networkName"];
                        NSString *deviceName = item[@"deviceName"];
                        networkCount++;
                        
                        if ([[item valueForKey:@"commands"] isKindOfClass:[NSArray class]]) {
                            NSArray *commands = item[@"commands"];
                            for (id command in commands) {
                                if ([self isValidJsonCommand:command]) {
                                    
                                    dtvCustomCommand *customCommand = [[dtvCustomCommand alloc] init];
                                    
                                    customCommand.isCustomCommand = YES;
                                    customCommand.networkName = networkName;
                                    customCommand.deviceName = deviceName;
                                    customCommand.url = command[@"url"];
                                    customCommand.method = command[@"method"];
                                    customCommand.data = command[@"data"];
                                    customCommand.buttonIndex = command[@"buttonIndex"];
                                    customCommand.commandDescription = command[@"title"];
                                    customCommand.abbreviation = command[@"abbreviation"];
                                    customCommand.onCompleteURIScheme = command[@"onCompleteURIScheme"];
                                    customCommand.sideBarCategory = @"Customs";
                                    customCommand.sideBarSortIndex = command[@"0"];
                                    
                                    [output addObject:customCommand];
                                    commandCount++;
                                }
                            }
                        }
                    }
                }
            }
        } else {
            errMessage = @"Error Importing: Invalid json";
        }
    } else {
        errMessage = @"Error Importing: No data found";
    }
    
    [self saveCustoms:output];
    if (errMessage) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageImportedCustomCommands" object:errMessage];
    } else {
        if (commandCount == 0) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageImportedCustomCommands" object:@"No valid commands found at this url"];
        } else {
            
            errMessage = [NSString stringWithFormat:@"Imported %d command(s) for %d devices(s).",
                          commandCount, networkCount];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageImportedCustomCommands" object:errMessage];
            
        }
    }
    
}

+ (void)saveCustoms:(NSMutableArray *) customs {
    if (customs) {
        [Util saveObjectToDisk:customs key:@"customs"];
    }
}

+ (NSMutableArray *) loadSavedCustoms {
    
    NSMutableArray *customs = (NSMutableArray *)[Util loadObjectFromDisk:@"customs"
                                                             objectType:@"NSMutableArray"];
    return customs;
}

+ (BOOL) isValidJsonCommand:(id) item {
    BOOL valid = false;
    if (item[@"url"] &&
        item[@"method"] &&
        item[@"data"] &&
        item[@"buttonIndex"] &&
        item[@"title"] &&
        item[@"abbreviation"]) {
        
        if ([item[@"url"] isKindOfClass:[NSString class]] &&
            [item[@"method"] isKindOfClass:[NSString class]] &&
            [item[@"data"] isKindOfClass:[NSString class]] &&
            [item[@"buttonIndex"] isKindOfClass:[NSNumber class]] &&
            [item[@"title"] isKindOfClass:[NSString class]] &&
            [item[@"abbreviation"] isKindOfClass:[NSString class]]) {
            
            valid = true;
        }
        
    }
    return valid;
}

@end
