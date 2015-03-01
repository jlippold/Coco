//
//  iNet.m
//  dtvRemote
//
//  Created by Jed Lippold on 2/22/15.
//  Copyright (c) 2015 jed. All rights reserved.
//   Finds clients on the network

#import "iNet.h"
#import "ViewController.h"
#include "TargetConditionals.h"
@import SystemConfiguration.CaptiveNetwork;

@interface iNet ()

@end

@implementation iNet

@synthesize portScanQueue = _portScanQueue;


- (void)dealloc {
   //[self.portScanQueue removeObserver:self forKeyPath:@"Scanner"];
}


-(void)findClients {
    NSLog(@"Scanning");
    
    NSString *wifiAddress = [self getWifiAddress];

    
    self.portScanQueue = [[NSOperationQueue alloc] init];
    self.portScanQueue.name = @"Scanner";

    //[self.portScanQueue addObserver:self forKeyPath:@"Scanner" options:NSKeyValueObservingOptionNew context: NULL];
    
    if ([wifiAddress containsString:@"."]) {
        NSRange range = [wifiAddress rangeOfString:@"." options:NSBackwardsSearch];
        NSString *subnet = [wifiAddress substringToIndex:range.location];
        NSMutableArray *prospectiveClients = [self getCandidates:subnet];
        NSMutableArray *checkedClients = [[NSMutableArray alloc] init];
        NSMutableArray *foundClients = [[NSMutableArray alloc] init];
        
        [self.portScanQueue cancelAllOperations];
        
        for (NSUInteger i = 0; i < [prospectiveClients count]; i++) {
            NSString *strUrl = [NSString stringWithFormat:@"http://%@:8080/info/getLocations",
                                [prospectiveClients objectAtIndex:i]];
            
            //NSLog(@"scanning %@", [addresses objectAtIndex:i]);
            NSURL *url = [NSURL URLWithString:strUrl];
            
            NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url
                                                          cachePolicy:1
                                                      timeoutInterval:3];
            
            [self makeRequest:request queue:self.portScanQueue completionHandler:
             ^(NSURLResponse *response, NSData *data, NSError *connectionError)
             {
                 id client = [prospectiveClients objectAtIndex:i];
                 if (data.length > 0 && connectionError == nil) {
                     NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                     if (json[@"locations"]) {
                         for (id item in json[@"locations"]) {
                             NSString *appendage = @"";
                             if (![[item objectForKey:@"clientAddr"] isEqualToString:@"0"]) {
                                 appendage = [NSString stringWithFormat:@"clientAddr=%@",
                                              [item objectForKey:@"clientAddr"]];
                             }

                             NSDictionary *clientInfo = @{@"address" : client,
                                                          @"url": [NSString stringWithFormat:@"http://%@:8080/", client],
                                                          @"name" : [item objectForKey:@"locationName"],
                                                          @"appendage": appendage};
                             
                             [foundClients addObject:clientInfo];
                         }
                         
                     }
                 }
                 
                 [checkedClients addObject:client];
                 if ([checkedClients count] == [prospectiveClients count]){
                     [self sendClients:foundClients];
                     NSLog(@"Completed Scanning");
                 }
             }];
        }
        
    }

}

-(void) sendClients:(NSMutableArray*) clients {
    
    NSString *ssid = [self fetchSSID];
    NSMutableDictionary *netClients = [[NSMutableDictionary alloc] init];
    [netClients setObject:clients forKey:ssid];
    NSLog(@"%@", netClients);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"pushClients" object:clients];
    //ViewController* vc = [[ViewController alloc] init];
    //[vc pushClients:clients];
}

-(void) makeRequest:(NSURLRequest*)request queue:(NSOperationQueue*)queue completionHandler:(void(^)(NSURLResponse *response, NSData *data, NSError *error))handler
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



- (NSMutableArray *) getCandidates:(NSString *)subnet {
    NSMutableArray *range = [[NSMutableArray alloc] init];
    for (NSUInteger i = 1; i < 256; i++) {
        [range addObject:[subnet stringByAppendingString:[NSString stringWithFormat:@".%@",  @(i)]]];
    }
    return range;
}

- (NSString *) getWifiAddress {
    
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL)
        {
            if(temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Check if interface is en0 which is the wifi connection on the iPhone
                
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
                {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    return address;
}

- (NSString *)fetchSSID {
    NSArray *ifs = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
    NSLog(@"Supported interfaces: %@", ifs);
    NSDictionary *info;
    for (NSString *ifnam in ifs) {
        info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
        NSLog(@"%@ => %@", ifnam, info);
        if (info && [info count]) { break; }
    }
    #if (TARGET_IPHONE_SIMULATOR)
        return @"Simulator";
    #else
        return info[@"SSID"];
    #endif
    
}



@end