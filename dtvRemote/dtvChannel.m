//
//  dtvChannel.m
//  dtvRemote
//
//  Created by Jed Lippold on 4/30/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "dtvChannel.h"
#import <UIKit/UIKit.h>

@implementation dtvChannel


- (id) initWithProperties:(NSDictionary *)properties {
    
    if (self = [super init])
    {
        _identifier = [properties[@"chId"] intValue];
        _number = [properties[@"chNum"] intValue];
        _name = properties[@"chName"];
        _callsign = properties[@"chCall"];
        _category = properties[@"chCat"];
        _logoId = [properties[@"chLogoId"] intValue];
        _hd = NO;
        if ([[properties[@"chHd"] stringValue] isEqualToString:@"1"]) {
            _hd = YES;
        }
        _adult = NO;
        if ([[properties[@"chAdult"] stringValue] isEqualToString:@"1"]) {
            _adult = YES;
        }


    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *) coder
{
    [coder encodeInt:_identifier forKey:@"identifier"];
    [coder encodeInt:_number forKey:@"number"];
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_category forKey:@"category"];
    [coder encodeObject:_callsign forKey:@"callsign"];
    [coder encodeInt:_logoId forKey:@"logoId"];
    [coder encodeBool:_hd forKey:@"hd"];
    [coder encodeBool:_adult forKey:@"adult"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _identifier = [decoder decodeIntForKey:@"identifier"];
        _number = [decoder decodeIntForKey:@"number"];
        _logoId = [decoder decodeIntForKey:@"logoId"];
        _hd = [decoder decodeBoolForKey:@"hd"];
        _adult = [decoder decodeBoolForKey:@"adult"];
        _name = [decoder decodeObjectForKey:@"name"];
        _callsign = [decoder decodeObjectForKey:@"callsign"];
        _category = [decoder decodeObjectForKey:@"category"];
    }
    return self;
}

+ (UIImage *) getImageForChannel:(dtvChannel *)channel {
    
    UIImage *image = [UIImage new];
    NSString *cacheDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *imagePath =[cacheDirectory stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%d.png", channel.identifier]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        image = [UIImage imageWithContentsOfFile:imagePath];
    }
    return image;
}

@end
