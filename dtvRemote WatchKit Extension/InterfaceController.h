//
//  InterfaceController.h
//  dtvRemote WatchKit Extension
//
//  Created by Jed Lippold on 7/12/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>

@interface InterfaceController : WKInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceButton *devicePicker;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *btnChannels;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *btnCommmands;
@property (nonatomic, weak) IBOutlet WKInterfaceTable *tableView;

@end
