//
//  TodayViewController.h
//  dtvRemote-Widget
//
//  Created by Jed Lippold on 7/4/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TodayViewController : UIViewController <UICollectionViewDataSource,UICollectionViewDelegate>

@property (nonatomic, weak) IBOutlet UISegmentedControl *deviceSegmentedControl;
@property (nonatomic, weak) IBOutlet UICollectionView *cv;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;

@end
