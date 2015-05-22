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
        command.isCustomCommand = NO;
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
                                    customCommand.title = command[@"title"];
                                    customCommand.abbreviation = command[@"abbreviation"];
                                    customCommand.successStatusCode = command[@"successStatusCode"];
                                    
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
            
            errMessage = [NSString stringWithFormat:@"Imported %d command(s) for %d network(s).",
                          commandCount, networkCount];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageImportedCustomCommands" object:errMessage];
            
        }
    }
    
}

+ (void)saveCustoms:(NSMutableArray *) customs {
    NSString *key = @"customs";
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    if (customs != nil) {
        [dataDict setObject:customs forKey:key];
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    [NSKeyedArchiver archiveRootObject:dataDict toFile:filePath];
}

+ (NSMutableArray *) loadSavedCustoms {
    
    NSMutableArray *customs = [[NSMutableArray alloc] init];
    NSString *key = @"customs";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([savedData objectForKey:key] != nil) {
            customs = [savedData objectForKey:key];
        }
    }
    return customs;
}

+ (BOOL) isValidJsonCommand:(id) item {
    BOOL valid = false;
    if (item[@"url"] &&
        item[@"method"] &&
        item[@"data"] &&
        item[@"buttonIndex"] &&
        item[@"title"] &&
        item[@"abbreviation"] &&
        item[@"successStatusCode"]) {
        
        if ([item[@"url"] isKindOfClass:[NSString class]] &&
            [item[@"method"] isKindOfClass:[NSString class]] &&
            [item[@"data"] isKindOfClass:[NSString class]] &&
            [item[@"buttonIndex"] isKindOfClass:[NSNumber class]] &&
            [item[@"title"] isKindOfClass:[NSString class]] &&
            [item[@"abbreviation"] isKindOfClass:[NSString class]] &&
            [item[@"successStatusCode"] isKindOfClass:[NSNumber class]]) {
            
            valid = true;
        }
        
    }
    return valid;
}

@end
