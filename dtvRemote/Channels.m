//
//  channels.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//  Returns Channels for a location

#import "Channels.h"

@implementation Channels


+ (void)save:(NSMutableDictionary *) channelList {
    NSString *key = @"channelList";
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    if (channelList != nil) {
        [dataDict setObject:channelList forKey:key];
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    [NSKeyedArchiver archiveRootObject:dataDict toFile:filePath];
}

+ (NSMutableDictionary *) load:(BOOL)showBlocks {
    NSString *key = @"channelList";
    NSMutableDictionary *channelList = [[NSMutableDictionary alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([savedData objectForKey:key] != nil) {
            channelList = [[NSMutableDictionary alloc] initWithDictionary:[savedData objectForKey:key]];
        }
    }
    
    //remove blocks
    if (!showBlocks) {
        NSMutableArray *blocks = [self loadBlockedChannels:channelList];
        for (id block in blocks) {
            [channelList removeObjectForKey:block];
        }
        //NSLog(@"Removed: %lu", (unsigned long)[blocks count]);
    }
    
    return channelList;
}

+ (NSMutableArray *) loadBlockedChannels:(NSMutableDictionary *)channelList {
    NSString *key = @"blockedChannels";
    NSMutableArray *blocks = [[NSMutableArray alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([savedData objectForKey:key] != nil) {
            blocks = [[NSMutableArray alloc] initWithArray:[savedData objectForKey:key] copyItems:YES];
        }
    }
    
    if ([blocks count] == 0) {
        //load some defaults
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"categories" withExtension:@"plist"];
        NSDictionary *categories = [[NSDictionary dictionaryWithContentsOfURL:url] objectForKey: @"Categories"];
        
        NSArray *blockCallSigns = [NSArray arrayWithObjects:
                                   @"CINE", @"CINEHD", @"SONIC", @"PPV", @"DTV",
                                   @"BSN", @"NHL", @"MLS", @"PPVHD", @"IACHD",
                                   @"CINE1", @"CINE2", @"CINE3", @"IDEA", @"BEST",
                                   @"MALL", @"SALE", @"NEW", @"AAN", @"EPL",
                                   @"UEFA", @"RGBY", @"EPL", @"MAS", @"NBA", @"PTNW", @"ACT", nil];
        
        NSArray *blockCategories = [NSArray arrayWithObjects:
                                   @"Foreign", @"Religious", @"Shopping", @"Sports", @"Uncatagorized", @"(null)", nil];
        
        for (id key in channelList) {
            id channel = [channelList objectForKey:key];
            NSString *callSign = [[NSString stringWithFormat:@"%@", channel[@"chCall"]] uppercaseString];
            NSString *category = [NSString stringWithFormat:@"%@", categories[callSign]];
            
            if ([channel[@"chAdult"] intValue] == 1 ||
                [blockCallSigns containsObject:callSign] ||
                [blockCategories containsObject:category]) {
                [blocks addObject:[channel[@"chId"] stringValue]];
            }
            
        }
    }
    return blocks;
    
}
+ (void)saveBlockedChannels:(NSMutableArray *) blockedChannels {
    NSString *key = @"blockedChannels";
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    if (blockedChannels != nil) {
        [dataDict setObject:blockedChannels forKey:key];
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    [NSKeyedArchiver archiveRootObject:dataDict toFile:filePath];
}

+ (void) getLocationsForZipCode:(NSString *)zipCode {
    
    //get valid locations for zip code
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.directv.com/json/zipcode/%@", zipCode]];
    
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError)
     {
         NSMutableDictionary *locations = [[NSMutableDictionary alloc] init];
         
         if (data.length > 0 && connectionError == nil) {
             
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
             }
             
         }
         
         [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedLocations" object:locations];
         
     }];
    
}

+ (void) populateChannels:(NSMutableDictionary *)location {
    NSLog(@"%@",location);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.directv.com/guide"]];
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    NSString *cookie = [NSString stringWithFormat:@"dtve-prospect-state=%@; dtve-prospect-zip=%@%%7C%@;",
                        location[@"state"], location[@"zipCode"],
                        [location[@"timeZone"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    [self saveDTVCookie:cookie];
    
    [mutableRequest addValue:cookie forHTTPHeaderField:@"Cookie"];
    
    request = [mutableRequest copy];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:
     ^(NSURLResponse *response, NSData *data, NSError *error) {
         NSString *responseText = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
         for (NSString *line in [responseText componentsSeparatedByString:@"\n"]) {
             NSString *searchTerm = @"var dtvClientData = ";
             if ([line hasPrefix:@"<!--[if gt IE 8]>"] && [line containsString:searchTerm]) {
                 NSRange range = [line rangeOfString:searchTerm];
                 NSString *json = [line substringFromIndex:(range.location + searchTerm.length)];
                 NSRange endrange = [json rangeOfString:@"};"];
                 json = [json substringToIndex:endrange.location+1];
                 
                 NSMutableDictionary *channelList = [[NSMutableDictionary alloc] init];
                 
                 NSDictionary *jsonchannels = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
                 
                 if (jsonchannels[@"guideData"]) {
                     id root = jsonchannels[@"guideData"];
                     if (root[@"channels"]) {
                         
                         NSMutableDictionary *deDuplicate = [[NSMutableDictionary alloc] init];
                         
                         for (id item in [root objectForKey: @"channels"]) {
                             
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
                             
                             NSDictionary *channel = @{@"chId" : deDuplicate[chNum],
                                                       @"chName" : [item objectForKey:@"chName"],
                                                       @"chCall" : [item objectForKey:@"chCall"],
                                                       @"chLogoId" : [item objectForKey:@"chLogoId"],
                                                       @"chNum": [item objectForKey:@"chNum"],
                                                       @"chHd": [item objectForKey:@"chHd"],
                                                       @"chCat": @"Uncategorized",
                                                       @"chAdult": [item objectForKey:@"chAdult"]};
                             
                             [channelList setObject:[channel mutableCopy] forKey:[deDuplicate[chNum] stringValue]];

                         }
                         
                     }
                 }
                 
                 
                 [Channels save:channelList];
                 
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageDownloadChannelLogos"
                                                                     object:channelList];
             }
         }
     }];
}

+ (void) downloadChannelImages:(NSMutableDictionary *)channelList {
    [self clearCaches];
                     //NSLog(@"checking channels");
    
    NSOperationQueue *channelImagesQueue = [[NSOperationQueue alloc] init];
    channelImagesQueue.name = @"Channel Images Cache";
    channelImagesQueue.maxConcurrentOperationCount = 5;
    
    NSString *cacheDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSArray *keys = [channelList allKeys];
    
    __block int completed = 0;
    __block int total = (double)[keys count];
    
    for (id channel in keys) {
        
        NSString *channelId =  [channelList[channel] objectForKey:@"chLogoId"];
        NSURL *location = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.directv.com/images/logos/channels/dark/medium/%03d.png", [channelId intValue]]];
        
        NSString *imagePath =[cacheDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",channelId]];
        
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:location]
                                           queue:channelImagesQueue
                               completionHandler:^(NSURLResponse *response,
                                                   NSData *data,
                                                   NSError *connectionError)
         {
             if (data.length > 0 && connectionError == nil) {
                 [data writeToFile:imagePath atomically:NO];
             }
             completed++;
             if (completed >= total) {
                 NSLog(@"channels refreshed");
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedChannels" object:channelList];
             } else {
                 long double progress =(completed*1.0/total*1.0);
                 NSNumber *nsprogress = [NSNumber numberWithDouble:progress];
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedChannelsProgress"
                                                                     object:nsprogress];
             }
             
         }];
        
    }
    
}

+ (void)clearCaches {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cacheDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSArray *cacheFiles = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:nil];
    for (NSString *file in cacheFiles) {
        [fileManager removeItemAtPath:[cacheDirectory stringByAppendingPathComponent:file] error:nil];
    }
}

+ (NSString *)getChannelIdForChannelNumber:(NSString *)chNum channels:(NSMutableDictionary *)channels {
    NSString *chan = @"";
    for (NSString *chId in channels) {
        id channel = [channels objectForKey:chId];
        if ( [channel[@"chNum"] integerValue] == [chNum integerValue] ) {
            chan = chId;
            break;
        }
    }
    return chan;
}

+ (NSString *)getChannelIdForChannelCallSign:(NSString *)callSign channels:(NSMutableDictionary *)channels {
    NSString *chan = @"";
    for (NSString *chId in channels) {
        id channel = [channels objectForKey:chId];
        if ( [channel[@"chCall"] isEqualToString:callSign] ) {
            chan = chId;
            break;
        }
    }
    return chan;
}

+ (NSMutableDictionary *) sortChannels:(NSMutableDictionary *)channels sortBy:(NSString *)sort {
    
    NSMutableDictionary *sortedChannels = [[NSMutableDictionary alloc] init];
    NSArray *keys = [channels allKeys];
    
    if ([sort isEqualToString:@"default"]) {
        if ([[NSUserDefaults standardUserDefaults] stringForKey:@"sort"] == nil) {
            [[NSUserDefaults standardUserDefaults] setObject:@"channelGroup" forKey:@"sort"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        sort = [[NSUserDefaults standardUserDefaults] stringForKey:@"sort"];
    }
    
    if ([sort isEqualToString:@"name"]) {
        for (id channel in keys) {
            NSString *chId = [channels[channel] objectForKey:@"chId"];
            NSString *chName = [channels[channel] objectForKey:@"chName"];
            NSString *header = [[chName substringToIndex:1] uppercaseString];
            
            if (![sortedChannels objectForKey:header]) {
                [sortedChannels setObject:[[NSMutableDictionary alloc] init] forKey:header];
            }
            
            [sortedChannels[header] setObject:chId forKey:chName];
        }
    }
    
    if ([sort isEqualToString:@"number"]) {
        for (id channel in keys) {
            NSString *chId = [channels[channel] objectForKey:@"chId"];
            NSString *chNum = [channels[channel] objectForKey:@"chNum"];
            int section = floor([chNum intValue]/100)*100;
            NSString *header = [NSString stringWithFormat:@"%04d-%04d", section, section+100];
            
            if (![sortedChannels objectForKey:header]) {
                [sortedChannels setObject:[[NSMutableDictionary alloc] init] forKey:header];
            }

            [sortedChannels[header] setObject:chId forKey:chNum];
        }
    }
    
    if ([sort isEqualToString:@"category"]) {
        for (id channel in keys) {
            NSString *chId = [channels[channel] objectForKey:@"chId"];
            NSString *chNum = [channels[channel] objectForKey:@"chNum"];
            NSString *header = [channels[channel] objectForKey:@"chCat"];
            
            if (![sortedChannels objectForKey:header]) {
                [sortedChannels setObject:[[NSMutableDictionary alloc] init] forKey:header];
            }
            
            [sortedChannels[header] setObject:chId forKey:chNum];
        }
    }
    
    if ([sort isEqualToString:@"channelGroup"]) {
        
        
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"categories" withExtension:@"plist"];
        NSDictionary *categories = [[NSDictionary dictionaryWithContentsOfURL:url] objectForKey: @"Categories"];

        for (id channel in keys) {
            NSString *chId = [channels[channel] objectForKey:@"chId"];
            NSString *chNum = [channels[channel] objectForKey:@"chNum"];
            NSString *chCall = [[channels[channel] objectForKey:@"chCall"] uppercaseString];
            NSString *header = @"Uncatagorized";
            if (categories[chCall]) {
                header = categories[chCall];
            }
            
            if ([header isEqualToString:@"Uncatagorized"] &&
                [[chCall substringFromIndex:1] isEqualToString:@"W"]) {
                header = @"Local";
            }

            if (![sortedChannels objectForKey:header]) {
                [sortedChannels setObject:[[NSMutableDictionary alloc] init] forKey:header];
            }
            
            [sortedChannels[header] setObject:chId forKey:chNum];
        }
    }
    
    
    return sortedChannels;
}

+ (NSString *) DTVCookie {

    NSString *cookie = @"";
    
    NSString *key = @"saveDTVCookie";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([savedData objectForKey:key] != nil) {
            cookie = [savedData objectForKey:key];
        }
    }
    return cookie;
}

+ (void)saveDTVCookie:(NSString *) channelList {
    NSString *key = @"saveDTVCookie";
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    if (channelList != nil) {
        [dataDict setObject:channelList forKey:key];
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    [NSKeyedArchiver archiveRootObject:dataDict toFile:filePath];
}

+ (NSMutableDictionary *) addChannelCategoriesFromGuide:(NSMutableDictionary *)guide
                                               channels:(NSMutableDictionary *)channels  {
    for (NSString *chId in channels) {
        if ([guide objectForKey:chId]) {
            NSDictionary *guideItem = [guide objectForKey:chId];
            channels[chId][@"chCat"] = guideItem[@"category"];
        }
    }
    return channels;
}


@end