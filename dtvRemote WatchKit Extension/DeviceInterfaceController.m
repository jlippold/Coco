//
//  DeviceInterfaceController.m
//  dtvRemote
//
//  Created by Jed Lippold on 7/12/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "DeviceInterfaceController.h"
#import "DeviceRowController.h"
#import "dtvDevices.h"
#import "Colors.h"

@interface DeviceInterfaceController ()

@end

@implementation DeviceInterfaceController {
    NSMutableDictionary *devices;
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedStatusOfDevices:)
                                                 name:@"messageUpdatedStatusOfDevices" object:nil];
    
    devices = [dtvDevices getSavedDevicesForActiveNetwork];
    [self loadTable];
    [self checkDeviceStatus];
}

- (void) loadTable {
    NSArray *keys = [[devices allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [self.tableView setNumberOfRows:keys.count withRowType:@"DeviceRowController"];
    
    for (NSInteger i = 0; i < keys.count; i++) {
        
        NSString *key = [keys objectAtIndex:i];
        dtvDevice *thisDevice = devices[key];
        DeviceRowController *row = [self.tableView rowControllerAtIndex:i];
        if (!thisDevice.online) {
            [row.label setTextColor:[Colors redColor]];
        } else {
            [row.label setTextColor:[Colors greenColor]];
        }
        [row.label setText:thisDevice.name];
    }
}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndex:(NSInteger)rowIndex {
    
    NSArray *keys = [[devices allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *key = [keys objectAtIndex:rowIndex];
    dtvDevice *device = devices[key];
    [dtvDevices setCurrentDevice:device];
    [self popToRootController];
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super didDeactivate];
    
}

- (void) dealloc {
}

- (void) checkDeviceStatus {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [dtvDevices checkStatusOfDevices:devices];
    });
}

- (void) messageUpdatedStatusOfDevices:(NSNotification *)notification {
    devices = notification.object;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self loadTable];
    }];
}

@end



