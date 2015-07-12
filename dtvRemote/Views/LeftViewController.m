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
#import "dtvCommands.h"
#import "Colors.h"
#import "iNet.h"
#import "MBProgressHUD.h"
#import "dtvIAP.h"
#import "UIImage+FontAwesome.h"

static NSString *kIdentifierMultiples = @"bz.jed.dtvRemote.multiples";


@interface LeftViewController ()

@end

@implementation LeftViewController {
    UIView *sideBarView;
    UITableView *sideBarTable;
    UIRefreshControl *refreshControl;
    NSMutableDictionary *devices;
    dtvDevice *currentDevice;
    NSString *ssid;
    NSArray *products;
    NSMutableArray *purchases;
    BOOL wasPurchased;
}

- (void)viewDidAppear:(BOOL)animated {
    //[self refreshDevicesStatus];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ssid = [iNet fetchSSID];
    
    [self getProducts:nil];

    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedStatusOfDevices:)
                                                 name:@"messageUpdatedStatusOfDevices" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedCurrentDevice:)
                                                 name:@"messageUpdatedCurrentDevice" object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedDevices:)
                                                 name:@"messageUpdatedDevices" object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageImportedCustomCommands:)
                                                 name:@"messageImportedCustomCommands" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageProductPurchased:) name:IAPHelperProductPurchasedNotification object:nil];
    
    devices = [dtvDevices getSavedDevicesForActiveNetwork];
    currentDevice = [dtvDevices getCurrentDevice];
    
    sideBarView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    sideBarView.backgroundColor = [Colors backgroundColor];
    
    CGRect navBarFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width * 0.75, 64.0);
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    bar.translucent = NO;
    bar.tintColor = [Colors tintColor];
    bar.barTintColor = [Colors navBGColor];
    bar.titleTextAttributes = @{NSForegroundColorAttributeName : [Colors textColor]};
    
    UINavigationItem *sideBarNavItem = [UINavigationItem alloc];
    sideBarNavItem.title = @"Devices & Settings";
    [bar pushNavigationItem:sideBarNavItem animated:false];
    
    [sideBarView addSubview:bar];
    
    CGRect tableFrame = [[UIScreen mainScreen] bounds];
    tableFrame.size.width = tableFrame.size.width * 0.75;
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
    [refreshControl addTarget:self action:@selector(refreshDevicesStatus:) forControlEvents:UIControlEventValueChanged];
    
    [sideBarTable addSubview:refreshControl];
    [sideBarView addSubview:sideBarTable];
    
    [self.view addSubview:sideBarView];
    [self refreshDevicesStatus:nil];
    

    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - TableView Management

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    cell.indentationLevel = 1;
    cell.indentationWidth = 2;
    cell.backgroundColor = [Colors backgroundColor];
    cell.userInteractionEnabled = YES;
    [cell setTintColor:[Colors tintColor]];
    [cell.textLabel setTextColor: [Colors textColor]];

}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *v = (UITableViewHeaderFooterView *)view;
    v.backgroundView.backgroundColor = [Colors backgroundColor];
    v.backgroundView.tintColor = [Colors tintColor];
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setTextColor:[Colors textColor]];
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        if ([ssid isEqualToString:@""]) {
            return @"Not on Wifi";
        } else {
            return ssid;
        }
    } else {
        return @"Actions";
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if (section == 0) {
        return [devices count];
    } else {
        BOOL purchased = ((int)[products count] == (int)[purchases count]);
        if (purchased) {
            return 4;
        } else {
            return 6;
        }
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
    
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *cellImage;
    
    if (indexPath.section == 0) {
        NSArray *keys = [[devices allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
        NSString *key = [keys objectAtIndex:indexPath.row];
        dtvDevice *thisDevice = devices[key];
        
        cell.textLabel.text = thisDevice.name;
        cell.detailTextLabel.textColor = [Colors textColor];
        
        if (thisDevice.lastChecked == nil) {
            cell.detailTextLabel.text = @"Checking...";
            
            cellImage = [UIImage imageWithIcon:@"fa-spinner"
                               backgroundColor:[UIColor clearColor]
                                     iconColor:[Colors textColor]
                                       andSize:CGSizeMake(16, 16)];
            
        } else if (thisDevice.online) {
            cell.detailTextLabel.text = @"Online";
            
            if ([thisDevice.identifier isEqualToString:currentDevice.identifier]) {
                
                cell.detailTextLabel.textColor = [Colors greenColor ];
                
                cell.detailTextLabel.text = @"Active Device";
                cellImage = [UIImage imageWithIcon:@"fa-check"
                                   backgroundColor:[UIColor clearColor]
                                         iconColor:[Colors greenColor]
                                           andSize:CGSizeMake(16, 16)];
            } else {
                
                cell.detailTextLabel.text = @"Ready";
                cellImage = [UIImage imageWithIcon:@"fa-check"
                                   backgroundColor:[UIColor clearColor]
                                         iconColor:[Colors textColor]
                                           andSize:CGSizeMake(16, 16)];
            }
            
        } else {
            cell.detailTextLabel.text = @"Offline";
            
            cellImage = [UIImage imageWithIcon:@"fa-exclamation-triangle"
                               backgroundColor:[UIColor clearColor]
                                     iconColor:[Colors textColor]
                                       andSize:CGSizeMake(16, 16)];
        }
        
    }
    
    if (indexPath.section == 1) {
        cell.detailTextLabel.text = @"";
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Scan network";
                cellImage = [UIImage imageWithIcon:@"fa-wifi"
                                   backgroundColor:[UIColor clearColor]
                                         iconColor:[Colors textColor]
                                           andSize:CGSizeMake(16, 16)];
                break;
            case 1:
                cell.textLabel.text = @"Clear these devices";
                cellImage = [UIImage imageWithIcon:@"fa-times"
                                   backgroundColor:[UIColor clearColor]
                                         iconColor:[Colors textColor]
                                           andSize:CGSizeMake(16, 16)];
                break;
            case 2:
                cell.textLabel.text = [NSString stringWithFormat:@"Change location: %@",
                                       [[NSUserDefaults standardUserDefaults] stringForKey:@"zip"]];
                cellImage = [UIImage imageWithIcon:@"fa-location-arrow"
                                   backgroundColor:[UIColor clearColor]
                                         iconColor:[Colors textColor]
                                           andSize:CGSizeMake(16, 16)];
                break;
            case 3:
                cell.textLabel.text = @"Import custom commands";
                cellImage = [UIImage imageWithIcon:@"fa-cloud-download"
                                   backgroundColor:[UIColor clearColor]
                                         iconColor:[Colors textColor]
                                           andSize:CGSizeMake(16, 16)];
                break;
            case 4:
                cell.textLabel.text = @"Unlock all features";
                cellImage = [UIImage imageWithIcon:@"fa-unlock-alt"
                                   backgroundColor:[UIColor clearColor]
                                         iconColor:[Colors textColor]
                                           andSize:CGSizeMake(16, 16)];
                break;
            case 5:
                cell.textLabel.text = @"Restore purchases";
                cellImage = [UIImage imageWithIcon:@"fa-recycle"
                                   backgroundColor:[UIColor clearColor]
                                         iconColor:[Colors textColor]
                                           andSize:CGSizeMake(16, 16)];
                break;
        }
    }
    
    cell.imageView.image = cellImage;
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        if (wasPurchased) {
            
            NSArray *keys = [[devices allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
            NSString *deviceId = keys[indexPath.row];
            dtvDevice *device = [devices objectForKey:deviceId];
            
            [dtvDevices setCurrentDevice:device];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageCloseLeftMenu"
                                                                object:nil];
        } else {
            [self askToBuy];
        }
    }
    
    if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0:
                [self refreshDevices:nil];
                break;
            case 1:
                [self clearDevices];
                break;
            case 2:
                [self setZipCode];
                break;
            case 3:
                [self importCommands];
                break;
            case 4:
                [self unlock:nil];
                break;
            case 5:
                [self restorePurchases:nil];
                break;
        }
    }
}


#pragma mark - Actions

- (IBAction)unlock:(id)sender {
    if ([products count] > 0 ) {
        SKProduct *product = [products objectAtIndex:0];
        [[dtvIAP sharedInstance] buyProduct:product];
    }
}

- (void)restorePurchases:(id)sender {
    [[dtvIAP sharedInstance] restoreCompletedTransactions];
}


- (IBAction) getProducts:(id)sender {
    
#if TARGET_IPHONE_SIMULATOR
    wasPurchased = YES;
#else
    [[dtvIAP sharedInstance] requestProductsWithCompletionHandler:^(BOOL success, NSArray *p) {
        if (success) {
            products = p;
            [self reloadTable];
            wasPurchased = NO;
            purchases = [[NSMutableArray alloc] init];
            if ([[dtvIAP sharedInstance] productPurchased:kIdentifierMultiples]) {
                wasPurchased = YES;
                [purchases addObject:kIdentifierMultiples];
                [self reloadTable];
            }
        }
    }];
#endif
}

- (IBAction)refreshDevices:(id)sender {
    
    UIAlertController *view = [UIAlertController
                               alertControllerWithTitle:@"Refresh Devices"
                               message:@"Are you sure you would like to search this network for available devices?"
                               preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:
                             ^(UIAlertAction * action) {
                                 [view dismissViewControllerAnimated:YES completion:nil];
                                 return;
                             }];
    
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:
                         ^(UIAlertAction * action) {
                             [view dismissViewControllerAnimated:YES completion:nil];

                             [[NSNotificationCenter defaultCenter] postNotificationName:@"messageCloseLeftMenu"
                                                                                 object:nil];
                             
                             [[NSNotificationCenter defaultCenter] postNotificationName:@"messageRefreshDevices"
                                                                                 object:nil];
                             return;
                         }];
    
    [view addAction:ok];
    [view addAction:cancel];
    
    UIViewController *vc = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [vc presentViewController:view animated:YES completion:nil];

}

- (IBAction)refreshDevicesStatus:(id)sender  {
    [refreshControl endRefreshing];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        ssid = [iNet fetchSSID];
        devices = [dtvDevices getSavedDevicesForActiveNetwork];
        currentDevice = [dtvDevices getCurrentDevice];
        [self reloadTable];
        [self checkDeviceStatus];
    });
}

- (void) importCommands {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Import Commands"
                                                                   message:@"Please enter a URL to import commands" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* accept =
    [UIAlertAction actionWithTitle:@"Import" style:UIAlertActionStyleDefault handler:
     ^(UIAlertAction * action){
         
         UITextField *textField = alert.textFields.firstObject;
         NSString *url = textField.text;

         [[NSUserDefaults standardUserDefaults] setObject:url forKey:@"url"];
         [[NSUserDefaults standardUserDefaults] synchronize];
         
         NSURL *testUrl = [NSURL URLWithString:url];
         if (testUrl && testUrl.scheme && testUrl.host) {
         } else {
             [self importCommands];
             return;
         }
         
         MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
         hud.mode = MBProgressHUDModeIndeterminate;
         hud.labelText = [NSString stringWithFormat:@"Importing Commands from %@", url];
         [dtvCommands loadCustomCommandsFromUrl:url];
         
     }];
    
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:
                             ^(UIAlertAction * action) {
                                 [self dismissViewControllerAnimated:YES completion:nil];
                                 return;
                             }];
    

    [alert addAction:cancel];
    [alert addAction:accept];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"url"];
        textField.keyboardType = UIKeyboardTypeURL;
        textField.placeholder = @"http://somesite.com/settings.json";
    }];
    
    [self presentViewController:alert animated:YES completion:nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageCloseLeftMenu"
                                                        object:nil];
}

- (void) setZipCode {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messagePromptForZipCode"
                                                        object:nil];
}

- (void) setChannelLogos {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageDownloadChannelLogos"
                                                        object:nil];
}
- (void) clearDevices {
    
    UIAlertController *view = [UIAlertController
                               alertControllerWithTitle:@"Clear Devices"
                               message:@"Are you sure you would like to clear all devices on this network?"
                               preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:
                             ^(UIAlertAction * action) {
                                 [view dismissViewControllerAnimated:YES completion:nil];
                                 return;
                             }];
    
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:
                         ^(UIAlertAction * action) {
                             [view dismissViewControllerAnimated:YES completion:nil];
                             
                             dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                                 [dtvDevices clearDevicesForNetwork];
                                 [self refreshDevices:nil];
                             });
                             
                             return;
                         }];
    
    [view addAction:ok];
    [view addAction:cancel];
    
    UIViewController *vc = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [vc presentViewController:view animated:YES completion:nil];
    

}

- (void) askToBuy {
    
    UIAlertController *view = [UIAlertController
                               alertControllerWithTitle:@"Upgrade Needed"
                               message:@"Would you like to purchase the full app to unlock switching devices?"
                               preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:
                             ^(UIAlertAction * action) {
                                 [view dismissViewControllerAnimated:YES completion:nil];
                                 return;
                             }];
    
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:
                         ^(UIAlertAction * action) {
                             [view dismissViewControllerAnimated:YES completion:nil];
                             [self unlock:nil];
                             return;
                         }];
    
    [view addAction:ok];
    [view addAction:cancel];
    
    UIViewController *vc = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [vc presentViewController:view animated:YES completion:nil];
}

- (void) messageImportedCustomCommands:(NSNotification *)notification {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    if (currentDevice) {
        [dtvDevices setCurrentDevice:currentDevice];
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Custom Commands"
                                                                   message:notification.object preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* accept = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:accept];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void) messageUpdatedStatusOfDevices:(NSNotification *)notification {
    devices = notification.object;
    [self reloadTable];
}
- (void) messageUpdatedCurrentDevice:(NSNotification *)notification {
    currentDevice = notification.object;
    [self reloadTable];
}

- (void) messageUpdatedDevices:(NSNotification *)notification {
    devices = notification.object;
    ssid = [iNet fetchSSID];
    [self reloadTable];
    [self checkDeviceStatus];
}

- (void)messageProductPurchased:(NSNotification *)notification {
    [self getProducts:nil];
}

- (void) reloadTable {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [sideBarTable reloadData];
    }];
}

- (void) checkDeviceStatus {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [dtvDevices checkStatusOfDevices:devices];
    });
}
@end
