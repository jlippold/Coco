//
//  SideBar.m
//  dtvRemote
//
//  Created by Jed Lippold on 4/7/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "SideBarTableView.h"
#import "dtvDevices.h"
#import "dtvDevice.h"
#import "dtvCommands.h"
#import "dtvCommand.h"


@implementation SideBarTableView {
    UIColor *textColor;
    UIColor *backgroundColor;
    UIColor *tableBackgroundColor;
    UIColor *seperatorColor;
    UIColor *boxBackgroundColor;
    UIColor *navBGColor;
    UIColor *tint;
    NSArray *commands;
    
    NSMutableDictionary *devices;
    dtvDevice *currentDevice;
    
}


-(id) init {
    self = [super init];
    
    devices = [dtvDevices getSavedDevicesForActiveNetwork];
    currentDevice = [dtvDevices getCurrentDevice];
    
    commands = [dtvCommands getArrayOfCommands];
    
    textColor = [UIColor colorWithRed:193/255.0f green:193/255.0f blue:193/255.0f alpha:1.0f];
    backgroundColor = [UIColor colorWithRed:30/255.0f green:30/255.0f blue:30/255.0f alpha:1.0f];
    boxBackgroundColor = [UIColor colorWithRed:28/255.0f green:28/255.0f blue:28/255.0f alpha:1.0f];
    navBGColor = [UIColor colorWithRed:23/255.0f green:23/255.0f blue:23/255.0f alpha:1.0f];
    tint = [UIColor colorWithRed:30/255.0f green:147/255.0f blue:212/255.0f alpha:1.0f];
    seperatorColor = [UIColor colorWithRed:40/255.0f green:40/255.0f blue:40/255.0f alpha:1.0f];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedStatusOfDevices:)
                                                 name:@"messageUpdatedStatusOfDevices" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedCurrentDevice:)
                                                 name:@"messageUpdatedCurrentDevice" object:nil];
    
    
    
    return self;
}

- (void)refresh:(UIRefreshControl *)refreshControl {
    [refreshControl endRefreshing];
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    cell.indentationLevel = 1;
    cell.indentationWidth = 2;
    //cell.accessoryType = UITableViewCellAccessoryNone;
    cell.backgroundColor = tableBackgroundColor;
    [cell.textLabel setTextColor: textColor];
    [cell.detailTextLabel setTextColor:textColor];
    
    cell.userInteractionEnabled = YES;
    [cell setTintColor:tint];
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return  18.0;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *v = (UITableViewHeaderFooterView *)view;
    v.backgroundView.backgroundColor = [UIColor blackColor];
    v.backgroundView.alpha = 0.9;
    v.backgroundView.tintColor = tint;
    
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setTextColor:textColor];
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) { //Devices
        return @"Devices";
    } else {    //Commands
        return @"Commands";
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if (section == 0) { //Devices
        return [devices count];
    } else {    //Commands
        return [commands count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CellPicker"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CellPicker"];
    }
    
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    cell.userInteractionEnabled = YES;
    cell.detailTextLabel.enabled = YES;
    
    if (indexPath.section == 0) {
        NSArray *keys = [[devices allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
        NSString *key = [keys objectAtIndex:indexPath.row];
        dtvDevice *thisDevice = devices[key];
        
        cell.textLabel.text = thisDevice.name;
        if (thisDevice.online) {
            cell.detailTextLabel.text = @"Online";
        } else {
            cell.detailTextLabel.text = @"Offline";
            cell.detailTextLabel.textColor = [UIColor redColor];
        }

        if ([thisDevice.identifier isEqualToString:currentDevice.identifier]) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        }
    }
    
    if (indexPath.section == 1) {
        dtvCommand *c = [commands objectAtIndex:indexPath.row];
        cell.textLabel.text = c.description;
        cell.detailTextLabel.text = c.action;
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        NSArray *keys = [[devices allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        NSString *deviceId = keys[indexPath.row];
        dtvDevice *device = [devices objectForKey:deviceId];
        if (device.online) {
            [dtvDevices setCurrentDevice:device];
        }
        
    }
    if (indexPath.section == 1) {
        dtvCommand *c = [commands objectAtIndex:indexPath.row];
        [dtvCommands sendCommand:c.action device:currentDevice];
    }
    
    
}

- (void) messageUpdatedStatusOfDevices:(NSNotification *)notification {
    devices = notification.object;
}
- (void) messageUpdatedCurrentDevice:(NSNotification *)notification {
    currentDevice = notification.object;
}

@end
