//
//  SharedVars.h
//  dtvRemote
//
//  Created by Jed Lippold on 7/18/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "dtvDevice.h"

@interface SharedVars : NSObject

@property (nonatomic) NSMutableDictionary *channels;
@property (nonatomic) NSMutableArray *favoriteChannels;
@property (nonatomic) NSMutableArray *favoriteCommands;
@property (nonatomic) dtvDevice *currentDevice;

+ (SharedVars*) sharedInstance;


@end

