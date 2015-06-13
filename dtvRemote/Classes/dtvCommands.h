//
//  Commands.h
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "dtvChannel.h"
#import "dtvDevice.h"
#import "dtvCommand.h"
#import "dtvCustomCommand.h"

@interface dtvCommands : NSObject

+ (void)changeChannel:(dtvChannel *)channel device:(dtvDevice *)device;
+ (NSString *)getChannelOnDevice:(dtvDevice *)device;
+ (BOOL) sendCommand:(NSString *)command device:(dtvDevice *)device;
+ (void) sendCustomCommand:(dtvCustomCommand *)command;
+ (NSMutableDictionary *) getCommandsForSidebar:(dtvDevice *) currentDevice;
+ (NSMutableDictionary *) getCommandsForNumberPad;
+ (void) loadCustomCommandsFromUrl:(NSString *) strUrl;
+ (dtvCommand *) getCommandAtnumberPadPagePosition:(NSMutableDictionary *) commands
                                              page:(NSString *)page
                                          position:(NSString *)position;
@end


