//
//  SharedVars.m
//  dtvRemote
//
//  Created by Jed Lippold on 7/18/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "SharedVars.h"
#import "dtvChannels.h"
#import "dtvCommands.h"
#import "dtvDevices.h"

@implementation SharedVars

@synthesize channels;
@synthesize favoriteChannels;
@synthesize favoriteCommands;
@synthesize currentDevice;


+ (SharedVars*) sharedInstance {
    static SharedVars *myInstance = nil;
    if (myInstance == nil) {
        myInstance = [[[self class] alloc] init];
        
        myInstance.currentDevice = [dtvDevices getCurrentDevice];
        myInstance.channels = [dtvChannels load:NO];
        myInstance.favoriteChannels = [dtvChannels loadFavoriteChannels:myInstance.channels];
        myInstance.favoriteCommands = [dtvCommands getCommandArrayOfFavorites:myInstance.currentDevice];
    }
    return myInstance;
}

@end
