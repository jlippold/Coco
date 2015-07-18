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
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    
    // Configure interface objects here.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedNowPlaying:)
                                                 name:@"messageUpdatedNowPlaying" object:nil];
    
    channels = [WatchKitCache loadAllChannels];
    currentDevice = [dtvDevices getCurrentDevice];

}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    [self refreshNowPlaying:nil];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

- (void) refreshNowPlaying:(id)sender {
    if (currentDevice) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *channelNum = [dtvCommands getChannelOnDevice:currentDevice];
            
            if ([channelNum isEqualToString:@""]) {
                [self setAsOffline];
            } else {
                
                dtvChannel *channel = [dtvChannels getChannelByNumber:[channelNum intValue] channels:channels];
                if (channel.identifier == 0) {
                    [self setAsOffline];
                } else {
                    [self.NowPlayingtitle setText:@"Loading..."];
                    [self.deviceLabel setText:[NSString stringWithFormat:@"%@: %d", currentDevice.name, channel.number]];
                    [self.channelImage setImage:[dtvChannel getImageForChannel:channel]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateNowPlaying:channel];
                    });
                }
            }
        });
    }
}

- (void) updateNowPlaying:(dtvChannel *) channel {
    dtvNowPlaying *np = [[dtvNowPlaying alloc] init];
    [np update:channel];
}

- (void) messageUpdatedNowPlaying:(NSNotification *)notification {
    [self setNowPlaying:notification.object];
}

- (void) setNowPlaying:(dtvNowPlaying *) np {
    if (!np) {
        return;
    }
    
    [self.timeRemaining setText:np.timeLeft];
    [self.synopsis setText:np.synopsis];
    
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
}
@end



