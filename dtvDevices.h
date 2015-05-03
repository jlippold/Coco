//
//  dtvDevices.h
//  dtvRemote
//
//  Created by Jed Lippold on 5/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "dtvDevice.h"

@interface dtvDevices : NSObject

+ (void) refreshDevicesForNetworks;
+ (void) checkStatusOfDevices;

+ (dtvDevice *) getCurrentDevice;
+ (NSMutableDictionary *) getSavedDevicesForActiveNetwork;

+ (void) saveCurrentDeviceId:(NSString *) deviceId;

@end
