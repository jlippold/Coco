//
//  channels.h
//  dtvRemote
//
//  Created by Jed Lippold on 3/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//  Returns Channels for a location

#import <Foundation/Foundation.h>

@interface Channels : NSObject

@property (nonatomic, strong) NSOperationQueue *channelImagesQueue;

- (id)init;
- (void)save:(NSMutableDictionary *) channelList;
- (NSMutableDictionary *)loadChannels;
- (void) populateChannels:(NSMutableDictionary *)location;

@end
