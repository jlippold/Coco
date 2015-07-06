//
//  channels.h
//  dtvRemote
//
//  Created by Jed Lippold on 3/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//  Returns Channels for a location

#import <Foundation/Foundation.h>
#import "dtvChannel.h"

@interface dtvChannels : NSObject

+ (void)save:(NSMutableDictionary *)channels;
+ (NSMutableDictionary *) load:(BOOL)showBlocks;

+ (void) getLocationsForZipCode:(NSString *)zipCode;
+ (void) populateChannels:(NSMutableDictionary *)location;
+ (void) downloadChannelImages:(NSMutableDictionary *)channels;
+ (NSMutableArray *) loadBlockedChannels:(NSMutableDictionary *)channels;
+ (NSMutableArray *) loadFavoriteChannels:(NSMutableDictionary *)channels;
+ (void)saveBlockedChannels:(NSMutableArray *) blockedChannels;
+ (void)saveFavoriteChannels:(NSMutableArray *) favortiteChannels;


+ (dtvChannel *)getChannelByNumber:(int)number channels:(NSMutableDictionary *)channels;
+ (dtvChannel *)getChannelByCallSign:(NSString *)callSign channels:(NSMutableDictionary *)channels;
+ (NSMutableDictionary *) sortChannels:(NSMutableDictionary *)channels sortBy:(NSString *)sort;
+ (NSString *) DTVCookie;

@end
