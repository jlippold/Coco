//
//  iNet.m
//  dtvRemote
//
//  Created by Jed Lippold on 2/22/15.
//  Copyright (c) 2015 jed. All rights reserved.
//   Finds clients on the network

#import "iNet.h"
#import "ViewController.h"
@import SystemConfiguration.CaptiveNetwork;

@interface iNet ()

@end

@implementation iNet

- (void)dealloc {
    [_portScanQueue removeObserver:self forKeyPath:@"Scanner"];
}

-(void)findClients {
    
    NSString *addr = [self getWifiAddress];
    
    _portScanQueue = [[NSOperationQueue alloc] init];
    _portScanQueue.name = @"Scanner";
    _portScanQueue.maxConcurrentOperationCount = 20;
    
    [_portScanQueue addObserver:self forKeyPath:@"Scanner" options: NSKeyValueObservingOptionNew context: NULL];
    
    if ([addr containsString:@"."]) {
        NSRange range = [addr rangeOfString:@"." options:NSBackwardsSearch];
        NSString *subnet = [addr substringToIndex:range.location];
        NSMutableArray *addresses = [self getCandidates:subnet];
        
        [_portScanQueue cancelAllOperations];
        
        for (NSUInteger i = 0; i < [addresses count]; i++) {
            NSString *strUrl = [NSString stringWithFormat:@"http://%@:8080/",
                                [addresses objectAtIndex:i]];
            
            //NSLog(@"scanning %@", [addresses objectAtIndex:i]);
            NSURL *url = [NSURL URLWithString:strUrl];
            
            NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url
                                                          cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                      timeoutInterval:3];
            
            [NSURLConnection sendAsynchronousRequest:request queue:_portScanQueue completionHandler:
             ^(NSURLResponse *response, NSData *data, NSError *connectionError)
             {

                 if (data.length > 0 && connectionError == nil) {
                     ViewController* vc = [[ViewController alloc] init];
                     [vc pushClient:[addresses objectAtIndex:i]];
                 }
             }];
            
        }
        
    }

}

- (NSMutableArray *) getCandidates:(NSString *)subnet {
    NSMutableArray *range = [[NSMutableArray alloc] init];
    for (NSUInteger i = 1; i < 255; i++) {
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




@end