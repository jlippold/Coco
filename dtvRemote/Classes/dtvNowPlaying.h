//
//  dtvNowPlaying.h
//  dtvRemote
//
//  Created by Jed Lippold on 6/4/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "dtvChannel.h"

@interface dtvNowPlaying : NSObject

@property (nonatomic, strong) dtvChannel *channel;
@property (nonatomic, strong) NSString *programId;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *synopsis;
@property (nonatomic, strong) NSString *rating;
@property (nonatomic, strong) NSString *timeLeft;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIImage *channelImage;
@property (nonatomic, strong) NSMutableArray *colors;
@property BOOL HD;
@property double stars;
@property double percentComplete;

- (void) update:(dtvChannel *)channel;

@end