//
//  LeftViewController.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/10/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "LeftViewController.h"
#import "dtvDevices.h"
#import "dtvDevice.h"
#import "Colors.h"
#import "iNet.h"


@interface LeftViewController ()

@end

@implementation LeftViewController {
    UIView *sideBarView;
    UITableView *sideBarTable;
    UIRefreshControl *refreshControl;
    NSMutableDictionary *devices;
    dtvDevice *currentDevice;
    NSString *ssid;
}

- (void)viewWillAppear:(BOOL)animated {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        ssid = [iNet fetchSSID];
        [dtvDevices checkStatusOfDevices:devices];
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ssid = [iNet fetchSSID];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedStatusOfDevices:)
                                                 name:@"messageUpdatedStatusOfDevices" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedCurrentDevice:)
                                                 name:@"messageUpdatedCurrentDevice" object:nil];
    
    
    devices = [dtvDevices getSavedDevicesForActiveNetwork];
    currentDevice = [dtvDevices getCurrentDevice];
    
    sideBarView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    CGRect navBarFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width * 0.75, 64.0);
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    bar.translucent = NO;
    bar.tintColor = [Colors tintColor];
    bar.barTintColor = [Colors navBGColor];
    bar.titleTextAttributes = @{NSForegroundColorAttributeName : [Colors textColor]};
    
    UINavigationItem *sideBarNavItem = [UINavigationItem alloc];
    sideBarNavItem.title = @"Device Settings";
    [bar pushNavigationItem:sideBarNavItem animated:false];
    
    [sideBarView addSubview:bar];
    
    CGRect tableFrame = [[UIScreen mainScreen] bounds];
    tableFrame.size.width = tableFrame.size.width;
    tableFrame.size.height = tableFrame.size.height - 64;
    tableFrame.origin.x = 0;
    tableFrame.origin.y = 64;
    sideBarTable = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStyleGrouped];
    sideBarTable.frame = tableFrame;
    
    sideBarTable.dataSource = self;
    sideBarTable.delegate = self;
    sideBarTable.separatorColor = [Colors seperatorColor];
    sideBarTable.backgroundColor = [UIColor clearColor];
    
    refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refreshDevices:) forControlEvents:UIControlEventValueChanged];
    
    [sideBarTable addSubview:refreshControl];
    [sideBarView addSubview:sideBarTable];
    
    [self.view addSubview:sideBarView];
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - TableView Management

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    cell.indentationLevel = 1;
    cell.indentationWidth = 2;
    cell.backgroundColor = [Colors backgroundColor];
    cell.userInteractionEnabled = YES;
    [cell setTintColor:[Colors tintColor]];
    
    if (indexPath.section == 0) {
        [cell.textLabel setTextColor: [Colors textColor]];
        [cell.detailTextLabel setTextColor:[Colors textColor]];
    } else {
        [cell.textLabel setTextColor: [Colors blueColor]];
        [cell.detailTextLabel setTextColor:[Colors textColor]];
    }

}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *v = (UITableViewHeaderFooterView *)view;
    v.backgroundView.backgroundColor = [UIColor blackColor];
    v.backgroundView.alpha = 0.9;
    v.backgroundView.tintColor = [Colors tintColor];
    
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setTextColor:[Colors textColor]];
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) { //Devices
        return ssid;
    } else {    //Commands
        return @"Actions";
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if (section == 0) { //Devices
        return [devices count];
    } else {    //Commands
        return 3;
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
            [cell.detailTextLabel setTextColor:[Colors redColor]];
        }
        
        if ([thisDevice.identifier isEqualToString:currentDevice.identifier]) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        }
    }
    
    if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Check devices status";
                break;
            case 1:
                cell.textLabel.text = @"Scan network for new devices";
                break;
            case 2:
                cell.textLabel.text = @"Forget these devices";
                break;
        }
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

    }
}


#pragma mark - Actions

- (IBAction)refreshDevices:(id)sender {
    [refreshControl endRefreshing];
    //[self.sideBar dismiss];
    //[self toggleOverlay:@"show"];
    //overlayLabel.text = @"Scanning wifi network for devices...";
    [UIApplication sharedApplication].statusBarHidden = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [dtvDevices refreshDevicesForNetworks];
    });
}

- (void) messageUpdatedStatusOfDevices:(NSNotification *)notification {
    devices = notification.object;
    [sideBarTable reloadData];
}
- (void) messageUpdatedCurrentDevice:(NSNotification *)notification {
    currentDevice = notification.object;
}

@end
