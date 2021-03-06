//
//  GlanceInterfaceController.m
//  dtvRemote
//
//  Created by Jed Lippold on 7/16/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "GlanceInterfaceController.h"
#import "dtvDevice.h"
#import "dtvDevices.h"
#import "dtvNowPlaying.h"
#import "dtvCommands.h"
#import "dtvChannels.h"
#import "dtvChannel.h"
#import "WatchKitCache.h"

@interface GlanceInterfaceController ()

@end

@implementation GlanceInterfaceController {
    NSMutableDictionary *channels;
    dtvDevice *currentDevice;
    NSTimer *timer;
    NSString *currentProgramId;
    BOOL refreshing;
    dtvNowPlaying *nowPlaying;
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    
    // Configure interface objects here.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedNowPlaying:)
                                                 name:@"messageUpdatedNowPlaying" object:nil];
    
    timer = [[NSTimer alloc] init];
    timer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                             target:self
                                           selector:@selector(onTimerFire:)
                                           userInfo:nil
                                            repeats:YES];
    nowPlaying = [[dtvNowPlaying alloc] init];
    channels = [WatchKitCache loadAllChannels];
    refreshing = NO;
    [self refreshNowPlaying:nil];

}

- (void) onTimerFire:(id)sender {
    [self refreshNowPlaying:nil];
}


- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedNowPlaying:)
                                                 name:@"messageUpdatedNowPlaying" object:nil];
    
    refreshing = NO;
    [self refreshNowPlaying:nil];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

}

- (void) refreshNowPlaying:(id)sender {
    if (refreshing) {
        return;
    }
    refreshing = YES;
    
    currentDevice = [dtvDevices getCurrentDevice];
    if (currentDevice) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *channelNum = @"";
            channelNum = [dtvCommands getChannelOnDevice:currentDevice];
            
            if ([channelNum isEqualToString:@""]) {
                [self setAsOffline];
            } else {
                
                dtvChannel *channel = [dtvChannels getChannelByNumber:[channelNum intValue] channels:channels];
                if (channel.identifier == 0) {
                    [self setAsOffline];
                } else {
                    
                    [self.deviceLabel setText:[NSString stringWithFormat:@"%@ ch:%d", currentDevice.name, channel.number]];
                    [self.channelImage setImage:[dtvChannel getImageForChannel:channel]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateNowPlaying:channel];
                        refreshing = NO;
                    });
                }
            }
        });
    } else {
        [self setAsNoDevice];
    }
}

- (void) updateNowPlaying:(dtvChannel *) channel {
    [nowPlaying update:channel];
}

- (void) messageUpdatedNowPlaying:(NSNotification *)notification {
    [self setNowPlaying:notification.object];
}

- (void) setNowPlaying:(dtvNowPlaying *) np {
    if (!np) {
        return;
    }
    
    [self.timeRemaining setText:np.timeLeft];
    
    if ([currentProgramId isEqualToString:np.programId]) {
        return;
    } else {
        [self clearNowPlaying];
    }
    
    currentProgramId = np.programId;
    
    [self.synopsis setText:np.synopsis];
    [self.NowPlayingtitle setText:np.title];
    
    [UIView animateWithDuration:0.25
                     animations:^{
                         self.boxCover.alpha = 0.0;
                     } completion:
     ^(BOOL finished) {
         
         [self.NowPlayingtitle setText:np.title];
         [self.boxCover setImage:np.image];

         [UIView animateWithDuration:0.25
                          animations:^{
                              self.boxCover.alpha = 1.0;
                          } completion:nil];
         
     }];
}


- (void) setAsOffline {
    [self.NowPlayingtitle setText:@"Offline"];
    [self clearDeviceAndChannel];
    [self clearNowPlaying];
}

- (void) setAsNoDevice {
    [self.NowPlayingtitle setText:@"No Device Found"];
    [self clearDeviceAndChannel];
    [self clearNowPlaying];
}

- (void) clearDeviceAndChannel {
    [self.deviceLabel setText:@""];
    [self.channelImage setImage:nil];
    refreshing = NO;
}

- (void) clearNowPlaying {
    [self.synopsis setText:@""];
    [self.timeRemaining setText:@""];
    [self.boxCover setImage:nil];
}

@end



