//
//  dtvDevice.h
//  dtvRemote
//
//  Created by Jed Lippold on 5/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface dtvDevice : NSObject

@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSString *ssid;
@property (nonatomic, strong) NSString *address;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *appendage;
@property (nonatomic, strong) NSDate *lastChecked;
@property BOOL online;

-(id) initWithProperties:(NSDictionary *)properties;


@end
