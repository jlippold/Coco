//
//  iNet.m
//  dtvRemote
//
//  Created by Jed Lippold on 2/22/15.
//  Copyright (c) 2015 jed. All rights reserved.
//  Network Utilities

#import "iNet.h"
#include "TargetConditionals.h"
#import "Reachability.h"

@import SystemConfiguration.CaptiveNetwork;

@implementation iNet

+ (NSString *) getWifiAddress {
    
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

+ (NSString *)fetchSSID {
    NSArray *ifs = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
    NSDictionary *info;
    for (NSString *ifnam in ifs) {
        info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
        if (info && [info count]) { break; }
    }
    #if (TARGET_IPHONE_SIMULATOR)
        return @"Simulator";
    #else
        if (info[@"SSID"]) {
            return info[@"SSID"];
        } else {
            return @"";
        }
    #endif
    
}

+ (BOOL) isOnWifi {
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    [reachability startNotifier];
    NetworkStatus status = [reachability currentReachabilityStatus];
    return (status == ReachableViaWiFi);
}


@end