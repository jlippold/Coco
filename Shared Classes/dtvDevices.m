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
#import "Util.h"

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
                                                          @"ssid" : ssid,
                                                          @"name" : [item objectForKey:@"locationName"],
                                                          @"appendage": appendage
                                                     };
                             
                             
                             dtvDevice *device = [[dtvDevice alloc] initWithProperties:props];
                             
                             if (!networks[ssid]) {
                                 NSMutableDictionary *newClient = [[NSMutableDictionary alloc] init];
                                 [networks setObject:newClient forKey:ssid];
                             }
                             
                             BOOL needsUpdate = NO;
                             
                             if (!networks[ssid][clientId]) {
                                 //new device
                                 needsUpdate = YES;
                             } else if (![networks[ssid][clientId] isEqual:device]) {
                                 //new ip
                                 needsUpdate = YES;
                             }
                             
                             if (needsUpdate) {
                                 [networks[ssid] setObject:device forKey:clientId];
                             }
                             
                         }
                         
                     }
                 }
                 
                 completed++;
                 if (completed == total){
                     [self saveNetworksToDisk:networks];
                     [self sendMessageOfUpdatedDevices:networks[ssid]];
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedDevicesProgress"
                                                                         object:[NSNumber numberWithDouble:1]];
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

+ (void) clearDevicesForNetwork {
    NSMutableDictionary *networks = [self loadNetworksFromDisk];
    NSString *ssid = [iNet fetchSSID];
    
    if (networks[ssid]) {
        [networks removeObjectForKey:ssid];
    }
    [networks setObject:[[NSMutableDictionary alloc] init] forKey:ssid];
    [self saveNetworksToDisk:networks];
    [self sendMessageOfUpdatedDevices:networks[ssid]];
    
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

+ (void) checkStatusOfDevices:(NSMutableDictionary *) deviceList {

    __block NSMutableDictionary *devices = [deviceList mutableCopy];
    NSArray *keys = [devices allKeys];
    __block int total = (double)[keys count];
    __block int completed = 0;
    
    for (NSString *deviceId in keys) {
        dtvDevice *device = devices[deviceId];
        
        

        NSURL *url = [NSURL URLWithString:
                      [NSString stringWithFormat:@"http://%@:8080/tv/getTuned?%@",
                       device.address, device.appendage ]];
        
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url
                                                      cachePolicy:1
                                                  timeoutInterval:3];
        
        NSOperationQueue *deviceCheckQueue = [[NSOperationQueue alloc] init];
        deviceCheckQueue.name = @"Scanner";
        deviceCheckQueue.maxConcurrentOperationCount = 20;
        [deviceCheckQueue cancelAllOperations];
        
        [self makeRequest:request queue:deviceCheckQueue completionHandler:
         ^(NSURLResponse *response, NSData *data, NSError *connectionError)
         {
             device.online = NO;
             
             if (data.length > 0 && connectionError == nil) {
                 NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                 NSNumber *statusCode = json[@"status"][@"code"];
                 if ([statusCode isEqualToNumber:[NSNumber numberWithInt:200]]){
                     device.online = YES;
                 }
             }
             device.lastChecked = [NSDate new];
             devices[deviceId] = device;
             completed++;
             if (completed == total){
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedStatusOfDevices"
                                                                     object:devices];
             }
             
         }];
        
    }
}

+ (void) saveNetworksToDisk:(NSMutableDictionary *) devices {
    if (devices) {
        [Util saveObjectToDisk:devices key:@"devices"];
    }
}

+ (NSMutableDictionary *) loadNetworksFromDisk {
    return (NSMutableDictionary *)[Util loadObjectFromDisk:@"devices" objectType:@"NSMutableDictionary"];
}


+ (void) setCurrentDevice:(dtvDevice *) device {
    [self saveCurrentDeviceId:device.identifier];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedCurrentDevice"
                                                        object:device];
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
    NSString *deviceId = (NSString *)[Util loadObjectFromDisk:@"deviceId" objectType:@"NSString"];
    return  deviceId;
}

+ (void) saveCurrentDeviceId:(NSString *)deviceId {
    if (deviceId) {
        [Util saveObjectToDisk:deviceId key:@"deviceId"];
    }
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
        [queue addOperationWithBlock:^{
            handler(response, data, error);
        }];
    };
    
    [queue addOperation:blockOperation];
}

@end
