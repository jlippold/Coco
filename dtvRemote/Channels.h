//
//  channels.h
//  dtvRemote
//
//  Created by Jed Lippold on 3/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//  Returns Channels for a location

#import <Foundation/Foundation.h>

@interface Channels : NSObject

+ (void)save:(NSMutableDictionary *) channelList;
+ (NSMutableDictionary *) load:(BOOL)showBlocks;

+ (void) getLocationsForZipCode:(NSString *)zipCode;
+ (void) populateChannels:(NSMutableDictionary *)location;
+ (void) downloadChannelImages:(NSMutableDictionary *)channelList;
+ (NSMutableArray *) loadBlockedChannels:(NSMutableDictionary *)channelList;
+ (void)saveBlockedChannels:(NSMutableArray *) blockedChannels;
+ (NSMutableDictionary *) addChannelCategoriesFromGuide:(NSMutableDictionary *)guide
                                               channels:(NSMutableDictionary *)channels;

+ (NSString *)getChannelIdForChannelNumber:(NSString *)chNum channels:(NSMutableDictionary *)channels;
+ (NSString *)getChannelIdForChannelCallSign:(NSString *)callSign channels:(NSMutableDictionary *)channels;
+ (NSMutableDictionary *) sortChannels:(NSMutableDictionary *)channels sortBy:(NSString *)sort;
+ (NSString *) DTVCookie;

@end
