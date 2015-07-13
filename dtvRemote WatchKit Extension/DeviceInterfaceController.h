//
//  DeviceInterfaceController.h
//  dtvRemote
//
//  Created by Jed Lippold on 7/12/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>

@interface DeviceInterfaceController : WKInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *tableView;

@end
