//
//  ViewController.h
//  dtvRemote
//
//  Created by Jed Lippold on 2/21/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UITableViewDataSource,UITableViewDelegate,UISearchBarDelegate> {
    NSArray* _mainTableData;
    NSDate* _nextRefresh;
    NSString* _currentProgramId;

    double searchBarMaxWidth;
    double searchBarMinWidth;
    double xOffset;
    
    BOOL guideIsRefreshing;
    BOOL isEditing;
    
}

@property (nonatomic, strong) NSMutableDictionary *channels;
@property (nonatomic, strong) NSMutableDictionary *allChannels;
@property (nonatomic, strong) NSMutableDictionary *sortedChannels;
@property (nonatomic, strong) NSMutableArray *blockedChannels;

@property (nonatomic, strong) NSMutableDictionary *guide;
@property (nonatomic, strong) NSMutableDictionary *clients;
@property (nonatomic, strong) NSDictionary *currentClient;
@property (nonatomic, strong) NSString *ssid;


@property (nonatomic, strong) UITableView *mainTableView;
@property (nonatomic, strong) IBOutlet UINavigationBar *navbar;
@property (nonatomic, strong) IBOutlet UILabel *navTitle;
@property (nonatomic, strong) IBOutlet UILabel *navSubTitle;
@property (nonatomic, strong) IBOutlet UINavigationItem *navItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *rightButton;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UISearchBar *searchBar;


@property (nonatomic, strong) UIImageView *boxCover;
@property (nonatomic, strong) UILabel *boxTitle;
@property (nonatomic, strong) UILabel *boxDescription;


@property (nonatomic, strong) UIToolbar *playBar;
@property (nonatomic, strong) UILabel *overlayLabel;
@property (nonatomic, strong) UIView *overlayProgress;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *rewindButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *playButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *forwardButton;
@property (nonatomic, strong) UILabel *hdLabel;
@property (nonatomic, strong) UILabel *stars;
@property (nonatomic, strong) UILabel *ratingLabel;

@property (nonatomic, strong) IBOutlet UISlider *seekBar;
@property (nonatomic, strong) UIToolbar *toolBar;


@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSTimer *ssidTimer;

@end

