//
//  ViewController.m
//  dtvRemote
//
//  Created by Jed Lippold on 2/21/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "CenterViewController.h"
#import <QuartzCore/QuartzCore.h>

#import "MMDrawerBarButtonItem.h"
#import "UIViewController+MMDrawerController.h"
#import "dtvChannels.h"
#import "dtvChannel.h"
#import "dtvGuide.h"
#import "dtvCommands.h"
#import "dtvDevices.h"
#import "dtvDevice.h"
#import "dtvNowPlaying.h"
#import "VibrancyViewController.h"

#import "MBProgressHUD.h"
#import "Reachability.h"
#import "Colors.h"
#import "iNet.h"



@implementation CenterViewController {

    NSMutableDictionary *channels;
    NSMutableDictionary *allChannels;
    NSMutableDictionary *sortedChannels;
    NSMutableArray *blockedChannels;
    NSMutableArray *favoriteChannels;
    NSMutableDictionary *guide;
    NSMutableDictionary *devices;
    dtvDevice *currentDevice;
    NSString *lastSSID;
   
    UIImageView *backgroundView;
    UIVisualEffectView *bluredEffectView;
    UIView *centerView;
    UITableView *mainTableView;
    IBOutlet UINavigationBar *navbar;
    IBOutlet UILabel *navTitle;
    IBOutlet UILabel *navSubTitle;
    IBOutlet UINavigationItem *navItem;
    IBOutlet UIBarButtonItem *editButton;
    UISearchController *searchController;
    UISearchBar *searchBar;
    UIImageView *boxCover;
    UILabel *boxTitle;
    UIImageView *channelImage;
    UILabel *boxDescription;
    UIView *topContainer;
    UIToolbar *playBar;
    UIView *overlay;
    UILabel *overlayLabel;
    UIView *overlayProgress;
    UIRefreshControl *refreshControl;
    UIRefreshControl *mainRefreshControl;

    IBOutlet UIBarButtonItem *playButton;

    UIImageView *hdImage;
    UILabel *stars;
    UILabel *ratingLabel;
    IBOutlet UISlider *seekBar;
    UILabel *timeLeft;
    UIToolbar *toolBar;

    UITextField *guideTime;
    UIDatePicker *guideDatePicker;
    NSTimer *timer;
    
    UIScrollView *commandScrollView;
    UIPageControl *commandPager;
    
    NSDate *nextRefresh;
    NSString *currentProgramId;
    
    double searchBarMaxWidth;
    double searchBarMinWidth;
    double xOffset;
    double tableXOffset;
    double toolbarHeight;
    
    BOOL guideIsRefreshing;
    BOOL isEditing;
    BOOL isPlaying;
    BOOL usingVibrancy;
    
    Reachability *reach;
    
}

#pragma mark - Initialization


- (void) viewDidLoad {
    [super viewDidLoad];
    [self setNeedsStatusBarAppearanceUpdate];
    
    [self initiate];

}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) initiate {
    
    nextRefresh = [NSDate date];
    timer = [[NSTimer alloc] init];
    currentProgramId = @"";
    isEditing = NO;
    isPlaying = YES;
    guide = [[NSMutableDictionary alloc] init];
    devices = [dtvDevices getSavedDevicesForActiveNetwork];
    currentDevice = [dtvDevices getCurrentDevice];
    blockedChannels = [dtvChannels loadBlockedChannels:channels];
    favoriteChannels = [dtvChannels loadFavoriteChannels:channels];
    
    
    xOffset = 140;
    searchBarMinWidth = 74;
    tableXOffset = 255;
    toolbarHeight = 40;
    searchBarMaxWidth = [[UIScreen mainScreen] bounds].size.width - xOffset;
    
    [self registerForNotifications];
    [self createViews];
    [self displayDevice];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                             target:self
                                           selector:@selector(onTimerFire:)
                                           userInfo:nil
                                            repeats:YES];
    
    [UIApplication sharedApplication].statusBarHidden = YES;
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    
    channels = [dtvChannels load:NO];

    
    lastSSID = [iNet fetchSSID];
    BOOL firstRun = ([[channels allKeys] count] == 0);
    
    if (firstRun) {
        if ([lastSSID isEqualToString:@""]) {
            [self displayWifiChallenge:NO];
        } else {
            [self initiatePull];
        }
    } else {
        if ([lastSSID isEqualToString:@""]) {
            [self displayWifiChallenge:YES];
        }
        [self initiatePull];
    }

}

- (void) initiatePull {
    
    BOOL firstRun = ([[channels allKeys] count] == 0);
    
    if (firstRun) {
        
        [self refreshDevices:nil];
        dispatch_after(0, dispatch_get_main_queue(), ^{
            [self promptForZipCode:nil];
        });
        
    } else {
        
        allChannels = [dtvChannels load:YES];
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
        
        dispatch_after(0, dispatch_get_main_queue(), ^{
            
            [self refreshGuide:nil];
            
            if (currentDevice) {
                [self refreshNowPlaying:nil scrollToPlayingChanel:YES];
            }
        
        });
    }
    
    reach = [Reachability reachabilityForLocalWiFi];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    
    [reach startNotifier];
}

- (IBAction) reachabilityChanged:(id)sender  {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *thisSSID = [iNet fetchSSID];
        
        if (thisSSID != lastSSID) {
            lastSSID = thisSSID;
            devices = [dtvDevices getSavedDevicesForActiveNetwork];
            NSLog(@"New Network! %lu", (unsigned long)devices.count);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedDevices" object:devices];
        }
    });
    
}

- (void) onTimerFire:(id)sender {

    [self refreshNowPlaying:nil scrollToPlayingChanel:NO];
    
    if ([[NSDate date] timeIntervalSinceDate:nextRefresh] >= 0 && [channels count] > 0) {
        [self refreshGuide:nil];
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void) registerForNotifications {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedDevices:)
                                                 name:@"messageUpdatedDevices" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedDevicesProgress:)
                                                 name:@"messageUpdatedDevicesProgress" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageDownloadChannelLogos:)
                                                 name:@"messageDownloadChannelLogos" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedChannels:)
                                                 name:@"messageUpdatedChannels" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedChannelsProgress:)
                                                 name:@"messageUpdatedChannelsProgress" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageNextGuideRefreshTime:)
                                                 name:@"messageNextGuideRefreshTime" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuide:)
                                                 name:@"messageUpdatedGuide" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedFutureGuide:)
                                                 name:@"messageUpdatedFutureGuide" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuidePartial:)
                                                 name:@"messageUpdatedGuidePartial" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuideProgress:)
                                                 name:@"messageUpdatedGuideProgress" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedLocations:)
                                                 name:@"messageUpdatedLocations" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(promptForZipCode:)
                                                 name:@"messagePromptForZipCode" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageChannelChanged:)
                                                 name:@"messageChannelChanged" object:nil];
 
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageSetNowPlayingChannel:)
                                                 name:@"messageSetNowPlayingChannel" object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageAPIDown:)
                                                 name:@"messageAPIDown" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedCurrentDevice:)
                                                 name:@"messageUpdatedCurrentDevice" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageRefreshDevices:)
                                                 name:@"messageRefreshDevices" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageCloseLeftMenu:)
                                                 name:@"messageCloseLeftMenu" object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageDidBecomeActive:)
                                                 name:@"messageDidBecomeActive" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedNowPlaying:)
                                                 name:@"messageUpdatedNowPlaying" object:nil];
}


#pragma mark - View Creation

- (void) createViews {
    
    
    [self.view setBackgroundColor:[Colors backgroundColor]];

    CGRect frm = [[UIScreen mainScreen] bounds];
    centerView = [[UIView alloc] initWithFrame:frm];
    
    [centerView setBackgroundColor:[Colors backgroundColor]];
    
    frm.size.width = frm.size.width * 0.75;
    frm.origin.x = 0;

    [self.view addSubview:centerView];
    [self createBackgroundView];
    [self createTitleBar];
    [self createTopSection];
    [self createTableView];
    [self createToolbar];
    
    [self hideTopContainer:YES];
}

- (void) createBackgroundView {
    
    backgroundView = [[UIImageView alloc] initWithImage:[Colors imageWithColor:[Colors backgroundColor]]];
    backgroundView.frame = [[UIScreen mainScreen] bounds];
    backgroundView.contentMode = UIViewContentModeScaleToFill;
    backgroundView.alpha = 1.0;
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    bluredEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    bluredEffectView.frame = [UIScreen mainScreen].bounds;
    [backgroundView addSubview:bluredEffectView];
    
    CGRect frm = [[UIScreen mainScreen] bounds];
    frm.size.height = 80;
    frm.origin.x = 0;
    frm.origin.y = 400;
    
    [centerView addSubview:backgroundView];
}


- (void) createTitleBar {
    
    CGRect navBarFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, 64.0);
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    navbar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    navbar.barTintColor = [Colors navBGColor];
    navbar.translucent = NO;
    navbar.tintColor = [Colors textColor];
    navbar.titleTextAttributes = @{NSForegroundColorAttributeName : [Colors textColor]};
    
    navTitle = [[UILabel alloc] init];
    navTitle.translatesAutoresizingMaskIntoConstraints = YES;
    navTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:17];
    [navTitle setTextColor:[Colors textColor]];
    navTitle.tintColor = [Colors textColor];
    navTitle.textAlignment = NSTextAlignmentCenter;
    navTitle.frame = CGRectMake(0, 28, [[UIScreen mainScreen] bounds].size.width, 20);
    
    navSubTitle = [[UILabel alloc] init];
    navSubTitle.translatesAutoresizingMaskIntoConstraints = YES;
    navSubTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    [navSubTitle setTextColor: [Colors textColor]];
    navSubTitle.textAlignment = NSTextAlignmentCenter;
    navSubTitle.frame = CGRectMake(0, 42, [[UIScreen mainScreen] bounds].size.width, 20);
    [navSubTitle setFont:[UIFont systemFontOfSize:14]];
    
    [navbar addSubview:navTitle];
    [navbar addSubview:navSubTitle];
    
    
    NSDictionary* barButtonItemAttributes =  @{NSFontAttributeName: [UIFont fontWithName:@"Helvetica" size:14.0f],
                                               NSForegroundColorAttributeName: [Colors tintColor]};
    
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateNormal];
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateHighlighted];
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateDisabled];
    
    
    
    navItem = [UINavigationItem alloc];
    navItem.title = @"";
    
  
    
    MMDrawerBarButtonItem *leftDrawerButton = [[MMDrawerBarButtonItem alloc] initWithTarget:self
                                                                                     action:@selector(showLeftView:)];
    navItem.leftBarButtonItem = leftDrawerButton;
    

    MMDrawerBarButtonItem *rightDrawerButton = [[MMDrawerBarButtonItem alloc] initWithTarget:self
                                                                                      action:@selector(showRightView:)];
    
    navItem.rightBarButtonItem = rightDrawerButton;
    
    [navbar pushNavigationItem:navItem animated:false];
    [centerView addSubview:navbar];
}

- (void) createTopSection {
    
    topContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 64,
                                                             [[UIScreen mainScreen] bounds].size.width,
                                                             tableXOffset - 64)];
    topContainer.alpha = 0.0;
    

    [centerView addSubview:topContainer];
    
    
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(5, 69, 120, 180)];
    [v setBackgroundColor:[Colors boxBackgroundColor]];
    
    boxCover = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 120, 180)];
    [boxCover setImage:[UIImage new]];
    [v addSubview:boxCover];
    [centerView addSubview:v];
    
    
    boxTitle = [[UILabel alloc] init];
    boxTitle.text = @"";
    boxTitle.lineBreakMode = NSLineBreakByWordWrapping;
    boxTitle.numberOfLines = 2;
    boxTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:17];
    [boxTitle setTextColor:[Colors textColor]];

    boxTitle.textAlignment = NSTextAlignmentLeft;
    boxTitle.frame = CGRectMake(xOffset, 8, [[UIScreen mainScreen] bounds].size.width - xOffset, 42);
    
    
    [topContainer addSubview:boxTitle];
    
    
    playBar = [[UIToolbar alloc] init];
    playBar.tintColor = [Colors textColor];
    playBar.clipsToBounds = YES;
    playBar.frame = CGRectMake(xOffset,
                                (22 + boxTitle.frame.origin.y) + 12,
                                [[UIScreen mainScreen] bounds].size.width - (xOffset+5), 40);
    [playBar setBackgroundImage:[UIImage new] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil ];
    UIBarButtonItem *fit = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil ];
    fit.width = 15.0f;
    
    UIBarButtonItem *rewindButton = [[UIBarButtonItem alloc]
                                     initWithImage:[UIImage imageNamed:@"images.bundle/rewind"]
                                     style:UIBarButtonItemStylePlain target:self action:@selector(rewind:)];
    
    playButton = [[UIBarButtonItem alloc]
                   initWithImage:[UIImage imageNamed:@"images.bundle/pause"]
                   style:UIBarButtonItemStylePlain target:self action:@selector(playpause:) ];
    
    playButton.tintColor = [Colors textColor];
    
    UIBarButtonItem *forwardButton = [[UIBarButtonItem alloc]
                                      initWithImage:[UIImage imageNamed:@"images.bundle/forward"]
                                      style:UIBarButtonItemStylePlain target:self action:@selector(forward:) ];

    NSArray *buttons = [NSArray arrayWithObjects:
                        flex, rewindButton, flex, flex, playButton, flex, flex, forwardButton, flex, nil];
    [playBar setItems: buttons animated:NO];
    
    
    [topContainer addSubview:playBar];
    
    
    //seekbar
    seekBar = [[UISlider alloc] init];
    seekBar.frame = CGRectMake(xOffset,
                                (playBar.frame.size.height + playBar.frame.origin.y),
                                [[UIScreen mainScreen] bounds].size.width - (xOffset+5) - 40,
                                10);
    seekBar.minimumValue = 0.0;
    seekBar.maximumValue = 100.0;
    seekBar.value = 0;
    [seekBar setMaximumTrackTintColor:[Colors boxBackgroundColor]];
    [seekBar setMinimumTrackTintColor:[Colors tintColor]];
    
    seekBar.tintColor = [Colors textColor];
    seekBar.thumbTintColor = [Colors textColor];
    seekBar.userInteractionEnabled = NO;
    
    [seekBar setThumbImage:[UIImage imageNamed:@"images.bundle/slider"] forState:UIControlStateNormal];
    [topContainer addSubview:seekBar];
    
    timeLeft = [[UILabel alloc] init];
    timeLeft.frame = CGRectMake([[UIScreen mainScreen] bounds].size.width - 40,
                               (playBar.frame.size.height + playBar.frame.origin.y) - 3,
                               40, 15);
    timeLeft.font = [UIFont fontWithName:@"Helvetica-Bold" size:12];
    [timeLeft setTextColor:[Colors textColor]];
    timeLeft.text = @"";
    
    [topContainer addSubview:timeLeft];
    
    channelImage = [[UIImageView alloc] init];
    channelImage.frame = CGRectMake(xOffset,
                                    (seekBar.frame.size.height + seekBar.frame.origin.y) + 66,
                                    50, 44);
    [bluredEffectView addSubview:channelImage];
    
    
    boxDescription = [[UILabel alloc] init];
    boxDescription.translatesAutoresizingMaskIntoConstraints = YES;
    boxDescription.numberOfLines = 4;
    boxDescription.text = @"";
    boxDescription.font = [UIFont fontWithName:@"Helvetica" size:12];
    [boxDescription setTextColor: [Colors textColor]];
    boxDescription.textAlignment = NSTextAlignmentLeft;
    boxDescription.frame = CGRectMake(xOffset + 55,
                                       (seekBar.frame.size.height + seekBar.frame.origin.y) + 4,
                                       [[UIScreen mainScreen] bounds].size.width - xOffset - 55,
                                       56);

    [topContainer addSubview:boxDescription];
    
    [[UITextField appearanceWhenContainedIn:[UISearchBar class], nil] setDefaultTextAttributes:@{NSForegroundColorAttributeName:[Colors textColor]}];
    
    searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(xOffset - 10,
                                                               (topContainer.frame.size.height - 42),
                                                               searchBarMinWidth, 44)];
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    searchBar.translucent = YES;
    searchBar.tintColor = [UIColor whiteColor];
    searchBar.backgroundColor = [UIColor clearColor];
    searchBar.alpha = 0.8;
    
    searchBar.barStyle = UIBarStyleDefault;
    searchBar.delegate = self;
    
    searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.dimsBackgroundDuringPresentation = NO;
    searchController.hidesNavigationBarDuringPresentation = NO;
    searchController.searchBar.frame = searchBar.frame;
    searchBar.enablesReturnKeyAutomatically = NO;

    [topContainer addSubview:searchBar];
    
    hdImage = [[UIImageView alloc] init];
    hdImage.image = [UIImage imageNamed:@"images.bundle/hd.png"];
    hdImage.contentMode = UIViewContentModeScaleAspectFit;
    hdImage.frame = CGRectMake(xOffset,
                                        (seekBar.frame.size.height + seekBar.frame.origin.y) + 46 + 64,
                                        50, 13);
    [hdImage setHidden:YES];
    
    [bluredEffectView addSubview:hdImage];
    
    
    ratingLabel = [[UILabel alloc] init];
    ratingLabel.text = @"";
    ratingLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    [ratingLabel setBackgroundColor:[UIColor clearColor]];
    [ratingLabel setTextColor:[Colors textColor]];
    ratingLabel.textAlignment = NSTextAlignmentCenter;
    ratingLabel.frame = CGRectMake(
                                   searchBar.frame.origin.x + searchBarMinWidth + 10,
                                   (topContainer.frame.size.height - 36) + 64,
                                   64,
                                   29);
    
    [ratingLabel setHidden:YES];
    
    [bluredEffectView addSubview:ratingLabel];
    
    stars = [[UILabel alloc] init];
    stars.text = @"★★★★★";
    stars.font = [UIFont fontWithName:@"Helvetica-Bold" size:16];
    stars.clipsToBounds = YES;
    stars.adjustsFontSizeToFitWidth = NO;
    stars.lineBreakMode = NSLineBreakByClipping;
    stars.layer.masksToBounds = YES;
    [stars setTextColor:[UIColor colorWithRed:0.941 green:0.812 blue:0.376 alpha:1]];  /*#f0cf60*/
    stars.textAlignment = NSTextAlignmentLeft;
    stars.frame = CGRectMake(
                             0,
                             (topContainer.frame.size.height - 36),
                             0,
                             29);
    [stars setHidden:YES];
    [topContainer addSubview:stars];

    
    
}

- (void) createTableView {

    mainTableView = [[UITableView alloc] init];
    [mainTableView setFrame:CGRectMake(0, tableXOffset,
                                        [[UIScreen mainScreen] bounds].size.width,
                                        [[UIScreen mainScreen] bounds].size.height-(tableXOffset+ toolbarHeight))];
    mainTableView.dataSource = self;
    mainTableView.delegate = self;
    
    mainTableView.separatorColor = [Colors seperatorColor];
    mainTableView.backgroundColor = [Colors backgroundColor];
    
     mainRefreshControl = [[UIRefreshControl alloc] init];
    [mainRefreshControl addTarget:self action:@selector(refreshGuide:) forControlEvents:UIControlEventValueChanged];
    [mainTableView addSubview:mainRefreshControl];
    
    [centerView addSubview:mainTableView];
    
}

- (void) createToolbar {
    

    overlay = [[UIView alloc] init];
    overlay.opaque = YES;
    overlay.alpha = 0;
    overlay.backgroundColor = [UIColor clearColor];
    overlay.frame = [[UIApplication sharedApplication] statusBarFrame];
    
    overlayProgress = [[UIView alloc] init];
    overlayProgress.frame = [[UIApplication sharedApplication] statusBarFrame];
    overlayProgress.opaque = YES;
    overlayProgress.alpha = 0.8;
    overlayProgress.backgroundColor = [Colors greenColor];
    
    overlayLabel = [[UILabel alloc] init];
    overlayLabel.textColor = [UIColor whiteColor];
    overlayLabel.frame = [[UIApplication sharedApplication] statusBarFrame];
    overlayLabel.text = @"";
    overlayLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
    overlayLabel.textAlignment = NSTextAlignmentCenter;

    [self.view addSubview:overlayProgress];
    [overlay addSubview:overlayLabel];
    [self.view addSubview:overlay];
    
    toolBar = [[UIToolbar alloc] init];
    toolBar.clipsToBounds = YES;
    toolBar.frame = CGRectMake(0, [[UIScreen mainScreen] bounds].size.height - toolbarHeight, [[UIScreen mainScreen] bounds].size.width, toolbarHeight);
    [toolBar setBackgroundImage:[UIImage new] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    toolBar.tintColor = [Colors textColor];
    
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil ];
    
    
    UIBarButtonItem *clock = [[UIBarButtonItem alloc]
                                     initWithImage:[UIImage imageNamed:@"images.bundle/clock"]
                                     style:UIBarButtonItemStylePlain target:self action:@selector(selectGuideTime:) ];
     
    
    UIBarButtonItem *numberPad = [[UIBarButtonItem alloc]
                                  initWithImage:[UIImage imageNamed:@"images.bundle/numberpad"]
                                  style:UIBarButtonItemStylePlain target:self action:@selector(showNumberPad:) ];
    
    
    UIBarButtonItem *sort = [[UIBarButtonItem alloc]
                             initWithImage:[UIImage imageNamed:@"images.bundle/sort"]
                             style:UIBarButtonItemStylePlain target:self action:@selector(sortChannels:) ];
    
    editButton = [[UIBarButtonItem alloc]
                   initWithImage:[UIImage imageNamed:@"images.bundle/favorite"]
                   style:UIBarButtonItemStylePlain target:self action:@selector(toggleEditMode:)];
    
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc]
                               initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                               target:self
                               action:@selector(refreshGuide:)];
    
    
    NSArray *buttons = [NSArray arrayWithObjects: clock, flex , sort, flex, numberPad, flex, editButton, flex, refresh, nil];
    [toolBar setItems:buttons animated:NO];
    
    [centerView addSubview:toolBar];

    
    guideDatePicker = [[UIDatePicker alloc] init];
    guideTime = [[UITextField alloc] initWithFrame:CGRectMake(0,0,1,1)];
    [guideTime setHidden:YES];
    [guideTime setInputView:guideDatePicker];
    [guideDatePicker addTarget:self action:@selector(changedGuideTime:)
         forControlEvents:UIControlEventValueChanged];
    
    UIToolbar *guideTimeDone = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, 44)];
    [guideTimeDone setBarStyle:UIBarStyleBlackTranslucent];
    
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone
                                                            target:nil action:@selector(selectedGuideTime:)];
    
    [guideTimeDone setItems: [NSArray arrayWithObjects:flex, done, nil]];
    [guideTime setInputAccessoryView:guideTimeDone];
    guideTime.text = @"";
    
    [centerView addSubview:guideTime];

    
}

- (void) showCommandSlider {
    VibrancyViewController *vib = [[VibrancyViewController alloc] init];
    [self presentViewController:vib animated:YES completion:^(void) {
        
        overlay.alpha = 0;
        overlayProgress.hidden = YES;
        overlayLabel.text = @"";
        [UIApplication sharedApplication].statusBarHidden = NO;

    }];
    
    vib.backgroundView.image = backgroundView.image;
    
}


-(UIStatusBarStyle) preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

#pragma mark - Table View Filtering

- (void) searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [self openSearchBar];
}

- (void) searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self closeSearchBar];
}

- (void) searchBarTextDoneEditing:(UISearchBar *)searchBar {
    [self closeSearchBar];
}

- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([searchText isEqualToString:@""]) {
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
        [mainTableView reloadData];
        [self closeSearchBar];
    } else {
        [self filterResults:searchText];
    }
}

- (void) closeSearchBar {
    [searchBar resignFirstResponder];
    if ([searchBar.text isEqualToString:@""]) {
        if (searchBar.tag == 2) {
            return;
        }
        searchBar.tag = 2;
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
        
        CGRect newFrame = searchBar.frame;
        newFrame.size.width = searchBarMinWidth;
        [UIView animateWithDuration:0.50
                         animations:^{
                             searchBar.frame = newFrame;
                             ratingLabel.alpha = 1.0;
                             stars.alpha = 1.0;
                         }];
    }
}

- (void) openSearchBar {
    if (searchBar.tag == 1) {
        return;
    }
    searchBar.tag = 1;
    
    CGRect newFrame = searchBar.frame;
    newFrame.size.width = searchBarMaxWidth;
    
    [UIView animateWithDuration:0.25
                     animations:^{
                         searchBar.frame = newFrame;
                         ratingLabel.alpha = 0.0;
                         stars.alpha = 0.0;
                     }];
}

- (void) filterResults:(NSString *) term {
    NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
    NSArray *keys = [channels allKeys];
    
    NSString *header = @"Filtered Results";
    [results setObject:[[NSMutableDictionary alloc] init] forKey:header];

    for (NSString *chId in keys) {
        dtvChannel *channel = channels[chId];
        dtvGuideItem *guideItem = guide[chId];
        if (guideItem.title && [guideItem.title rangeOfString:term options:NSCaseInsensitiveSearch].location != NSNotFound ) {
            [results[header] setObject:channel forKey:chId];
        } else {
            if ([channel.name rangeOfString:term options:NSCaseInsensitiveSearch].location != NSNotFound ) {
                [results[header] setObject:channel forKey:chId];
            }
        }
    }
    sortedChannels = results;
    [mainTableView reloadData];
}

- (BOOL) searchBarShouldEndEditing:(UISearchBar *)searchBar {
    return YES;
}

- (void) scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self closeSearchBar];
}

#pragma mark - TableView Management

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return  19.0;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return [[sortedChannels allKeys] count];
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *sections = [[sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *sectionKey = [sections objectAtIndex:section];
    return [[[sortedChannels objectForKey:sectionKey] allKeys] count];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *v = (UITableViewHeaderFooterView *)view;
    
    if (usingVibrancy) {
        v.backgroundView.backgroundColor = [Colors navClearColor];
        v.backgroundView.alpha = 0.8;
        v.backgroundView.tintColor = [Colors tintColor];
    } else {
        v.backgroundView.backgroundColor = [Colors backgroundColor];
        v.backgroundView.alpha = 0.9;
        v.backgroundView.tintColor = [Colors tintColor];
    }
    
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setTextColor:[Colors textColor]];
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray *sections = [[sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return [sections objectAtIndex:section];
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{

    cell.indentationLevel = 1;
    cell.indentationWidth = 2;
    //cell.accessoryType = UITableViewCellAccessoryCheckmark;
    cell.userInteractionEnabled = YES;
    
    if (usingVibrancy) {
        cell.backgroundColor = [Colors transparentColor];
        [cell.textLabel setTextColor: [Colors textColor]];
        [cell.detailTextLabel setTextColor:[Colors textColor]];
        [cell setTintColor:[Colors tintColor]];
    } else {
        cell.backgroundColor = [Colors backgroundColor];
        [cell.textLabel setTextColor: [Colors textColor]];
        [cell.detailTextLabel setTextColor:[Colors textColor]];
        [cell setTintColor:[Colors tintColor]];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SomeId"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SomeId"];
        UILabel *label = [[UILabel alloc] init];
        label.text = @"";
        label.textColor = [Colors textColor];
        label.font = [UIFont fontWithName:@"Helvetica" size:12];
        label.numberOfLines = 2;
        label.backgroundColor = [UIColor clearColor];
        [label setTag:1];
        label.textAlignment = NSTextAlignmentCenter;
        [label setFrame:CGRectMake([[UIScreen mainScreen] bounds].size.width - 40, 7, 40, 30)];
        [cell.contentView addSubview:label];
    }
    
    //cell data
    NSArray *sections = [[sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *sectionKey = [sections objectAtIndex:indexPath.section];
    NSMutableDictionary *sectionData = [sortedChannels objectForKey:sectionKey];
    
    
    //NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
    id channelSort = ^(NSString *chId1, NSString *chId2){
        dtvChannel *channel1 = channels[chId1];
        dtvChannel *channel2 = channels[chId2];
        return channel1.number > channel2.number;
    };
    NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingComparator:channelSort];
    
    
    NSString *chId = [sectionChannels objectAtIndex:indexPath.row];
    
    dtvChannel *channel = sectionData[chId];
    dtvGuideItem *guideItem = guide[chId];

    cell.textLabel.text = @"Not Available";
    cell.detailTextLabel.text = @" ";
    if (guideItem) {
        cell.textLabel.text = guideItem.title;
        if (guideItem.futureAiring) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@",
                                         guideItem.futureAiring];
        } else {
            if (guideItem.upNext) {
                NSDictionary *duration = [dtvGuide getDurationForChannel:guideItem];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"-%@ %@",
                                             duration[@"timeLeft"],
                                             guideItem.upNext];
            }
        }
    }
    
    UILabel *l2 = (UILabel *)[cell viewWithTag:1];
    
    if (isEditing) {
        [l2 setHidden:YES];
        
        cell.textLabel.text = [NSString stringWithFormat:@"%d: %@", channel.number, channel.name];
        cell.detailTextLabel.text = @"Visible";
        
        UIImage *image = [UIImage new];
        
        if ([blockedChannels containsObject:chId]) {
            image = [UIImage imageNamed:@"images.bundle/hidden"];
            cell.detailTextLabel.text = @"Hidden";
        }

        if ([favoriteChannels containsObject:chId]) {
            image = [UIImage imageNamed:@"images.bundle/favorite"];
            cell.detailTextLabel.text = @"Favorite";
        }
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect frame = CGRectMake(0, 0, image.size.width, image.size.height);
        button.frame = frame;
        button.userInteractionEnabled = NO;
        [button setBackgroundImage:image forState:UIControlStateNormal];
        button.backgroundColor = [UIColor clearColor];
        cell.accessoryView = button;
        
    } else {
        cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage new]];
        
        [l2 setHidden:NO];
        l2.text = [NSString stringWithFormat:@"%d", channel.number];

    }

    
    cell.imageView.image = [dtvChannel getImageForChannel:channel];
    [cell setNeedsLayout];
    
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *sections = [[sortedChannels allKeys]
                         sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *sectionKey = [sections objectAtIndex:indexPath.section];
    NSMutableDictionary *sectionData = [sortedChannels objectForKey:sectionKey];
    
    //NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
    id channelSort = ^(NSString *chId1, NSString *chId2){
        dtvChannel *channel1 = channels[chId1];
        dtvChannel *channel2 = channels[chId2];
        return channel1.number > channel2.number;
    };
    NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingComparator:channelSort];
    
    NSString *chId = [sectionChannels objectAtIndex:indexPath.row];
    dtvChannel *channel = [sectionData objectForKey:chId];
    dtvGuideItem *guideItem = guide[chId];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (isEditing) {
        
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        UIImage *image = [UIImage new];
        
        BOOL match = false;
        
        if (![blockedChannels containsObject:chId] && ![favoriteChannels containsObject:chId] ) {
            //nothing to blocked
            image = [UIImage imageNamed:@"images.bundle/hidden"];
            if ([favoriteChannels containsObject:chId]) {
                [favoriteChannels removeObject:chId];
            }
            [blockedChannels addObject:chId];
            cell.detailTextLabel.text = @"Hidden";
            match = true;
        } else
            
        if ([blockedChannels containsObject:chId] && !match) {
            //blocked to favortie
            image = [UIImage imageNamed:@"images.bundle/favorite"];
            if ([blockedChannels containsObject:chId]) {
                [blockedChannels removeObject:chId];
            }
            [favoriteChannels addObject:chId];
            cell.detailTextLabel.text = @"Favorite";
            match = true;
        } else {
            //favorite to nothing
            image = [UIImage new];
            if ([favoriteChannels containsObject:chId]) {
                [favoriteChannels removeObject:chId];
            }
            if ([blockedChannels containsObject:chId]) {
                [blockedChannels removeObject:chId];
            }
            cell.detailTextLabel.text = @"Visible";
        }
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tintColor = [Colors textColor];
        CGRect frame = CGRectMake(0, 0, image.size.width, image.size.height);
        button.frame = frame;
        button.userInteractionEnabled = NO;
        [button setBackgroundImage:image forState:UIControlStateNormal];
        button.backgroundColor = [UIColor clearColor];
        cell.accessoryView = button;
        
    } else {
        
        if (!currentDevice) {
            [self displayNoDeviceError];
            return;
        }
        
        if (guideItem.futureAiring) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cannot Change Channel"
                                                                           message:@"This program is not on the air" preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* accept = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
             [alert addAction:accept];
             [self presentViewController:alert animated:YES completion:nil];
            return;
        }

        [dtvCommands changeChannel:channel device:currentDevice];
    }
    
}

#pragma mark - IB Actions

- (IBAction) promptForZipCode:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Guide Listing"
                                                                   message:@"Please enter your 5 digit zipcode" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* accept =
    [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:
     ^(UIAlertAction * action){
         
         UITextField *chosenZip = alert.textFields.firstObject;
         NSString *zip = chosenZip.text;
         NSLog(@"Entered: %@", zip);
         
         //save entered zip
         [[NSUserDefaults standardUserDefaults] setObject:zip forKey:@"zip"];
         [[NSUserDefaults standardUserDefaults] synchronize];
         
         if ([zip length] != 5) {
             [self promptForZipCode:nil];
             return;
         }
         
         MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
         hud.mode = MBProgressHUDModeIndeterminate;
         hud.labelText = [NSString stringWithFormat:@"Getting locations in %@", zip];
         
         [dtvChannels getLocationsForZipCode:zip];
         return;
     }];
    
    [alert addAction:accept];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"zip"];
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = @"10001";
        
    }];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void) promptForLocation:(NSMutableDictionary *) locations {
    
    NSArray *keys = [locations allKeys];
    
    if ([keys count] == 0 ) {
        //somethings wrong, ask again for zip
        [self promptForZipCode:nil];
        return;
    }
    
    if ([keys count] == 1 ) {
        //only 1 location, dont ask, just confirm
        id key = [keys objectAtIndex: 0];
        [dtvChannels populateChannels:locations[key]];
        return;
    }
    
    UIAlertController *view = [UIAlertController
                               alertControllerWithTitle:@"Confirm your location"
                               message:@""
                               preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSUInteger i = 0; i < [locations count]; i++) {
        
        id key = [keys objectAtIndex: i];
        id item = locations[key];
        UIAlertAction *action =
        [UIAlertAction actionWithTitle: item[@"countyName"] style: UIAlertActionStyleDefault handler:
         ^(UIAlertAction * action) {
             [view dismissViewControllerAnimated:YES completion:nil];

             MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
             hud.mode = MBProgressHUDModeIndeterminate;
             hud.labelText = [NSString stringWithFormat:@"Loading channels for %@", item[@"countyName"]];
             
             [dtvChannels populateChannels:item];
             return;
         }];
        [view addAction:action];
    }
    
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        [view dismissViewControllerAnimated:YES completion:nil];
        [self promptForZipCode:nil];
    }];
    
    [view addAction:cancel];
    [self presentViewController:view animated:YES completion:nil];
}


- (void) displayWifiChallenge:(BOOL) allowEscape {
    dispatch_after(0, dispatch_get_main_queue(), ^{

        UIAlertController *view = [UIAlertController
                                   alertControllerWithTitle:@"No Wifi Connection Found"
                                   message:@"You must be on the same wifi network as the direct tv box."
                                   preferredStyle:UIAlertControllerStyleAlert];
        
        NSString *buttonTitle = allowEscape ? @"Ok" : @"Retry";

        UIAlertAction *ok = [UIAlertAction actionWithTitle:buttonTitle style:UIAlertActionStyleDefault handler:
                             ^(UIAlertAction * action) {
                                 
                                 [view dismissViewControllerAnimated:YES completion:nil];
                                 if (allowEscape) {
                                     return;
                                 }
                                 
                                 lastSSID = [iNet fetchSSID];
                                 if ([lastSSID isEqualToString:@""]) {
                                     [self displayWifiChallenge:NO];
                                 } else {
                                     [self initiatePull];
                                 }
                             }];
        
        [view addAction:ok];
        
        UIViewController *vc = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
        [vc presentViewController:view animated:YES completion:nil];
    });
    
}

- (void) displayNoDeviceError {
    //some message about no device
    UIAlertController *view = [UIAlertController
                               alertControllerWithTitle:@"No device selected"
                               message:@"Would you like to search for available devices?"
                               preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:
                             ^(UIAlertAction * action) {
                                 [view dismissViewControllerAnimated:YES completion:nil];
                                 return;
                             }];
    
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:
                         ^(UIAlertAction * action) {
                             [view dismissViewControllerAnimated:YES completion:nil];
                             [self refreshDevices:nil];
                             return;
                         }];
    
    [view addAction:ok];
    [view addAction:cancel];
    
    UIViewController *vc = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [vc presentViewController:view animated:YES completion:nil];

}

- (IBAction) refreshGuide:(id)sender {
    [mainRefreshControl endRefreshing];
    if (!guideIsRefreshing) {
        guideIsRefreshing = YES;
        [self refreshGuideForTime:[NSDate date]];
    }
}

- (IBAction) sortChannels:(id)sender {
    
    UIAlertController *view = [UIAlertController
                               alertControllerWithTitle:nil
                               message:@"Sort By"
                               preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* name = [UIAlertAction actionWithTitle:@"Channel Name" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        //save sort
        [[NSUserDefaults standardUserDefaults] setObject:@"name" forKey:@"sort"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"name"];
        [mainTableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
        [mainTableView reloadData];
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    [view addAction:name];
    
    UIAlertAction* number = [UIAlertAction actionWithTitle:@"Channel Number" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        //save sort
        [[NSUserDefaults standardUserDefaults] setObject:@"number" forKey:@"sort"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"number"];
        [mainTableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
        [mainTableView reloadData];
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    [view addAction:number];
    
    UIAlertAction* category = [UIAlertAction actionWithTitle:@"Channel Type" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        //save sort
        [[NSUserDefaults standardUserDefaults] setObject:@"category" forKey:@"sort"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"category"];
        [mainTableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
        [mainTableView reloadData];
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    [view addAction:category];
    
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [view addAction:cancel];
    [self presentViewController:view animated:YES completion:nil];
    
}

- (IBAction) toggleEditMode:(id)sender {
    if (isEditing) {
        //Going back to regular mode
        [dtvChannels saveBlockedChannels:blockedChannels];
        [dtvChannels saveFavoriteChannels:favoriteChannels];
        isEditing = NO;
        editButton.image = [UIImage imageNamed:@"images.bundle/favorite"];
        channels = [dtvChannels load:NO];
        blockedChannels = [[NSMutableArray alloc] init];
        favoriteChannels = [[NSMutableArray alloc] init];
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
        
    } else {
        //Going into edit mode
        isEditing = YES;
        editButton.image = [UIImage imageNamed:@"images.bundle/favortite-selected"];
        channels = [dtvChannels load:YES];
        blockedChannels = [dtvChannels loadBlockedChannels:channels];
        favoriteChannels = [dtvChannels loadFavoriteChannels:channels];
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
    }
    
    [mainTableView reloadData];
}

- (IBAction) showNumberPad:(id)sender {
    [self showCommandSlider];
}


- (IBAction) playpause:(id)sender {
    if (isPlaying) {
        if ([dtvCommands sendCommand:@"pause" device:currentDevice]) {
            playButton.image = [UIImage imageNamed:@"images.bundle/play"];
            isPlaying = NO;
        }
    } else {
        if ([dtvCommands sendCommand:@"play" device:currentDevice]) {
            playButton.image = [UIImage imageNamed:@"images.bundle/pause"];
            isPlaying = YES;
        }
    }
}

- (IBAction) rewind:(id)sender {
    if ([dtvCommands sendCommand:@"rew" device:currentDevice]) {
        playButton.image = [UIImage imageNamed:@"images.bundle/play"];
        isPlaying = NO;
    }
}

- (IBAction) forward:(id)sender {
    if ([dtvCommands sendCommand:@"ffwd" device:currentDevice]) {
        playButton.image = [UIImage imageNamed:@"images.bundle/play"];
        isPlaying = NO;
    }
}

- (IBAction) selectGuideTime:(id)sender {
    if (!guideIsRefreshing) {
        guideIsRefreshing = YES;
        [guideDatePicker setDate:[NSDate date]];
        guideDatePicker.maximumDate=[[NSDate date] dateByAddingTimeInterval:(48*60*60)];
        guideDatePicker.minimumDate=[[NSDate date] dateByAddingTimeInterval:(90*60*-1)];
        [guideTime becomeFirstResponder];
    }
}

- (IBAction) selectedGuideTime:(id)sender {
    if (![guideTime.text isEqualToString:@""]) {
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateStyle:NSDateFormatterFullStyle];
        [dateFormat setTimeStyle:NSDateFormatterFullStyle];
        NSDate *date = [dateFormat dateFromString:guideTime.text];
        [self refreshGuideForTime:date];
        guideTime.text = @"";
    }
    [guideTime resignFirstResponder];
}


- (IBAction) showLeftView:(id)sender {
    [self.mm_drawerController toggleDrawerSide:MMDrawerSideLeft animated:YES completion:nil];
}

- (IBAction) showRightView:(id)sender {
    [self.mm_drawerController toggleDrawerSide:MMDrawerSideRight animated:YES completion:nil];
}


- (IBAction) sendCommand:(id)sender {
    NSString *buttonTitle = [sender title];
    
    if([buttonTitle isEqualToString:@"Rec"]) {
        [dtvCommands sendCommand:@"record" device:currentDevice];
    }
    else if([buttonTitle isEqualToString:@"Guide"]) {
        [dtvCommands sendCommand:@"guide" device:currentDevice];
    }
    else if([buttonTitle isEqualToString:@"List"]) {
        [dtvCommands sendCommand:@"list" device:currentDevice];
    }
    else if([buttonTitle isEqualToString:@"Menu"]) {
        [dtvCommands sendCommand:@"menu" device:currentDevice];
    }
    else if([buttonTitle isEqualToString:@"Prev"]) {
        [dtvCommands sendCommand:@"prev" device:currentDevice];
    }

}



#pragma mark - Messages / Events

- (void) messageUpdatedLocations:(NSNotification *)notification {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSMutableDictionary *locations = [notification object];
    [self promptForLocation:locations];
}


- (void) messageAPIDown:(NSNotification *)notification {
    
    [self showStatusOverlay:@"Connection Error: Error accessing directv guide"];
    
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.5);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
       [self hideStatusOverlay:@"Connection Error: Error accessing directv guide"];
    });
    
}


- (void) messageDownloadChannelLogos:(NSNotification *)notification { 
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    channels = [notification object];
    allChannels = [notification object];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.labelText = @"Downloading channel information";
        hud.detailsLabelText = @"This only has to happen once...";
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [dtvChannels downloadChannelImages:channels];
        });
        
    });
    
}

- (void) messageUpdatedChannels:(NSNotification *)notification {

    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        
        channels = [dtvChannels load:NO];
        allChannels = [dtvChannels load:YES];
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
        
        [mainTableView reloadData];
        [self refreshGuide:nil];
        //[self setDefaultNowPlayingChannel];
    });
    
}

- (void) messageUpdatedChannelsProgress:(NSNotification *)notification {
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.progress = [[notification object] floatValue];
    
}

- (void) messageUpdatedDevices:(NSNotification *)notification {
    devices = notification.object;
    if ([[devices allKeys] count] == 0) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self hideStatusOverlay:@"No devices found on this network!"];
            [self hideTopContainer:YES];
        }];
    } else {
        if (!currentDevice) {
            NSString *deviceId = [devices allKeys][0];
            dtvDevice *device = [devices objectForKey:deviceId];
            [dtvDevices setCurrentDevice:device];
        }
    }
}

- (void) messageUpdatedDevicesProgress:(NSNotification *)notification {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        float percent = [[notification object] floatValue];
        CGRect frm = overlayProgress.frame;
        frm.size.width = [[UIScreen mainScreen] bounds].size.width * percent;
        overlayProgress.hidden = NO;

        [UIView animateWithDuration:0.25
                         animations:^{
                             overlayProgress.frame = frm;
                         }
                         completion:^(BOOL finished) {
                             if (finished && percent == 1) {
                                 overlayProgress.hidden = YES;
                                 [self hideStatusOverlay:@"Scanning completed!"];
                             }
                         }];
        
    }];
}

- (void) messageNextGuideRefreshTime:(NSNotification *)notification {
    nextRefresh = [notification object];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"h:mm a"];
        [self hideStatusOverlay:[NSString stringWithFormat:@"Next Refresh at %@",
                                 [formatter stringFromDate:nextRefresh]]];
    }];
}

- (void) messageUpdatedGuide:(NSNotification *)notification {
    [self sendGuideDataToUI:notification.object isFuture:NO];
}

- (void) messageUpdatedFutureGuide:(NSNotification *)notification {
    [self sendGuideDataToUI:notification.object isFuture:YES];
}

- (void) messageUpdatedGuideProgress:(NSNotification *)notification {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        float percent = [[notification object] floatValue];
        CGRect frm = overlayProgress.frame;
        frm.size.width = [[UIScreen mainScreen] bounds].size.width * percent;
        
        [UIView animateWithDuration:0.25
                         animations:^{
                             overlayProgress.frame = frm;
                         }
                         completion:^(BOOL finished) {
                             if (finished && percent == 1) {
                                 overlayProgress.hidden = YES;
                             }
                         }];
    }];
}

- (void) messageUpdatedGuidePartial:(NSNotification *)notification {
    guide = notification.object;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [mainTableView reloadData];
    }];
}

- (void) messageChannelChanged:(NSNotification *)notification {
    isPlaying = YES;
    [self refreshNowPlaying:nil scrollToPlayingChanel:NO];
}

- (void) messageSetNowPlayingChannel:(NSNotification *)notification {
    NSString *chNum = notification.object;
    dtvChannel *channel = [dtvChannels getChannelByNumber:[chNum intValue] channels:channels];
    [self updateNowPlaying:channel];
}

- (void) messageUpdatedCurrentDevice:(NSNotification *)notification {
    currentDevice = notification.object;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self hideTopContainer:YES];
        [self displayDevice];
    }];
}

- (void) messageRefreshDevices:(NSNotification *)notification {
    [self refreshDevices:nil];
}
- (void) messageCloseLeftMenu:(NSNotification *)notification {
    [self showLeftView:nil];
}
- (void) messageDidBecomeActive:(NSNotification *)notification {
    dtvDevice *d = [dtvDevices getCurrentDevice];
    
    if (![d.identifier isEqualToString:currentDevice.identifier]) {
        [dtvDevices setCurrentDevice:d];
    }
        
    [self reachabilityChanged:nil];
    [self onTimerFire:nil];
}

- (void) messageUpdatedNowPlaying:(NSNotification *)notification {
    [self setNowPlaying:notification.object];
}

#pragma mark - UI Updates

-(BOOL)isVisible{
    if (self.isViewLoaded && self.view.window) {
        // viewController is visible
        return YES;
    }
    return NO;
}

- (void) displayDevice {
    if (currentDevice) {
        navTitle.text = [currentDevice.name capitalizedString];
        navSubTitle.text = @"N/A";
        [self refreshNowPlaying:nil scrollToPlayingChanel:YES];
    } else {
        navTitle.text = @"No Device Selected";
        navSubTitle.text = @"N/A";
        [self clearNowPlaying];
    }
}

- (IBAction)refreshDevices:(id)sender {
    [self showStatusOverlay:@"Scanning wifi network for devices..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [dtvDevices refreshDevicesForNetworks];
    });
}

-(void)hideTopContainer:(BOOL) hide {
    
    if (hide) {
        [self clearNowPlaying];
        [self toggleVibrancyEffects:[UIImage new] enable:NO];
        
        [UIView animateWithDuration:0.25
                         animations:^{
                             [mainTableView setFrame:CGRectMake(0, topContainer.frame.origin.y,
                                                                [[UIScreen mainScreen] bounds].size.width,
                                                                [[UIScreen mainScreen] bounds].size.height-
                                                                (topContainer.frame.origin.y+toolbarHeight))];
                             topContainer.alpha = 0.0;
                             boxTitle.text = @"";
                             boxDescription.text = @"";
                             [ratingLabel setHidden:YES];
                             [stars setHidden:YES];
                         }];
    } else {
        [UIView animateWithDuration:0.5
                         animations:^{
                             [mainTableView setFrame:CGRectMake(0, tableXOffset,
                                                                [[UIScreen mainScreen] bounds].size.width,
                                                                [[UIScreen mainScreen] bounds].size.height-(tableXOffset+ toolbarHeight))];
                             topContainer.alpha = 1.0;
                         }];
    }
}

-(BOOL)topContainerIsHidden {
    return topContainer.frame.origin.y == mainTableView.frame.origin.y;
}


- (void) setDefaultNowPlayingChannel {
    dtvChannel *channel = [dtvChannels getChannelByCallSign:@"HBOe" channels:channels];
    [self updateNowPlaying:channel];
}

- (void) refreshNowPlaying:(id)sender scrollToPlayingChanel:(BOOL)scroll {
    if (currentDevice) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *channelNum = [dtvCommands getChannelOnDevice:currentDevice];
            
            if ([channelNum isEqualToString:@""]) {
                navSubTitle.text = @"Offline";
            } else {
                
                dtvChannel *channel = [dtvChannels getChannelByNumber:[channelNum intValue] channels:allChannels];
                if (channel.identifier == 0) {
                    [self clearNowPlaying];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateNowPlaying:channel];
                        if (scroll) {
                            [self scrollToChannel:channel];
                        }
                    });
                }
            }
        });
    }
}

- (void) updateNowPlaying:(dtvChannel *) channel {
    dtvNowPlaying *np = [[dtvNowPlaying alloc] init];
    [np update:channel];
}

- (void) setNowPlaying:(dtvNowPlaying *) np {
    if (!np) {
        [self hideTopContainer:YES];
        return;
    }
    
    seekBar.value = np.percentComplete;
    timeLeft.text = np.timeLeft;
    
    if ([currentProgramId isEqualToString:np.programId]) {
        return;
    }
    
    [UIView animateWithDuration:0.25
                     animations:^{
                         topContainer.alpha = 0.0;
                         boxCover.alpha = 0.0;
                     } completion:
     ^(BOOL finished) {
         
         currentProgramId = np.programId;
         boxTitle.text = np.title;
         channelImage.image = np.channelImage;
         navSubTitle.text = [NSString stringWithFormat:@"%d %@", np.channel.number, np.channel.name];
         boxDescription.text = np.synopsis;
         
         if (np.HD) {
             [hdImage setHidden:NO];
         } else {
             [hdImage setHidden:YES];
         }
         
         if (np.rating) {
             ratingLabel.text = np.rating;
             [ratingLabel setHidden:NO];
         } else {
             [ratingLabel setHidden:YES];
         }
         
         if (np.stars) {
             [self setStarRating:np.stars];
             [stars setHidden:NO];
         } else {
             [stars setHidden:YES];
         }
         
         if (np.image) {
             [self toggleVibrancyEffects:np.image enable:YES];
         } else {
             [self toggleVibrancyEffects:nil enable:NO];
         }
         [self applyColors:np.colors];
         
         if ([self topContainerIsHidden]) {
             [self hideTopContainer:NO];
         }
         
         [UIView animateWithDuration:0.25
                          animations:^{
                              topContainer.alpha = 1.0;
                              boxCover.alpha = 1.0;
                          } completion:nil];
         
     }];
}

-(void) applyColors:(NSMutableArray *) colors {
     
    if (colors) {
        UIColor *mainText = [colors objectAtIndex:0];
        //UIColor *subText = [colors objectAtIndex:1];
        UIColor *buttons = [colors objectAtIndex:2];
        //UIColor *others = [colors objectAtIndex:3];
        
        [navTitle setTextColor:mainText];
        navTitle.tintColor = mainText;
        //[navSubTitle setTextColor:subText];
        //navSubTitle.tintColor = subText;
        
        //timeLeft.textColor = buttons;
        boxTitle.textColor = mainText;
        //boxDescription.textColor = subText;
        
        navItem.leftBarButtonItem.tintColor = buttons;
        navItem.rightBarButtonItem.tintColor = buttons;
        
        [seekBar setMinimumTrackTintColor:buttons];
        
        for (UIBarButtonItem* item in toolBar.subviews) {
            item.tintColor = buttons;
        }
        
        
        playButton.tintColor = buttons;
        for (UIBarButtonItem* item in playBar.subviews) {
            item.tintColor = buttons;
        }
        
    } else {
        
        [navTitle setTextColor:[Colors textColor]];
        navTitle.tintColor = [Colors textColor];
        [navSubTitle setTextColor:[Colors textColor]];
        navSubTitle.tintColor = [Colors textColor];
        
        timeLeft.textColor = [Colors textColor];
        boxTitle.textColor = [Colors textColor];
        boxDescription.textColor = [Colors textColor];
        
        navItem.leftBarButtonItem.tintColor = [Colors textColor];
        navItem.rightBarButtonItem.tintColor = [Colors textColor];
        
        [seekBar setMinimumTrackTintColor:[Colors tintColor]];
        
        for (UIBarButtonItem* item in toolBar.subviews) {
            item.tintColor = [Colors textColor];
        }
        
        playButton.tintColor = [Colors textColor];
        for (UIBarButtonItem* item in playBar.subviews) {
            item.tintColor = [Colors textColor];
        }
    }
    
}

- (void) setStarRating:(double) rating {
    rating = (rating*2.0) / 100.0;
    
    UIFont *font = [UIFont fontWithName:@"Helvetica-Bold" size:16];
    NSDictionary *userAttributes = @{NSFontAttributeName: font};
    const CGSize textSize = [@"★★★★★" sizeWithAttributes: userAttributes];
    stars.frame = CGRectMake(
                             [[UIScreen mainScreen] bounds].size.width - textSize.width - 10 ,
                             (topContainer.frame.size.height - 36),
                             textSize.width * rating,
                             29);
}

- (void) scrollToChannel:(dtvChannel *) channel {
    int row = -1;
    int section = -1;
    
    int sectionCounter = 0;
    int rowCounter = 0;
    
    NSArray *sections = [[sortedChannels allKeys]
                         sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    for (NSString *sectionKey in sections) {
        NSMutableDictionary *sectionData = [sortedChannels objectForKey:sectionKey];

        //NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
        id channelSort = ^(NSString *chId1, NSString *chId2){
            dtvChannel *channel1 = channels[chId1];
            dtvChannel *channel2 = channels[chId2];
            return channel1.number > channel2.number;
        };
        NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingComparator:channelSort];
        
        for (id sectionChannelKey in sectionChannels) {
            dtvChannel *thisChannel = sectionData[sectionChannelKey];
            if (channel.number == thisChannel.number) {
                row = rowCounter;
                section = sectionCounter;
            }
            rowCounter++;
        }
        sectionCounter++;
        rowCounter = 0;
    }
    
    if (row > -1 && section > -1) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
        [mainTableView scrollToRowAtIndexPath:indexPath
                             atScrollPosition:UITableViewScrollPositionTop
                                     animated:YES];
    }
}

- (void) toggleVibrancyEffects:(UIImage *) image enable:(BOOL)enable {
    BOOL canDoVibrancy = YES;
    if (enable) {
        if (image == nil) {
            canDoVibrancy = NO;
            NSLog(@"No Image, cannot enable vibrancy effect");
        } else {
            if (image.size.width < 50) {
                canDoVibrancy = NO;
                NSLog(@"Small Image, cannot enable vibrancy effect");
            }
        }
    }
    
    if (enable && canDoVibrancy) {
        [boxCover setImage:image];

        backgroundView.image = image;
        [mainTableView setBackgroundColor:[Colors transparentColor]];
        usingVibrancy = YES;
        [mainTableView reloadData];
        
        navbar.barTintColor = [Colors navClearColor];
        [navbar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
        navbar.translucent = YES;
        
        /*
        averageColor = [Colors averageColor:image];
        navbar.tintColor = averageColor;
        [navSubTitle setTextColor: averageColor];
        */
        
    } else {
        image = [Colors imageWithColor:[Colors backgroundColor]];
        [boxCover setImage:nil];
        backgroundView.image = image;
        [mainTableView setBackgroundColor:[Colors backgroundColor]];
        usingVibrancy = NO;
        [mainTableView reloadData];

        navbar.barTintColor = [Colors navBGColor];
        [navbar setBackgroundImage:image forBarMetrics:UIBarMetricsDefault];
        navbar.translucent = NO;
        navbar.tintColor = [Colors textColor];
        
        [navSubTitle setTextColor: [Colors textColor]];
    }

}

- (void) clearNowPlaying {
    boxCover.image = [UIImage new];
    boxTitle.text = @"";
    boxDescription.text = @"";
    channelImage.image = nil;
    currentProgramId = @"";
}


#pragma mark - Guide Updates

- (void) refreshGuideForTime:(NSDate *)time {

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    NSDate *dt = [dtvGuide getHalfHourIncrement:time];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MMM, d h:mm a"];
    [self showStatusOverlay:[NSString stringWithFormat:@"Loading guide for %@",
                             [formatter stringFromDate:dt]]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [dtvGuide refreshGuide:channels sorted:sortedChannels forTime:dt];
    });
}

- (void) sendGuideDataToUI:(NSMutableDictionary *) newGuide isFuture:(BOOL)future {
    guide = newGuide;
    guideIsRefreshing = NO;
    
    sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        if (future) {
            CGRect frm = overlayProgress.frame;
            frm.size.width = [[UIScreen mainScreen] bounds].size.width;
            overlayProgress.frame = frm;
            overlayProgress.hidden = NO;
            overlayLabel.text = [overlayLabel.text stringByReplacingOccurrencesOfString:@"Loading"
                                                                               withString:@"Showing future"];
        }
        [mainTableView reloadData];
    }];
}

- (void) changedGuideTime:(UIDatePicker *)sender {
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateStyle:NSDateFormatterFullStyle];
    [dateFormat setTimeStyle:NSDateFormatterFullStyle];
    guideTime.text = [dateFormat stringFromDate:sender.date];
}

- (void) showStatusOverlay:(NSString *) message {
    
    if (![self isVisible]) {
        return;
    }
    
    [UIApplication sharedApplication].statusBarHidden = YES;
    
    overlayProgress.hidden = YES;
    CGRect frm = overlayProgress.frame;
    frm.size.width = 0;
    overlayProgress.frame = frm;
    overlayProgress.hidden = NO;
    
    overlay.alpha = 0;
    overlayLabel.text = message;
    
    [UIView animateWithDuration:0.5
                     animations:^{
                         overlay.alpha = 1.0;
                     }
                     completion:^(BOOL finished) {
                         if (finished) {
                             [UIApplication sharedApplication].statusBarHidden = YES;
                         }
                     }];
}

- (void) hideStatusOverlay:(NSString *) message {
    
    if (![self isVisible]) {
        return;
    }
    
    [UIApplication sharedApplication].statusBarHidden = YES;
    overlay.alpha = 1.0;
    overlayLabel.text = message;
    overlayProgress.hidden = YES;
    
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 3);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        [UIView animateWithDuration:0.5
                         animations:^{
                             overlay.alpha = 0.0;
                         }
                         completion:^(BOOL finished) {
                             if (finished) {
                                 [UIApplication sharedApplication].statusBarHidden = NO;
                             }
                         }];
    });
}

@end
