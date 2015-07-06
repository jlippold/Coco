//
//  dtvChannels.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//  Returns Channels for a location

#import "dtvChannels.h"
#import "dtvChannel.h"
#import "Util.h"

@implementation dtvChannels


+ (void)save:(NSMutableDictionary *) channels {
    if (channels) {
        [Util saveObjectToDisk:channels key:@"channels"];
    }
}

+ (NSMutableDictionary *) load:(BOOL)showBlocks {

    NSMutableDictionary *channels = (NSMutableDictionary *)[Util loadObjectFromDisk:@"channels" objectType:@"NSMutableDictionary"];

    //remove blocks
    if (!showBlocks) {
        NSMutableArray *blocks = [self loadBlockedChannels:channels];
        for (id block in blocks) {
            [channels removeObjectForKey:block];
        }
        //NSLog(@"Removed: %lu", (unsigned long)[blocks count]);
    }
    
    return channels;
}

+ (NSMutableArray *) loadBlockedChannels:(NSMutableDictionary *)channels {
    
    NSMutableArray *blocks = (NSMutableArray *)[Util loadObjectFromDisk:@"blockedChannels"
                                                             objectType:@"NSMutableArray"];

    
    if ([blocks count] == 0) {
        NSArray *blockCallSigns = [NSArray arrayWithObjects:
                                   @"CINE", @"CINEHD", @"SONIC", @"PPV", @"DTV",
                                   @"BSN", @"NHL", @"MLS", @"PPVHD", @"IACHD",
                                   @"CINE1", @"CINE2", @"CINE3", @"IDEA", @"BEST",
                                   @"MALL", @"SALE", @"NEW", @"AAN", @"EPL", @"HBOLHD"
                                   @"STZEHD",@"STZWHD",@"STZKHD",@"STZCHD",@"SEDGHD",@"SBLKHD",@"SCINHD",
                                   @"UEFA", @"RGBY", @"EPL", @"MAS", @"NBA", @"PTNW", @"ACT", nil];
        
        NSArray *blockCategories = [NSArray arrayWithObjects:
                                   @"Foreign", @"Religious", @"Shopping", @"Sports", @"Uncategorized", @"(null)", nil];
        
        for (NSString *key in channels) {
            dtvChannel *channel = [channels objectForKey:key];
            
            if (channel.adult ||
                [blockCallSigns containsObject:[channel.callsign uppercaseString]] ||
                [blockCategories containsObject:channel.category]) {
                [blocks addObject:key];
            }
            
        }
    }
    return blocks;
}
+ (void)saveBlockedChannels:(NSMutableArray *) blockedChannels {
    if (blockedChannels) {
        [Util saveObjectToDisk:blockedChannels key:@"blockedChannels"];
    }
}

+ (NSMutableArray *) loadFavoriteChannels:(NSMutableDictionary *)channels {

    NSMutableArray *favs = (NSMutableArray *)[Util loadObjectFromDisk:@"favoriteChannels"
                                                             objectType:@"NSMutableArray"];
    if ([favs count] == 0) {
        NSArray *favCallSigns = [NSArray arrayWithObjects:
                                   @"COM", @"CNN", @"HBOE", @"MTV", nil];
        
        for (NSString *key in channels) {
            dtvChannel *channel = [channels objectForKey:key];
            
            if ([favCallSigns containsObject:[channel.callsign uppercaseString]]) {
                [favs addObject:key];
            }
            
        }
    }
    return favs;
}

+ (void)saveFavoriteChannels:(NSMutableArray *) favoriteChannels {
    if (favoriteChannels) {
        [Util saveObjectToDisk:favoriteChannels key:@"favoriteChannels"];
    }
}

+ (void) getLocationsForZipCode:(NSString *)zipCode {
    
    //get valid locations for zip code
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.directv.com/json/zipcode/%@", zipCode]];
    
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *error)
     {
         NSMutableDictionary *locations = [[NSMutableDictionary alloc] init];
         
         if (error) {
             [[NSNotificationCenter defaultCenter] postNotificationName:@"messageAPIDown" object:nil];
             [[NSNotificationCenter defaultCenter] postNotificationName:@"messagePromptForZipCode" object:nil];
         } else {
             NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
             if (json[@"zipCodes"]) {
                 for (id item in [json objectForKey: @"zipCodes"]) {
                     NSString *zip = [item objectForKey:@"zipCode"];
                     NSDictionary *dictionary = @{@"zipCode" : [item objectForKey:@"zipCode"],
                                                  @"state" : [item objectForKey:@"state"],
                                                  @"countyName" : [item objectForKey:@"countyName"],
                                                  @"timeZone": item[@"timeZone"][@"tzId"] };
                     [locations setObject:dictionary forKey:zip];
                 }
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedLocations" object:locations];
                 
             } else {
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageAPIDown" object:nil];
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messagePromptForZipCode" object:nil];
             }
         }
         
     }];
    
}

+ (void) populateChannels:(NSMutableDictionary *)location {
    NSLog(@"%@",location);
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"categories" withExtension:@"plist"];
    NSDictionary *categories = [[NSDictionary dictionaryWithContentsOfURL:url] objectForKey: @"Categories"];

    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.directv.com/json/channels"]];
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    NSString *cookie = [NSString stringWithFormat:@"dtve-prospect-state=%@; dtve-prospect-zip=%@%%7C%@;",
                        location[@"state"], location[@"zipCode"],
                        [location[@"timeZone"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    [self saveDTVCookie:cookie];
    
    [mutableRequest addValue:cookie forHTTPHeaderField:@"Cookie"];
    
    request = [mutableRequest copy];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:
     ^(NSURLResponse *response, NSData *data, NSError *error) {
         
         NSMutableDictionary *channels = [[NSMutableDictionary alloc] init];
         
         if (error) {
             
             [[NSNotificationCenter defaultCenter] postNotificationName:@"messageAPIDown" object:nil];
             [[NSNotificationCenter defaultCenter] postNotificationName:@"messagePromptForZipCode" object:nil];
             
         } else {
             
             NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
             if (json[@"channels"]) {
                 
                 NSMutableDictionary *deDuplicate = [[NSMutableDictionary alloc] init];
                 
                 for (id item in [json objectForKey: @"channels"]) {
                     
                     id chId = [item objectForKey:@"chId"];
                     id chNum = [item objectForKey:@"chNum"];
                     
                     if (deDuplicate[chNum]) {
                         //the channel has already been added
                         if ([[[item objectForKey:@"chHd"] stringValue] isEqualToString:@"1"]) {
                             //and new channel is in HD, overwrite the old with the new
                             [deDuplicate setObject:chId forKey:chNum];
                         }
                     } else {
                         //new channel
                         [deDuplicate setObject:chId forKey:chNum];
                     }
                     
                     NSString *category = @"Uncategorized";
                     NSString *callsign = [[item objectForKey:@"chCall"] uppercaseString];
                     if (categories[callsign]) {
                         category = categories[callsign];
                     }
                     
                     if ([category isEqualToString:@"Uncategorized"] &&
                         [[[item objectForKey:@"chCall"] substringFromIndex:1] isEqualToString:@"W"]) {
                         category = @"Local";
                     }
                     
                     NSDictionary *props = @{@"chId" : deDuplicate[chNum],
                                             @"chName" : [item objectForKey:@"chName"],
                                             @"chCall" : [item objectForKey:@"chCall"],
                                             @"chLogoId" : [item objectForKey:@"chLogoId"],
                                             @"chNum": [item objectForKey:@"chNum"],
                                             @"chHd": [item objectForKey:@"chHd"],
                                             @"chCat": category,
                                             @"chAdult": [item objectForKey:@"chAdult"]};
                     
                     dtvChannel *channel = [[dtvChannel alloc] initWithProperties:props];
                     
                     [channels setObject:channel forKey:[deDuplicate[chNum] stringValue]];
                     
                 }
                 [dtvChannels save:channels];
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageDownloadChannelLogos"
                                                                     object:channels];
                 
             } else {
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageAPIDown" object:nil];
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messagePromptForZipCode" object:nil];
             }
             
         }
         
     }];
}

+ (void) downloadChannelImages:(NSMutableDictionary *)channels {
    [self clearCachedImages];
    
    NSOperationQueue *channelImagesQueue = [[NSOperationQueue alloc] init];
    channelImagesQueue.name = @"Channel Images Cache";
    channelImagesQueue.maxConcurrentOperationCount = 5;
    
    NSString *cacheDirectory = [Util getDocumentsDirectory];
    NSArray *keys = [channels allKeys];
    
    __block int completed = 0;
    __block int total = (double)[keys count];
    
    for (NSString *channelId in keys) {
        
        dtvChannel *channel = channels[channelId];
        
        NSURL *location = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.directv.com/images/logos/channels/dark/medium/%03d.png", channel.logoId]];
        
        NSString *imagePath = [cacheDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",channelId]];
        
        NSURLResponse* response;
        NSError *connectionError;
        
        NSData* data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:location]
                                             returningResponse:&response error:&connectionError];
        

        if (data.length > 0 && connectionError == nil) {
            [data writeToFile:imagePath atomically:NO];
        }
        completed++;
        if (completed >= total) {
            NSLog(@"channels refreshed");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedChannels" object:channels];
        } else {
            long double progress =(completed*1.0/total*1.0);
            NSNumber *nsprogress = [NSNumber numberWithDouble:progress];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedChannelsProgress"
                                                                object:nsprogress];
        }
        
        
       
        
    }
    
}

+ (void)clearCachedImages {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cacheDirectory = [Util getDocumentsDirectory];
    NSArray *cacheFiles = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:nil];
    for (NSString *file in cacheFiles) {
        if ([file hasPrefix:@".png"]) {
            [fileManager removeItemAtPath:[cacheDirectory stringByAppendingPathComponent:file] error:nil];
        }
    }
}

+ (dtvChannel *)getChannelByNumber:(int)number channels:(NSMutableDictionary *)channels {
    dtvChannel *channel;
    for (NSString *chId in channels) {
        dtvChannel *thisChannel = [channels objectForKey:chId];
        if (thisChannel.number == number) {
            channel = thisChannel;
            break;
        }
    }
    return channel;
}

+ (dtvChannel *)getChannelByCallSign:(NSString *)callSign channels:(NSMutableDictionary *)channels {
    dtvChannel *channel;
    for (NSString *chId in channels) {
        dtvChannel *thisChannel = [channels objectForKey:chId];
        if ( [channel.callsign isEqualToString:callSign] ) {
            channel = thisChannel;
            break;
        }
    }
    return channel;
}

+ (NSMutableDictionary *) sortChannels:(NSMutableDictionary *)channels sortBy:(NSString *)sort {
    
    NSMutableDictionary *sortedChannels = [[NSMutableDictionary alloc] init];
    NSArray *keys = [channels allKeys];
    
    if ([sort isEqualToString:@"default"]) {
        if ([[NSUserDefaults standardUserDefaults] stringForKey:@"sort"] == nil) {
            [[NSUserDefaults standardUserDefaults] setObject:@"category" forKey:@"sort"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        sort = [[NSUserDefaults standardUserDefaults] stringForKey:@"sort"];
    }
    
    if ([sort isEqualToString:@"name"]) {
        for (NSString *chId in keys) {
            dtvChannel *channel = channels[chId];
            NSString *header = [[channel.name substringToIndex:1] uppercaseString];
            if (![sortedChannels objectForKey:header]) {
                [sortedChannels setObject:[[NSMutableDictionary alloc] init] forKey:header];
            }
            [sortedChannels[header] setObject:channel forKey:chId];
        }
    }
    
    if ([sort isEqualToString:@"number"]) {
        for (NSString *chId in keys) {
            dtvChannel *channel = channels[chId];
            int section = floor(channel.number/100)*100;
            NSString *header = [NSString stringWithFormat:@"%04d-%04d", section, section+100];
            if (![sortedChannels objectForKey:header]) {
                [sortedChannels setObject:[[NSMutableDictionary alloc] init] forKey:header];
            }
            [sortedChannels[header] setObject:channel forKey:chId];
        }
    }
    
    if ([sort isEqualToString:@"category"]) {
        
        for (NSString *chId in keys) {
            dtvChannel *channel = channels[chId];
            NSString *header = channel.category;
            if (![sortedChannels objectForKey:header]) {
                [sortedChannels setObject:[[NSMutableDictionary alloc] init] forKey:header];
            }
            [sortedChannels[header] setObject:channel forKey:chId];
        }
    }
    
    
    return sortedChannels;
}

+ (NSString *) DTVCookie {
    NSString *cookie = (NSString *)[Util loadObjectFromDisk:@"saveDTVCookie" objectType:@"NSString"];
    return  cookie;
}

+ (void)saveDTVCookie:(NSString *) channels {
    if (channels) {
        [Util saveObjectToDisk:channels key:@"saveDTVCookie"];
    }
}


@end