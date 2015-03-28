//
//  Clients.h
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Clients : NSObject

+ (void)searchWifiForDevices;
+ (NSMutableDictionary *) loadClientList;

+ (NSDictionary *) getClient;
+ (void) setCurrentClientId:(NSString *)clientId;

@end
