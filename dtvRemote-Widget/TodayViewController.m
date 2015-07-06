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
    NSMutableDictionary *channels;
    NSMutableArray *favoriteChannels;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    devices = [dtvDevices getSavedDevicesForActiveNetwork];
    currentDevice = [dtvDevices getCurrentDevice];
    channels = [dtvChannels load:NO];
    favoriteChannels = [dtvChannels loadFavoriteChannels:channels];
    
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
    
}


- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath; {
     return CGSizeMake(50, 50);
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *CellIdentifier = @"Cell";
    
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
    
    if (cell == nil) {
        cell = [[UICollectionViewCell alloc] init];
    }
    
    NSString *chId = [favoriteChannels objectAtIndex:indexPath.row];
    dtvChannel *channel = channels[chId];
    UIImageView *iv = [[UIImageView alloc] init];
    iv.frame = CGRectMake(0, 5, 50, 40);
    iv.image = [dtvChannel getImageForChannel:channel];
    [cell addSubview:iv];
    /*
     
    Command button
     
    UILabel *label = [[UILabel alloc] init];
    label.text = @"Volume Up";
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
    [button setTitle:@"VUP" forState:UIControlStateNormal];
    
    [label setFrame:CGRectMake(0, 34, 50, 10)];
    [label setTextColor:[Colors textColor]];
    
    [cell addSubview:button];
    [cell addSubview:label];
     */
    
    return cell;
}

- (NSInteger)numberOfSectionsInCollectionView: (UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
    return favoriteChannels.count;
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
