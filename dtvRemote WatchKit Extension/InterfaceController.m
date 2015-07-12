//
//  InterfaceController.m
//  dtvRemote WatchKit Extension
//
//  Created by Jed Lippold on 7/12/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "InterfaceController.h"
#import "TableRowController.h"
#import "HeaderRowController.h"
#import "dtvChannels.h"
#import "dtvChannel.h"
#import "dtvDevice.h"
#import "dtvDevices.h"
#import "dtvGuide.h"
#import "dtvGuideItem.h"
#import "dtvCommands.h"

@interface InterfaceController()

@end


@implementation InterfaceController {
    NSMutableDictionary *channels;
    NSMutableDictionary *devices;
    NSMutableDictionary *guide;
    dtvDevice *currentDevice;
    NSMutableDictionary *sortedChannels;
    NSMutableArray *rowData;
    BOOL guideIsRefreshing;
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuide:)
                                                 name:@"messageUpdatedGuide" object:nil];
    
    devices = [dtvDevices getSavedDevicesForActiveNetwork];
    guide = [[NSMutableDictionary alloc] init];
    currentDevice = [dtvDevices getCurrentDevice];
    [self.devicePicker setTitle:currentDevice.name];

    channels = [dtvChannels load:NO];
    sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
    rowData = [[NSMutableArray alloc] init];
    
    [self loadTableData];
    [self refreshGuide:nil];
    
}

- (void) loadTableData {

    NSMutableArray *rowTypes = [[NSMutableArray alloc] init];

    
    NSArray *sections = [[sortedChannels allKeys]
                         sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    NSString *lastSection = @"";
    for (NSString *sectionName in sections) {
        
        if (![sectionName isEqualToString:lastSection]) {
            [rowTypes addObject:@"HeaderRowController"];
            lastSection = sectionName;
            [rowData addObject:sectionName];
        }
        
        NSMutableDictionary *sectionData = [sortedChannels objectForKey:sectionName];
        NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
        for (id sectionChannelKey in sectionChannels) {
            NSString *chId = sectionChannelKey;
            [rowData addObject:chId];
            [rowTypes addObject:@"TableRowController"];
        }
    }
    
    [self.tableView setRowTypes:rowTypes];
    
    for (NSInteger i = 0; i < rowTypes.count; i++) {
        
        NSString* rowType = rowTypes[i];
        if ([rowType isEqualToString:@"HeaderRowController"]) {
            HeaderRowController *row = [self.tableView rowControllerAtIndex:i];
            [row.label setText:rowData[i]];
        } else {
            TableRowController *row = [self.tableView rowControllerAtIndex:i];
            NSString *chId = rowData[i];
            dtvChannel *channel = channels[chId];
            dtvGuideItem *guideItem = guide[chId];
            
            [row.label setText: (guideItem) ? guideItem.title : channel.name];
            [row.image setImage:[dtvChannel getImageForChannel:channel]];
        }
    }
}

- (void) messageUpdatedGuide:(NSNotification *)notification {
    guide = notification.object;
    guideIsRefreshing = NO;
    sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self loadTableData];
    }];
}


- (IBAction) refreshGuide:(id)sender {
    if (!guideIsRefreshing) {
        guideIsRefreshing = YES;
        NSDate *dt = [dtvGuide getHalfHourIncrement:[NSDate date]];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [dtvGuide refreshGuide:channels sorted:sortedChannels forTime:dt];
        });
    }
}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndex:(NSInteger)rowIndex {

    NSString *chId = rowData[rowIndex];
    dtvChannel *channel = channels[chId];    
    [dtvCommands changeChannel:channel device:currentDevice];

}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

@end



