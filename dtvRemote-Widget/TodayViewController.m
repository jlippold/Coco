//
//  TodayViewController.m
//  dtvRemote-Widget
//
//  Created by Jed Lippold on 7/4/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import "dtvDevices.h"
#import "dtvDevice.h"
#import "dtvChannels.h"
#import "dtvChannel.h"
#import "dtvCommands.h"
#import "Colors.h"
#import "CVCell.h"
#import "CVHeader.h"
#import "UIImage+FontAwesome.h"
#import "iNet.h"

static NSString *kIdentifierMultiples = @"bz.jed.dtvRemote.multiples";
static NSString *const reuseIdentifier = @"CVCell";
static NSString *const headerReuseIdentifier = @"CVHeader";

@interface TodayViewController () <NCWidgetProviding>

@property(nonatomic, copy) void (^completionHandler)(NCUpdateResult);
@property(nonatomic) BOOL hasSignaled;

@end

@implementation TodayViewController {
    NSMutableDictionary *devices;
    dtvDevice *currentDevice;
    NSMutableDictionary *commands;
    NSMutableDictionary *channels;
    NSMutableArray *favoriteChannels;
    NSMutableArray *favoriteCommands;
    NSString *ssid;
    BOOL purchased;
    NSUInteger totalChannels;
    NSUInteger totalCommands;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = @"";
    lbl.textColor = [Colors textColor];


    CGRect frm = self.view.frame;
    frm.size.height = 12;
    frm.origin.y = _deviceSegmentedControl.frame.origin.y;
    frm.origin.x = 0;
    lbl.frame = frm;
    
    lbl.font = [UIFont fontWithName:@"Helvetica-Bold" size:12];
    lbl.hidden = YES;
    [self.view addSubview:lbl];
    
    [_deviceSegmentedControl removeAllSegments];
    devices = [dtvDevices getSavedDevicesForActiveNetwork];
    currentDevice = [dtvDevices getCurrentDevice];
    
    ssid = [iNet fetchSSID];
    if ([ssid isEqualToString:@""] || devices.count == 0) {
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.text = [ssid isEqualToString:@""] ? @"Please connect to a wireless network":
        [NSString stringWithFormat:@"Open the app to scan devices on the %@ network", ssid];
        
        lbl.alpha = 0.6;
        lbl.hidden = NO;
        _deviceSegmentedControl.hidden = YES;
        self.preferredContentSize = CGSizeMake(320, 30);
        return;
    }
    
    channels = [dtvChannels load:NO];
    
    favoriteChannels = [dtvChannels loadFavoriteChannels:channels];
    favoriteCommands = [dtvCommands getCommandArrayOfFavorites:currentDevice];
    
    [_deviceSegmentedControl addTarget:self
                         action:@selector(chooseDevice:)
               forControlEvents:UIControlEventValueChanged];
    

#if TARGET_IPHONE_SIMULATOR
    purchased = YES;
#else
    purchased = [[NSUserDefaults standardUserDefaults] boolForKey:kIdentifierMultiples];
#endif
    
    if (purchased) {
        NSArray *keys = [[devices allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        int i;
        for (i = 0; i < [keys count]; i++) {
            NSString *key = [keys objectAtIndex:i];
            dtvDevice *thisDevice = devices[key];
            [_deviceSegmentedControl insertSegmentWithTitle:thisDevice.name atIndex:i animated:NO];
            if ([thisDevice.identifier isEqualToString:currentDevice.identifier]) {
                _deviceSegmentedControl.selectedSegmentIndex = i;
            }
        }
    } else {
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.text = @"Upgrade to enable device switching";
        lbl.hidden = NO;
        _deviceSegmentedControl.hidden = YES;

    }

    [_cv setDataSource:self];
    [_cv setDelegate:self];
    
    [self.cv registerClass:[CVHeader class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:headerReuseIdentifier];
    
    [self.cv registerClass:[CVCell class] forCellWithReuseIdentifier:reuseIdentifier];
    
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        [self reloadViews];
    });


}

- (void) reloadViews {
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        totalChannels = favoriteChannels.count > 10 ? 10 : favoriteChannels.count;
        totalCommands = favoriteCommands.count > 10 ? 10 : favoriteCommands.count;
        
        NSUInteger totalRows = 0;
        totalRows += totalCommands > 5 ? 2 : 1;
        totalRows += totalChannels > 5 ? 2 : 1;
        

        NSUInteger height = (112 + (totalRows*54));
        
        //NSUInteger lastHeight = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastHeight"];
        
        self.preferredContentSize = CGSizeMake(320, height);
        [self.cv reloadData];
        [self.cv layoutIfNeeded];
        [self signalComplete:NCUpdateResultNewData];
        
        [[NSUserDefaults standardUserDefaults] setInteger:height forKey:@"lastHeight"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];


}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath; {
     return CGSizeMake(50, 50);
}


- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    
    CVHeader *header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:headerReuseIdentifier forIndexPath:indexPath];
    
    UILabel *myLabel = (UILabel *)[header viewWithTag:1];
    if (!myLabel) {
        myLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [_cv bounds].size.width, 26)];
        myLabel.tag = 1;
        [myLabel setBackgroundColor:[[Colors backgroundColor] colorWithAlphaComponent:0.4f]];
        [myLabel setFont:[UIFont boldSystemFontOfSize:14.0f]];
        myLabel.textColor = [Colors textColor];
        [myLabel setOpaque:YES];
    }
    
    myLabel.text = indexPath.section == 0 ? @"    Favorite Channels" : @"    Favorite Commands";
    [header addSubview:myLabel];
    return header;

}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return CGSizeMake(320, 20.0f);
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    CVCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    cell.label.text = @"";
    cell.label.textColor = [Colors textColor];
    
    if (indexPath.section == 0) {
        NSString *chId = [favoriteChannels objectAtIndex:indexPath.row];
        dtvChannel *channel = channels[chId];
        cell.iv.frame = CGRectMake(2.5f, 0, 45, 40);
        cell.iv.image = [dtvChannel getImageForChannel:channel];
        cell.label.text = [NSString stringWithFormat:@"%d %@", channel.number, channel.name];
        cell.iv.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    if (indexPath.section == 1) {
        id obj = [favoriteCommands objectAtIndex:indexPath.row];
        NSString *title;
        NSString *fontAwesome;
        
        if ([obj isKindOfClass:[dtvCommand class]]) {
            dtvCommand *c = [favoriteCommands objectAtIndex:indexPath.row];
            title = c.commandDescription;
            fontAwesome = [NSString stringWithFormat:@"fa-%@", c.fontAwesome];
        } else {
            dtvCustomCommand *c = [favoriteCommands objectAtIndex:indexPath.row];
            title = c.commandDescription;
            fontAwesome = [NSString stringWithFormat:@"fa-%@", c.fontAwesome];
        }

        UIImage *cellImage = [UIImage imageWithIcon:fontAwesome
                                    backgroundColor:[UIColor clearColor]
                                          iconColor:[Colors textColor]
                                            andSize:CGSizeMake(16, 16)];

        cell.iv.contentMode = UIViewContentModeCenter;
        cell.iv.frame = CGRectMake(0, 0, 50, 50);
        cell.iv.image = cellImage;

        cell.label.text = [NSString stringWithFormat:@"%@", title];
        
    }
    
    cell.spinner.hidden = YES;

    return cell;
}

- (NSInteger)numberOfSectionsInCollectionView: (UICollectionView *)collectionView {
    int sections = 0;
    if (favoriteCommands && [favoriteCommands count] > 0) {
        sections++;
    }
    if (favoriteChannels && [favoriteChannels count] > 0) {
        sections++;
    }
    return sections;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(10, 14, 10, 14);
}

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
    if (section == 0) {
        return totalChannels;
    } else {
        return totalCommands;
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    CVCell *cell = (CVCell *)[_cv cellForItemAtIndexPath:indexPath];

    [cell.spinner startAnimating];
    cell.iv.hidden = YES;
    cell.spinner.hidden = NO;
    
    
    if (indexPath.section == 0) {
        NSString *chId = [favoriteChannels objectAtIndex:indexPath.row];
        dtvChannel *channel = channels[chId];
        [dtvCommands changeChannel:channel device:currentDevice];
    } else {
        id obj = [favoriteCommands objectAtIndex:indexPath.row];
        
        if ([obj isKindOfClass:[dtvCommand class]]) {
            dtvCommand *c = [favoriteCommands objectAtIndex:indexPath.row];
            [dtvCommands sendCommand:c.dtvCommandText device:currentDevice];
        } else {
            dtvCustomCommand *c = [favoriteCommands objectAtIndex:indexPath.row];
            [dtvCommands sendCustomCommand:c];
        }
    }
    
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.7);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        cell.iv.hidden = NO;
        cell.spinner.hidden = YES;
        [cell.spinner stopAnimating];
    });
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (!self.hasSignaled) [self signalComplete:NCUpdateResultFailed];
}

- (void)signalComplete:(NCUpdateResult)updateResult {
    //NSLog(@"Signaling complete: %lu", updateResult);
    self.hasSignaled = YES;
    if (self.completionHandler) self.completionHandler(updateResult);
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    NSUInteger lastHeight = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastHeight"];
    
    if (lastHeight) {
        self.preferredContentSize = CGSizeMake(320, lastHeight);
    } else {
        self.preferredContentSize = CGSizeMake(320, 100);
    }

    
    self.completionHandler = completionHandler;
    
}

-(UIEdgeInsets)widgetMarginInsetsForProposedMarginInsets:(UIEdgeInsets)defaultMarginInsets {
    return UIEdgeInsetsZero;
}

- (void)chooseDevice:(id) sender {
    NSInteger selectedSegment = _deviceSegmentedControl.selectedSegmentIndex;
    
    NSArray *keys = [[devices allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *deviceId = keys[selectedSegment];
    
    dtvDevice *device = [devices objectForKey:deviceId];
    [dtvDevices setCurrentDevice:device];
    currentDevice = device;
    
    favoriteCommands = [dtvCommands getCommandArrayOfFavorites:currentDevice];
    [self reloadViews];
    

}


@end
