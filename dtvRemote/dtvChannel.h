//
//  dtvChannel.h
//  dtvRemote
//
//  Created by Jed Lippold on 4/30/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface dtvChannel : NSObject

@property int identifier;
@property int number;
@property int logoId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *callsign;
@property (nonatomic, strong) NSString *category;
@property BOOL hd;
@property BOOL adult;

+ (UIImage *)getImageForChannel:(dtvChannel *)channel;
- (id) initWithProperties:(NSDictionary *) properties;

@end
