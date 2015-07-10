//
//  dtvCustomCommand.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/21/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "dtvCustomCommand.h"

@implementation dtvCustomCommand

- (id) init {
    return self;
}

- (void)encodeWithCoder:(NSCoder *) coder
{
    [coder encodeBool:_isCustomCommand forKey:@"isCustomCommand"];
    [coder encodeObject:_networkName forKey:@"networkName"];
    [coder encodeObject:_deviceName forKey:@"deviceName"];
    [coder encodeObject:_url forKey:@"url"];
    [coder encodeObject:_method forKey:@"method"];
    [coder encodeObject:_data forKey:@"data"];
    [coder encodeObject:_buttonIndex forKey:@"buttonIndex"];
    [coder encodeObject:_commandDescription forKey:@"title"];
    [coder encodeObject:_shortName forKey:@"shortName"];
    [coder encodeObject:_onCompleteURIScheme forKey:@"onCompleteURIScheme"];
    [coder encodeObject:_fontAwesome forKey:@"fontAwesome"];
    
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _isCustomCommand = [decoder decodeBoolForKey:@"isCustomCommand"];
        _networkName = [decoder decodeObjectForKey:@"networkName"];
        _deviceName = [decoder decodeObjectForKey:@"deviceName"];
        _url = [decoder decodeObjectForKey:@"url"];
        _method = [decoder decodeObjectForKey:@"method"];
        _data = [decoder decodeObjectForKey:@"data"];
        _buttonIndex = [decoder decodeObjectForKey:@"buttonIndex"];
        _commandDescription = [decoder decodeObjectForKey:@"title"];
        _shortName = [decoder decodeObjectForKey:@"shortName"];
        _onCompleteURIScheme = [decoder decodeObjectForKey:@"onCompleteURIScheme"];
        _fontAwesome = [decoder decodeObjectForKey:@"fontAwesome"];
    }
    return self;
}


@end
