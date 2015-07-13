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
#import "Colors.h"
#import "dtvCommands.h"
#import "dtvCommand.h"
#import "dtvCustomCommand.h"
#import "UIImage+FontAwesome.h"

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
    BOOL isCommandMode;
    NSMutableDictionary *commands;
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuide:)
                                                 name:@"messageUpdatedGuide" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedCurrentDevice:)
                                                 name:@"messageUpdatedCurrentDevice" object:nil];
    
    isCommandMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"watchKitCommandMode"];
    if (!isCommandMode) {
        isCommandMode = NO;
    }
    [self setButtonColors];
    
    devices = [dtvDevices getSavedDevicesForActiveNetwork];
    guide = [[NSMutableDictionary alloc] init];
    currentDevice = [dtvDevices getCurrentDevice];
    [self.devicePicker setTitle:currentDevice.name];
    commands = [dtvCommands getCommandsForSidebar:currentDevice];
    
    channels = [dtvChannels load:NO];
    sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
    rowData = [[NSMutableArray alloc] init];

    [self loadTableData];
    [self refreshGuide:nil];
}

- (void) loadTableData {
    if (isCommandMode) {
        [self loadCommandList];
    } else {
        [self loadChannelList];
    }
}

- (void) loadChannelList {
    NSMutableArray *rowTypes = [[NSMutableArray alloc] init];
    rowData = [[NSMutableArray alloc] init];
    
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
            //[row.image setImage:[dtvChannel getImageForChannel:channel]];
        }
    }
}

- (void) loadCommandList {
    
        
    NSMutableArray *rowTypes = [[NSMutableArray alloc] init];
    rowData = [[NSMutableArray alloc] init];
    
    NSArray *sections = [[commands allKeys]
                         sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    NSString *lastSection = @"";
    for (NSString *sectionKey in sections) {
        
        if (![sectionKey isEqualToString:lastSection]) {
            [rowTypes addObject:@"HeaderRowController"];
            lastSection = sectionKey;
            [rowData addObject:sectionKey];
        }
        
        NSMutableArray *sectionData = [commands objectForKey:sectionKey];
        
        NSArray *sortedArray = [sectionData sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            NSString *first = [(id) a sideBarSortIndex];
            NSString *second = [(id) b sideBarSortIndex];
            return [first compare:second];
        }];
        

        for (id obj in sortedArray) {
            [rowData addObject:obj];
            [rowTypes addObject:@"MainDeviceRowController"];
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
            id obj = rowData[i];
            
            UIImage *cellImage = [UIImage new];
            
            if ([obj isKindOfClass:[dtvCommand class]]) {
                dtvCommand *c = obj;
                [row.label setText:c.commandDescription];
                
                if (c.fontAwesome) {
                    cellImage = [UIImage imageWithIcon:[NSString stringWithFormat:@"fa-%@", c.fontAwesome]
                                       backgroundColor:[UIColor clearColor]
                                             iconColor:[Colors textColor]
                                               andSize:CGSizeMake(16, 16)];
                }
            } else {
                dtvCustomCommand *c = obj;
                [row.label setText:c.commandDescription];
                if (c.fontAwesome) {
                    cellImage = [UIImage imageWithIcon:[NSString stringWithFormat:@"fa-%@", c.fontAwesome]
                                       backgroundColor:[UIColor clearColor]
                                             iconColor:[Colors textColor]
                                               andSize:CGSizeMake(16, 16)];
                }
            }
            [row.image setImage:cellImage];
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
    if (isCommandMode) {
        id obj = rowData[rowIndex];
        if ([obj isKindOfClass:[dtvCommand class]]) {
            dtvCommand *c = obj;
            [dtvCommands sendCommand:c.dtvCommandText device:currentDevice];
        } else {
            dtvCustomCommand *c = obj;
            [dtvCommands sendCustomCommand:c];
        }
    } else {
        NSString *chId = rowData[rowIndex];
        dtvChannel *channel = channels[chId];
        [dtvCommands changeChannel:channel device:currentDevice];
    }
}

- (void) messageUpdatedCurrentDevice:(NSNotification *)notification {
    currentDevice = notification.object;
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    
    [self.devicePicker setTitle:currentDevice.name];
    [self loadTableData];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

-(IBAction)setCommandMode:(id)sender {
    isCommandMode = YES;
    [[NSUserDefaults standardUserDefaults] setBool:isCommandMode forKey:@"watchKitCommandMode"];
    [self setButtonColors];
    [self loadTableData];
}

-(IBAction)setChannelMode:(id)sender {
    isCommandMode = NO;
    [[NSUserDefaults standardUserDefaults] setBool:isCommandMode forKey:@"watchKitCommandMode"];
    [self setButtonColors];
    [self loadTableData];
}

- (void) setButtonColors {
    if (!isCommandMode) {
        [self.btnChannels setBackgroundColor:[Colors blueColor]];
        [self.btnCommmands setBackgroundColor:nil];
    } else {
        [self.btnChannels setBackgroundColor:nil];
        [self.btnCommmands setBackgroundColor:[Colors blueColor]];
    }
}

@end



