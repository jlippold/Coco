//
//  dtvDevice.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "dtvDevice.h"

@implementation dtvDevice

- (id) initWithProperties:(NSDictionary *)properties {
    
    if (self = [super init])
    {
        _identifier = properties[@"identifier"];
        _address = properties[@"address"];
        _ssid = properties[@"ssid"];
        _url = [NSString stringWithFormat:@"http://%@:8080/", properties[@"address"]];
        _name = properties[@"name"];
        _appendage = properties[@"appendage"];
        _online = NO;
        _lastChecked = nil;
    }
    
    return self;
}


- (void)encodeWithCoder:(NSCoder *) coder
{
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_address forKey:@"address"];
    [coder encodeObject:_ssid forKey:@"ssid"];
    [coder encodeObject:_url forKey:@"url"];
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_appendage forKey:@"appendage"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _identifier = [decoder decodeObjectForKey:@"identifier"];
        _address = [decoder decodeObjectForKey:@"address"];
        _ssid = [decoder decodeObjectForKey:@"ssid"];
        _url = [decoder decodeObjectForKey:@"url"];
        _name = [decoder decodeObjectForKey:@"name"];
        _appendage = [decoder decodeObjectForKey:@"appendage"];
        _online = NO;
        _lastChecked = nil;
    }
    return self;
}

@end

