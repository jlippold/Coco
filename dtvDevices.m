//
//  dtvDevices.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "dtvDevices.h"
#import "dtvDevice.h"
#import "iNet.h"

@implementation dtvDevices

+ (void) refreshDevicesForNetworks {

    if ([iNet isOnWifi]) {

        NSString *wifiAddress = [iNet getWifiAddress];
        
        __block int total;
        __block int completed = 0;
        __block NSMutableDictionary *networks;
        networks = [self loadNetworksFromDisk];
        
        NSRange range = [wifiAddress rangeOfString:@"." options:NSBackwardsSearch];
        NSString *ssid = [iNet fetchSSID];
        NSString *subnet = [wifiAddress substringToIndex:range.location];
        NSMutableArray *prospectiveDevices = [self getCandidates:subnet];
        
        total = (int)[prospectiveDevices count];
        
        NSOperationQueue *portScanQueue = [[NSOperationQueue alloc] init];
        portScanQueue.name = @"Scanner";
        portScanQueue.maxConcurrentOperationCount = 20;
        [portScanQueue cancelAllOperations];
        
        for (NSUInteger i = 0; i < [prospectiveDevices count]; i++) {
            NSString *strUrl = [NSString stringWithFormat:@"http://%@:8080/info/getLocations",
                                [prospectiveDevices objectAtIndex:i]];
            
            NSURL *url = [NSURL URLWithString:strUrl];
            
            NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url
                                                          cachePolicy:1
                                                      timeoutInterval:3];
            
            [self makeRequest:request queue:portScanQueue completionHandler:
             ^(NSURLResponse *response, NSData *data, NSError *connectionError)
             {
                 id client = [prospectiveDevices objectAtIndex:i];
                 
                 if (i == 50) {
                     NSLog(@"%@", strUrl);
                 }
            
                 
                 if (data.length > 0 && connectionError == nil) {
                     NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                     if (json[@"locations"]) {
                         for (id item in json[@"locations"]) {
                             
                             NSString *appendage = @"";
                             if (![[item objectForKey:@"clientAddr"] isEqualToString:@"0"]) {
                                 appendage = [NSString stringWithFormat:@"clientAddr=%@",
                                              [item objectForKey:@"clientAddr"]];
                             }
                             
                             NSString *clientId = [NSString stringWithFormat:@"%@-%@",
                                                   [item objectForKey:@"locationName"],
                                                   [item objectForKey:@"clientAddr"]];
                             
                             NSDictionary *props = @{@"identifier" : clientId,
                                                          @"address" : client,
                                                          @"name" : [item objectForKey:@"locationName"],
                                                          @"appendage": appendage};
                             
                             
                             dtvDevice *device = [[dtvDevice alloc] initWithProperties:props];
                             
                             if (!networks[ssid]) {
                                 NSMutableDictionary *newClient = [[NSMutableDictionary alloc] init];
                                 [networks setObject:newClient forKey:ssid];
                             }
                             
                             if (!networks[ssid][clientId]) {
                                 [networks[ssid] setObject:device forKey:clientId];
                             }
                         }
                         
                     }
                 }
                 
                 completed++;
                 if (completed == total){
                     [self saveNetworksToDisk:networks];
                     [self sendMessageOfUpdatedDevices:networks[ssid]];
                 } else {
                     long double progress =(completed*1.0/total*1.0);
                     NSNumber *nsprogress = [NSNumber numberWithDouble:progress];
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedDevicesProgress"
                                                                         object:nsprogress];
                 }
             }];
        }
    } else {
       [self sendMessageOfUpdatedDevices:[[NSMutableDictionary alloc] init]];
    }
    
}


+ (NSMutableDictionary *) getSavedDevicesForActiveNetwork {
    if ([iNet isOnWifi]) {
        NSMutableDictionary *networks = [self loadNetworksFromDisk];
        NSString *ssid = [iNet fetchSSID];
        if([networks objectForKey:ssid]) {
            return networks[ssid];
        } else {
            return [[NSMutableDictionary alloc] init];
        }
    } else {
        return [[NSMutableDictionary alloc] init];
    }
}

+ (void) checkStatusOfDevices {
    
}

+ (void) saveNetworksToDisk:(NSMutableDictionary *) devices {
    NSString *key = @"devices";
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    if (devices != nil) {
        [dataDict setObject:devices forKey:key];
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    [NSKeyedArchiver archiveRootObject:dataDict toFile:filePath];
}

+ (NSMutableDictionary *) loadNetworksFromDisk {
    NSString *key = @"devices";
    NSMutableDictionary *devices = [[NSMutableDictionary alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([savedData objectForKey:key] != nil) {
            NSMutableDictionary *base = [[savedData objectForKey:key] mutableCopy];
            devices = [base mutableCopy];
        }
    }
    return devices;
}


+ (dtvDevice *) getCurrentDevice {
    NSMutableDictionary *devices = [self getSavedDevicesForActiveNetwork];
    NSString *deviceId = [self getLastUsedDeviceById];
    
    dtvDevice *device;
    for (NSString *thisId in [devices allKeys]) {
        dtvDevice *thisDevice = devices[thisId];
        if ([thisDevice.identifier isEqualToString:deviceId]) {
            device = thisDevice;
        }
    }
    return device;
}

+ (NSString *) getLastUsedDeviceById {
    NSString *key = @"deviceId";
    NSString *deviceId = @"";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([savedData objectForKey:key] != nil) {
            deviceId = [savedData objectForKey:key];
        }
    }
    
    return  deviceId;
}

+ (void) saveCurrentDeviceId:(NSString *)deviceId {
    NSString *key = @"deviceId";
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    if (deviceId != nil) {
        [dataDict setObject:deviceId forKey:key];
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    [NSKeyedArchiver archiveRootObject:dataDict toFile:filePath];
}

+ (NSMutableArray *) getCandidates:(NSString *)subnet {
    NSMutableArray *range = [[NSMutableArray alloc] init];
    for (NSUInteger i = 1; i < 256; i++) {
        [range addObject:[subnet stringByAppendingString:[NSString stringWithFormat:@".%@",  @(i)]]];
    }
    return range;
}

+ (void) sendMessageOfUpdatedDevices:(NSMutableDictionary *) devices {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedDevices" object:devices];
}

+ (void) makeRequest:(NSURLRequest*)request queue:(NSOperationQueue*)queue
   completionHandler:(void(^)(NSURLResponse *response, NSData *data, NSError *error))handler
{
    __block NSURLResponse *response = nil;
    __block NSError *error = nil;
    __block NSData *data = nil;
    
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        data = [NSURLConnection sendSynchronousRequest:request
                                     returningResponse:&response
                                                 error:&error];
    }];
    
    blockOperation.completionBlock = ^{
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            handler(response, data, error);
        }];
    };
    
    [queue addOperation:blockOperation];
}

@end
