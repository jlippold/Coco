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

+ (NSMutableDictionary *) load {
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
    return channelList;
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
                         for (id item in [root objectForKey: @"channels"]) {
                             NSDictionary *dictionary = @{@"chId" : [item objectForKey:@"chId"],
                                                          @"chName" : [item objectForKey:@"chName"],
                                                          @"chCall" : [item objectForKey:@"chCall"],
                                                          @"chLogoId" : [item objectForKey:@"chLogoId"],
                                                          @"chNum": [item objectForKey:@"chNum"],
                                                          @"chHd": [item objectForKey:@"chHd"],
                                                          @"title": @"Loading..."};
                             
                             [channelList setObject:dictionary forKey:[[item objectForKey:@"chId"] stringValue]];
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


+ (void) readJSONFromHTMLBody:(NSString *)text {
    
    
    
    
}

+ (void) downloadChannelImages:(NSMutableDictionary *)channelList {
    [self clearCaches];
    
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
             if (completed >= (total-1)) {
                 NSLog(@"channels refreshed");
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedChannels" object:channelList];
             } else {
                 long double progress =(completed*1.0/total*1.0);
                 //NSLog(@"c: %f", completed*1.0);
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


+ (NSMutableDictionary *) sortChannels:(NSMutableDictionary *)channels sortBy:(NSString *)sort {
    
    NSMutableDictionary *sortedChannels = [[NSMutableDictionary alloc] init];
    NSArray *keys = [channels allKeys];
    
    if ([sort isEqualToString:@"name"]) {
        for (id channel in keys) {
            NSString *chId = [channels[channel] objectForKey:@"chId"];
            NSString *chName = [channels[channel] objectForKey:@"chName"];
            NSString *header = [chName substringToIndex:1];
            
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
    
    
    return sortedChannels;
}
@end