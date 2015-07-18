//
//  WatchKitCache.m
//  dtvRemote
//
//  Created by Jed Lippold on 7/14/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "WatchKitCache.h"
#import "dtvChannels.h"
#import "dtvChannel.h"
#import <WatchKit/WatchKit.h>
#import "Util.h"

@implementation WatchKitCache

+ (NSMutableDictionary *) loadChannels {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *keyName = @"channels";
    NSData *data = [defaults objectForKey:keyName];

    if ( data ) {
        return [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
    } else {
        NSMutableDictionary *channels = [dtvChannels load:NO];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:channels];
        [defaults setObject:data forKey:keyName];
        [defaults synchronize];
        return channels;
    }
}

+ (NSMutableDictionary *) loadAllChannels {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *keyName = @"allChannels";
    NSData *data = [defaults objectForKey:keyName];
    
    if ( data ) {
        return [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
    } else {
        NSMutableDictionary *channels = [dtvChannels load:YES];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:channels];
        [defaults setObject:data forKey:keyName];
        [defaults synchronize];
        return channels;
    }
}
@end
