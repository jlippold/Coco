//
//  channels.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//  Returns Channels for a location

#import "Channels.h"

@interface Channels ()

@end

@implementation Channels

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(id)init {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedZipCodes:)
                                                 name:@"messageUpdatedZipCodes" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedLocations:)
                                                 name:@"messageUpdatedLocations" object:nil];
    
    return self;
    
}

- (void) save:(NSMutableDictionary *) channelList {
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] initWithCapacity:3];
    if (channelList != nil) {
        [dataDict setObject:channelList forKey:@"channelList"];
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:@"appData"];
    [NSKeyedArchiver archiveRootObject:dataDict toFile:filePath];
}

- (NSMutableDictionary *) loadChannels {
    NSMutableDictionary *channelList = [[NSMutableDictionary alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:@"appData"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([savedData objectForKey:@"channelList"] != nil) {
            channelList = [[NSMutableDictionary alloc] initWithDictionary:[savedData objectForKey:@"channelList"]];
        }
    }
    return channelList;
}

- (void)messageUpdatedZipCodes:(NSNotification *)notification {
    NSString *zipCode = [notification object];
    [self getLocationsForZipCode:zipCode];
}

- (void) getLocationsForZipCode:(NSString *)zipCode {
    
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

- (void)messageUpdatedLocations:(NSNotification *)notification {
    NSMutableDictionary *location = [notification object];
    [self populateChannels:location];
}
- (void) populateChannels:(NSMutableDictionary *)location {
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
                 [self readJSONFromHTMLBody:json];
             }
         }
     }];
}


- (void) readJSONFromHTMLBody:(NSString *)text {
    
    NSMutableDictionary *channelList = [[NSMutableDictionary alloc] init];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    if (json[@"guideData"]) {
        id root = json[@"guideData"];
        if (root[@"channels"]) {
            for (id item in [root objectForKey: @"channels"]) {
                NSString *paddedId = [NSString stringWithFormat:@"%05ld", (long)[[item objectForKey:@"chNum"] integerValue]];
                NSDictionary *dictionary = @{@"chId" : [item objectForKey:@"chId"],
                                             @"chName" : [item objectForKey:@"chName"],
                                             @"chCall" : [item objectForKey:@"chCall"],
                                             @"chNum": [item objectForKey:@"chNum"],
                                             @"chHd": [item objectForKey:@"chHd"],
                                             @"title": @"Loading..."};
                
                [channelList setObject:dictionary forKey:paddedId];
            }
            
        }
    }
    
    
    [self save:channelList];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedChannels" object:channelList];
    
}

@end