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

@interface TodayViewController () <NCWidgetProviding>

@end

@implementation TodayViewController {
    NSMutableDictionary *devices;
    dtvDevice *currentDevice;
    NSMutableDictionary *commands;
    NSMutableDictionary *channels;
    NSMutableArray *favoriteChannels;
    NSMutableArray *favoriteCommands;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    devices = [dtvDevices getSavedDevicesForActiveNetwork];
    currentDevice = [dtvDevices getCurrentDevice];
    channels = [dtvChannels load:NO];
    
    favoriteChannels = [dtvChannels loadFavoriteChannels:channels];
    favoriteCommands = [dtvCommands getCommandArrayOfFavorites];
    
    
    [_deviceSegmentedControl removeAllSegments];
    
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
    
    [_cv setDataSource:self];
    [_cv setDelegate:self];
    
    [self.cv registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"Cell"];
    [self.cv registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"HeaderView"];

    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    [_cv reloadData];
    
    self.preferredContentSize = CGSizeMake(290, 340);
}


- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath; {
     return CGSizeMake(50, 50);
}


- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    UICollectionReusableView *reusableview = nil;
    
    if (kind == UICollectionElementKindSectionHeader) {
        UICollectionReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"HeaderView" forIndexPath:indexPath];
        UILabel *label = [[UILabel alloc] init];
        CGRect frm = _cv.frame;
        frm.size.height = 12;
        frm.origin.x = 2;
        frm.origin.y = 8;
        
        label.text = @"Favorite Channels";
        label.textColor = [Colors textColor];
        label.font = [UIFont fontWithName:@"Helvetica-Bold" size:12];
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = NSTextAlignmentLeft;
        label.frame = frm;
        //headerView.frame = frm;
        [headerView addSubview:label];
        reusableview = headerView;
    }
    
    return reusableview;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return CGSizeMake(290, 20.0f);
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *CellIdentifier = @"Cell";
    
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
    
    if (cell == nil) {
        cell = [[UICollectionViewCell alloc] init];
    }
    
    if (indexPath.section == 0) {
        NSString *chId = [favoriteChannels objectAtIndex:indexPath.row];
        dtvChannel *channel = channels[chId];
        UIImageView *iv = [[UIImageView alloc] init];
        iv.frame = CGRectMake(2.5f, 0, 45, 40);
        iv.image = [dtvChannel getImageForChannel:channel];
        
        UILabel *label = [[UILabel alloc] init];
        label.text = [NSString stringWithFormat:@"%d %@", channel.number, channel.name];
        label.textColor = [Colors textColor];
        label.font = [UIFont fontWithName:@"Helvetica" size:10];
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.frame = CGRectMake(0, 40, 50, 10);
        
        [cell addSubview:iv];
        [cell addSubview:label];
    }
    
    if (indexPath.section == 1) {
        id obj = [favoriteCommands objectAtIndex:indexPath.row];
        NSString *title;
        NSString *subTitle;
        
        if ([obj isKindOfClass:[dtvCommand class]]) {
            dtvCommand *c = [favoriteCommands objectAtIndex:indexPath.row];
            title = c.shortName;
            subTitle = c.commandDescription;
        } else {
            dtvCustomCommand *c = [favoriteCommands objectAtIndex:indexPath.row];
            title = c.abbreviation;
            subTitle = c.commandDescription;
        }
        
        UILabel *label = [[UILabel alloc] init];
        label.text = title;
        label.textColor = [Colors textColor];
        label.font = [UIFont fontWithName:@"Helvetica" size:10];
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = NSTextAlignmentCenter;
        
        UIButton *button = [[UIButton alloc] init];
        [button setTitleColor:[Colors textColor] forState:UIControlStateNormal];
        [button setTitleColor:[Colors backgroundColor] forState:UIControlStateHighlighted];
        [button setTitleColor:[Colors backgroundColor] forState:UIControlStateSelected];
        
        button.layer.borderColor = [Colors lightTextColor].CGColor;
        button.layer.borderWidth = 1.5f;
        button.layer.cornerRadius = 5;
        button.layer.masksToBounds = YES;
        [button setFrame:CGRectMake(0, 0, 50, 30)];
        [button setTitle:subTitle forState:UIControlStateNormal];
        
        [label setFrame:CGRectMake(0, 34, 50, 10)];
        [label setTextColor:[Colors textColor]];
        
        [cell addSubview:button];
        [cell addSubview:label];
        
    }

    
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

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
    if (section == 0) {
        return favoriteChannels.count;
    } else {
        return favoriteCommands.count;
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *chId = [favoriteChannels objectAtIndex:indexPath.row];
    dtvChannel *channel = channels[chId];
    
    [dtvCommands changeChannel:channel device:currentDevice];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData

    completionHandler(NCUpdateResultNewData);
}

@end
