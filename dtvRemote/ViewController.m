//
//  ViewController.m
//  dtvRemote
//
//  Created by Jed Lippold on 2/21/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "ViewController.h"
#import <QuartzCore/QuartzCore.h>

#import "dtvChannels.h"
#import "dtvChannel.h"
#import "dtvGuide.h"
#import "dtvCommands.h"
#import "dtvDevices.h"
#import "dtvDevice.h"
#import "SideBarTableView.h"
#import "MBProgressHUD.h"
#import "Reachability.h"
#import "CDRTranslucentSideBar.h"

@interface ViewController () <CDRTranslucentSideBarDelegate>
    @property (nonatomic, strong) CDRTranslucentSideBar *sideBar;
@end

@implementation ViewController {

    NSMutableDictionary *channels;
    NSMutableDictionary *allChannels;
    NSMutableDictionary *sortedChannels;
    NSMutableArray *blockedChannels;
    NSMutableDictionary *guide;
    NSMutableDictionary *devices;
    dtvDevice *currentDevice;
    
    UIView *centerView;
    UIView *sideBarView;
    UITableView *sideBarTable;
    UITableView *mainTableView;
    IBOutlet UINavigationBar *navbar;
    IBOutlet UILabel *navTitle;
    IBOutlet UILabel *navSubTitle;
    IBOutlet UINavigationItem *navItem;
    IBOutlet UIBarButtonItem *rightButton;
    UISearchController *searchController;
    UISearchBar *searchBar;
    UIImageView *boxCover;
    UILabel *boxTitle;
    UILabel *boxDescription;
    UIView *topContainer;
    UIToolbar *playBar;
    UIView *overlay;
    UILabel *overlayLabel;
    UIView *overlayProgress;
    UIRefreshControl *refreshControl;

    IBOutlet UIBarButtonItem *playButton;

    UILabel *hdLabel;
    UILabel *stars;
    UILabel *ratingLabel;
    IBOutlet UISlider *seekBar;
    UIToolbar *toolBar;
    UITextField *commandText;
    UITextField *guideTime;
    UIDatePicker *guideDatePicker;
    NSTimer *timer;
    NSTimer *ssidTimer;
    
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
    
    BOOL dragging;
    
    id SideBarTableViewData;
    
    UIColor *textColor;
    UIColor *backgroundColor;
    UIColor *tableBackgroundColor;
    UIColor *seperatorColor;
    UIColor *boxBackgroundColor;
    UIColor *navBGColor;
    UIColor *tint;
    Reachability *reach;
    
    
}

#pragma mark - Initialization


- (void) viewDidLoad {
    [super viewDidLoad];
    [self setNeedsStatusBarAppearanceUpdate];
    
    reach = [Reachability reachabilityForLocalWiFi];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    
    [reach startNotifier];
    
    [self initiate];
}

- (IBAction) reachabilityChanged:(id)sender  {
    NSLog(@"Network has changed, refreshing device list");
    [dtvDevices refreshDevicesForNetworks];
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) initiate {
    
    nextRefresh = [NSDate date];
    currentProgramId = @"";
    
    channels = [dtvChannels load:NO];
    allChannels = [dtvChannels load:YES];
    sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
    blockedChannels = [dtvChannels loadBlockedChannels:channels];
    
    guide = [[NSMutableDictionary alloc] init];
    
    devices = [dtvDevices getSavedDevicesForActiveNetwork];
    currentDevice = [dtvDevices getCurrentDevice];
    isEditing = NO;
    isPlaying = YES;
    
    ssidTimer = [[NSTimer alloc] init];
    
    timer = [[NSTimer alloc] init];

    xOffset = 140;
    searchBarMinWidth = 74;
    tableXOffset = 255;
    toolbarHeight = 40;
    searchBarMaxWidth = [[UIScreen mainScreen] bounds].size.width - xOffset;
    
    [self registerForNotifications];
    [self createViews];
    [self displayDevice];
    
    
    if ([[channels allKeys] count] == 0) { //run initial setup
        dispatch_after(0, dispatch_get_main_queue(), ^{
            [self promptForZipCode:nil];
        });
    } else {
        [self refreshGuide:nil];
        
        if (currentDevice) {
            [self refreshNowPlaying:nil scrollToPlayingChanel:YES];
        } else {
            [self setDefaultNowPlayingChannel];
        }
        
    }
    
    timer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                              target:self
                                            selector:@selector(onTimerFire:)
                                            userInfo:nil
                                             repeats:YES];
    

}

- (void) onTimerFire:(id)sender {
    [self refreshNowPlaying:nil scrollToPlayingChanel:NO];
    
    if ([[NSDate date] timeIntervalSinceDate:nextRefresh] >= 0) {
        [self refreshGuide:nil];
    }
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageRefreshSideBarDevices:)
                                                 name:@"messageRefreshSideBarDevices" object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedCurrentDevice:)
                                                 name:@"messageUpdatedCurrentDevice" object:nil];
    
    
}


#pragma mark - View Creation

- (void) createViews {
    
    textColor = [UIColor colorWithRed:193/255.0f green:193/255.0f blue:193/255.0f alpha:1.0f];
    backgroundColor = [UIColor colorWithRed:30/255.0f green:30/255.0f blue:30/255.0f alpha:1.0f];
    boxBackgroundColor = [UIColor colorWithRed:28/255.0f green:28/255.0f blue:28/255.0f alpha:1.0f];
    navBGColor = [UIColor colorWithRed:23/255.0f green:23/255.0f blue:23/255.0f alpha:1.0f];
    tint = [UIColor colorWithRed:30/255.0f green:147/255.0f blue:212/255.0f alpha:1.0f];
    seperatorColor = [UIColor colorWithRed:40/255.0f green:40/255.0f blue:40/255.0f alpha:1.0f];
    
    [self.view setBackgroundColor:backgroundColor];

    CGRect frm = [[UIScreen mainScreen] bounds];
    centerView = [[UIView alloc] initWithFrame:frm];
    [centerView setBackgroundColor:backgroundColor];
    centerView.userInteractionEnabled = YES;
    
    centerView.layer.masksToBounds = NO;
    centerView.layer.shadowOffset = CGSizeMake(0, 0);
    centerView.layer.shadowRadius = 3;
    centerView.layer.shadowOpacity = 0.5;
    centerView.layer.shadowPath = [UIBezierPath bezierPathWithRect:centerView.bounds].CGPath;
    
    frm.size.width = frm.size.width * 0.75;
    frm.origin.x = 0;
    sideBarView = [[UIView alloc] initWithFrame:frm];

    [self.view addSubview:centerView];
    
    [self createSideBar];
    [self createTitleBar];
    [self createTopSection];
    [self createTableView];
    [self createToolbar];

}

- (void) createSideBar {

    sideBarTable = [[UITableView alloc] init];
    CGRect tableFrame = [[UIScreen mainScreen] bounds];
    tableFrame.size.width = tableFrame.size.width * 0.75;
    tableFrame.size.height = tableFrame.size.height - 64;
    tableFrame.origin.x = 0;
    tableFrame.origin.y = 64;
    sideBarTable.frame = tableFrame;
    
    SideBarTableViewData = [[SideBarTableView alloc] init];
    
    sideBarTable.dataSource = SideBarTableViewData;
    sideBarTable.delegate = SideBarTableViewData;
    sideBarTable.separatorColor = seperatorColor;
    sideBarTable.backgroundColor = [UIColor clearColor];
    

    refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refreshDevices:) forControlEvents:UIControlEventValueChanged];
    [sideBarTable addSubview:refreshControl];
    
    [sideBarView addSubview:sideBarTable];
    
    CGRect navBarFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width * 0.75, 64.0);
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    bar.translucent = NO;
    bar.tintColor = tint;
    bar.barTintColor = navBGColor;
    bar.titleTextAttributes = @{NSForegroundColorAttributeName : textColor};

    UINavigationItem *sideBarNavItem = [UINavigationItem alloc];
    sideBarNavItem.title = @"Settings";
    [bar pushNavigationItem:sideBarNavItem animated:false];
    
    [sideBarView addSubview:bar];
    
    self.sideBar = [[CDRTranslucentSideBar alloc] init];
    self.sideBar.delegate = self;
    self.sideBar.tag = 55;
    self.sideBar.sideBarWidth = [[UIScreen mainScreen] bounds].size.width * 0.75;
    self.sideBar.translucentStyle = UIBarStyleBlack;
    [self.sideBar setContentViewInSideBar:sideBarView];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panSideBar:)];
    
    [self.view addGestureRecognizer:panGestureRecognizer];
    
}


- (void) createTitleBar {
    
    CGRect navBarFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, 64.0);
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    navbar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    navbar.barTintColor = navBGColor;
    
    navbar.translucent = NO;
    navbar.tintColor = tint;
    navbar.titleTextAttributes = @{NSForegroundColorAttributeName : textColor};
    
    navTitle = [[UILabel alloc] init];
    navTitle.translatesAutoresizingMaskIntoConstraints = YES;
    navTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:17];
    [navTitle setTextColor:textColor];
    navTitle.tintColor = tint;
    navTitle.textAlignment = NSTextAlignmentCenter;
    navTitle.frame = CGRectMake(0, 28, [[UIScreen mainScreen] bounds].size.width, 20);
    
    navSubTitle = [[UILabel alloc] init];
    navSubTitle.translatesAutoresizingMaskIntoConstraints = YES;
    navSubTitle.font = [UIFont fontWithName:@"Helvetica" size:15];
    [navSubTitle setTextColor: textColor];
    navSubTitle.textAlignment = NSTextAlignmentCenter;
    navSubTitle.frame = CGRectMake(0, 44, [[UIScreen mainScreen] bounds].size.width, 20);
    [navSubTitle setFont:[UIFont systemFontOfSize:14]];
    
    [navbar addSubview:navTitle];
    [navbar addSubview:navSubTitle];
    
    
    NSDictionary* barButtonItemAttributes =  @{NSFontAttributeName: [UIFont fontWithName:@"Helvetica" size:14.0f],
                                               NSForegroundColorAttributeName: tint};
    
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateNormal];
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateHighlighted];
    //[[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateSelected];
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateDisabled];
    
    
    
    navItem = [UINavigationItem alloc];
    navItem.title = @"";
    
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:@"Devices" style:UIBarButtonItemStylePlain target:self action:@selector(toggleEditMode:)];
    navItem.leftBarButtonItem = leftButton;
    
    rightButton = [[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(toggleEditMode:)];
    navItem.rightBarButtonItem = rightButton;
    
    [navbar pushNavigationItem:navItem animated:false];
    [centerView addSubview:navbar];
}

- (void) createTopSection {
    
    topContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 64,
                                                             [[UIScreen mainScreen] bounds].size.width,
                                                             tableXOffset - 64)];

    topContainer.alpha = 0.0;
    [centerView addSubview:topContainer];
    
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(5, 5, 120, 180)];
    [v setBackgroundColor:boxBackgroundColor];
    
    boxCover = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 120, 180)];
    [boxCover setImage:[UIImage new]];
    [v addSubview:boxCover];
    [topContainer addSubview:v];
    
    boxTitle = [[UILabel alloc] init];
    boxTitle.translatesAutoresizingMaskIntoConstraints = YES;
    boxTitle.text = @"";
    boxTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:17];
    [boxTitle setTextColor:textColor];

    boxTitle.textAlignment = NSTextAlignmentLeft;
    boxTitle.frame = CGRectMake(xOffset, 8, [[UIScreen mainScreen] bounds].size.width - xOffset, 18);
    [topContainer addSubview:boxTitle];
    
    
    playBar = [[UIToolbar alloc] init];
    playBar.tintColor = textColor;
    playBar.clipsToBounds = YES;
    playBar.frame = CGRectMake(xOffset,
                                (boxTitle.frame.size.height + boxTitle.frame.origin.y) + 12,
                                [[UIScreen mainScreen] bounds].size.width - (xOffset+5), 40);
    [playBar setBackgroundImage:[UIImage new] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil ];
    UIBarButtonItem *fit = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil ];
    fit.width = 15.0f;
    
    UIBarButtonItem *rewindButton = [[UIBarButtonItem alloc]
                                     initWithImage:[UIImage imageNamed:@"images.bundle/rewind.png"]
                                     style:UIBarButtonItemStylePlain target:self action:@selector(rewind:)];
    
    playButton = [[UIBarButtonItem alloc]
                   initWithImage:[UIImage imageNamed:@"images.bundle/pause"]
                   style:UIBarButtonItemStylePlain target:self action:@selector(playpause:) ];
    
    playButton.tintColor = textColor;
    
    UIBarButtonItem *forwardButton = [[UIBarButtonItem alloc]
                                      initWithImage:[UIImage imageNamed:@"images.bundle/forward.png"]
                                      style:UIBarButtonItemStylePlain target:self action:@selector(forward:) ];
    
    
    UIBarButtonItem *recButton = [[UIBarButtonItem alloc]
                                     initWithImage:[UIImage imageNamed:@"images.bundle/rec"]
                                     style:UIBarButtonItemStylePlain target:self action:@selector(rewind:)];
    
    recButton.tintColor = [UIColor colorWithRed:0.722 green:0.094 blue:0.094 alpha:0.5];
    
    NSArray *buttons = [NSArray arrayWithObjects:
                        flex, rewindButton, flex, flex, recButton, flex, playButton, flex, flex, forwardButton, flex, nil];
    [playBar setItems: buttons animated:NO];
    
    
    [topContainer addSubview:playBar];
    
    
    //seekbar
    seekBar = [[UISlider alloc] init];
    seekBar.frame = CGRectMake(xOffset,
                                (playBar.frame.size.height + playBar.frame.origin.y) ,
                                [[UIScreen mainScreen] bounds].size.width - (xOffset+5),
                                10);
    seekBar.minimumValue = 0.0;
    seekBar.maximumValue = 100.0;
    seekBar.value = 0;
    [seekBar setMaximumTrackTintColor:boxBackgroundColor];
    [seekBar setMinimumTrackTintColor:tint];
    
    seekBar.tintColor = textColor;
    seekBar.thumbTintColor = textColor;
    seekBar.userInteractionEnabled = NO;
    
    [seekBar setThumbImage:[UIImage new] forState:UIControlStateNormal];
    //[seekBar setThumbImage:[UIImage new] forState:UIControlStateSelected];
    [seekBar setThumbImage:[UIImage new] forState:UIControlStateHighlighted];

    [topContainer addSubview:seekBar];
    
    boxDescription = [[UILabel alloc] init];
    boxDescription.translatesAutoresizingMaskIntoConstraints = YES;
    boxDescription.numberOfLines = 4;
    boxDescription.text = @"";
    boxDescription.font = [UIFont fontWithName:@"Helvetica" size:12];
    [boxDescription setTextColor: textColor];
    boxDescription.textAlignment = NSTextAlignmentLeft;
    boxDescription.frame = CGRectMake(xOffset,
                                       (seekBar.frame.size.height + seekBar.frame.origin.y) + 4,
                                       [[UIScreen mainScreen] bounds].size.width - xOffset,
                                       56);

    [topContainer addSubview:boxDescription];
    
    searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(xOffset - 10,
                                                               (topContainer.frame.size.height - 42),
                                                               searchBarMinWidth, 44)];
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    searchBar.translucent = YES;
    searchBar.tintColor = [UIColor whiteColor];
    searchBar.backgroundColor = [UIColor clearColor];
    
    searchBar.barStyle = UIBarStyleBlackOpaque;
    searchBar.delegate = self;
    
    searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.dimsBackgroundDuringPresentation = NO;
    searchController.hidesNavigationBarDuringPresentation = NO;
    searchController.searchBar.frame = searchBar.frame;
    searchBar.enablesReturnKeyAutomatically = NO;

    [topContainer addSubview:searchBar];
    
    hdLabel= [[UILabel alloc] init];
    hdLabel.text = @"HD";
    hdLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    [hdLabel setBackgroundColor:[UIColor blackColor]];
    hdLabel.layer.cornerRadius = 5;
    hdLabel.layer.masksToBounds = YES;
    
    [hdLabel setTextColor:textColor];
    hdLabel.textAlignment = NSTextAlignmentCenter;
    hdLabel.frame = CGRectMake(7,
                               (topContainer.frame.size.height - 36),
                               31,
                               24);
    [hdLabel setHidden:YES];
    
    [topContainer addSubview:hdLabel];
    
    
    ratingLabel = [[UILabel alloc] init];
    ratingLabel.text = @"";
    ratingLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    [ratingLabel setBackgroundColor:[UIColor clearColor]];
    [ratingLabel setTextColor:textColor];
    ratingLabel.textAlignment = NSTextAlignmentCenter;
    ratingLabel.frame = CGRectMake(
                                   searchBar.frame.origin.x + searchBarMinWidth + 10,
                                   (topContainer.frame.size.height - 36),
                                   64,
                                   29);
    
    [ratingLabel setHidden:YES];
    
    [topContainer addSubview:ratingLabel];
    
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
    
    mainTableView.separatorColor = seperatorColor;
    mainTableView.backgroundColor = backgroundColor;
    
    [centerView addSubview:mainTableView];
    
}


- (void) createToolbar {
    
    double overlayHeight = 16;
    double progressHeight = 2;
    
    
    overlay = [[UIView alloc] init];
    overlay.opaque = YES;
    overlay.alpha = 0;
    overlay.backgroundColor = [UIColor blackColor];
    overlay.frame = CGRectMake(0, [[UIScreen mainScreen] bounds].size.height - (toolbarHeight + overlayHeight),
                               [[UIScreen mainScreen] bounds].size.width, overlayHeight);
    
    overlayProgress = [[UIView alloc] init];
    overlayProgress.frame = CGRectMake(0, overlayHeight - progressHeight,
                                        0, progressHeight);
    
    overlayProgress.opaque = YES;
    overlayProgress.alpha = 0.8;
    overlayProgress.backgroundColor = [UIColor redColor];
    

    
    overlayLabel = [[UILabel alloc] init];
    overlayLabel.textColor = textColor;
    overlayLabel.frame = CGRectMake(0, 0,[[UIScreen mainScreen] bounds].size.width, overlayHeight);
    overlayLabel.text = @"";
    overlayLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
    overlayLabel.textAlignment = NSTextAlignmentCenter;

    [overlay addSubview:overlayProgress];
    [overlay addSubview:overlayLabel];
    [centerView addSubview:overlay];
    
    toolBar = [[UIToolbar alloc] init];
    toolBar.clipsToBounds = YES;
    toolBar.frame = CGRectMake(0, [[UIScreen mainScreen] bounds].size.height - toolbarHeight, [[UIScreen mainScreen] bounds].size.width, toolbarHeight);
    [toolBar setBackgroundImage:[UIImage new] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    toolBar.tintColor = textColor;
    
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil ];
    
    /*
    UIBarButtonItem *clock = [[UIBarButtonItem alloc]
                                     initWithImage:[UIImage imageNamed:@"images.bundle/clock"]
                                     style:UIBarButtonItemStylePlain target:self action:@selector(selectGuideTime:) ];
     */
    
     UIBarButtonItem *clock = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemDownloads tag:0];
    
    UIBarButtonItem *numberPad = [[UIBarButtonItem alloc]
                                  initWithImage:[UIImage imageNamed:@"images.bundle/numberpad.png"]
                                  style:UIBarButtonItemStylePlain target:self action:@selector(showNumberPad:) ];
    
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                             target:self
                                                                             action:@selector(refreshGuide:)];
    
    
    UIBarButtonItem *commands = [[UIBarButtonItem alloc]
                                 initWithImage:[UIImage imageNamed:@"images.bundle/commands.png"]
                                 style:UIBarButtonItemStylePlain target:self action:@selector(showCommands:) ];
    
    UIBarButtonItem *sort = [[UIBarButtonItem alloc]
                             initWithImage:[UIImage imageNamed:@"images.bundle/sort.png"]
                             style:UIBarButtonItemStylePlain target:self action:@selector(sortChannels:) ];
    
    
    NSArray *buttons = [NSArray arrayWithObjects:  commands, flex , clock, flex, numberPad, flex, sort, flex, refresh, nil];
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
    

    commandText = [[UITextField alloc] initWithFrame:CGRectMake(0,0,1,1)];
    
    UIToolbar *commandTextDone = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, 44)];
    [commandTextDone setBarStyle:UIBarStyleBlackTranslucent];
    UIBarButtonItem *b1 = [[UIBarButtonItem alloc] initWithTitle:@"Last" style:UIBarButtonItemStylePlain
                                                             target:nil action:@selector(closeCommands:)];
    UIBarButtonItem *b2 = [[UIBarButtonItem alloc] initWithTitle:@"Last" style:UIBarButtonItemStylePlain
                                                          target:nil action:@selector(closeCommands:)];
    
    UIBarButtonItem *done3 = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone
                                                            target:nil action:@selector(closeCommands:)];
    
    [commandTextDone setItems: [NSArray arrayWithObjects:b2, flex, b1, flex, done3, nil]];
    [commandText setInputAccessoryView:commandTextDone];
    commandText.keyboardType = UIKeyboardTypeNumberPad;
    [commandText setHidden:YES];
    commandText.text = @"";
    [commandText addTarget:self
                  action:@selector(commandSend:)
        forControlEvents:UIControlEventEditingChanged];
    

    [centerView addSubview:commandText];

    
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
    return  18.0;
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
    v.backgroundView.backgroundColor = [UIColor blackColor];
    v.backgroundView.alpha = 0.9;
    v.backgroundView.tintColor = tint;
    
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setTextColor:textColor];
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray *sections = [[sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return [sections objectAtIndex:section];
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{

    cell.indentationLevel = 1;
    cell.indentationWidth = 2;
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    cell.backgroundColor = tableBackgroundColor;
    [cell.textLabel setTextColor: textColor];
    [cell.detailTextLabel setTextColor:textColor];
    
    cell.userInteractionEnabled = YES;
    [cell setTintColor:tint];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SomeId"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SomeId"];
        UILabel *label = [[UILabel alloc] init];
        label.text = @"";
        label.textColor = textColor;
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
    NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
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
        
        cell.textLabel.text = channel.name;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%d - %@", channel.number, channel.callsign];
        
        if ([blockedChannels containsObject:chId]) {
            cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage new]];
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    } else {
        cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage new]];
        
        [l2 setHidden:NO];
        l2.text = [NSString stringWithFormat:@"%d", channel.number];

    }

    
    //channel image
    UIImage *image = [UIImage new];
    NSString *cacheDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *imagePath =[cacheDirectory stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%d.png", channel.identifier]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        image = [UIImage imageWithContentsOfFile:imagePath];
    }
    cell.imageView.image = image;
    
    [cell setNeedsLayout];
    
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *sections = [[sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *sectionKey = [sections objectAtIndex:indexPath.section];
    NSMutableDictionary *sectionData = [sortedChannels objectForKey:sectionKey];
    NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
    NSString *chId = [sectionChannels objectAtIndex:indexPath.row];
    dtvChannel *channel = [sectionData objectForKey:chId];
    dtvGuideItem *guideItem = guide[chId];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (isEditing) {
        
        UITableViewCell *cell =[tableView cellForRowAtIndexPath:indexPath];
        if ([blockedChannels containsObject:chId]) {
            [blockedChannels removeObject:chId];
            cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage new]];
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            [blockedChannels addObject:chId];
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        [mainTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
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
        isEditing = NO;
        rightButton.title = @"Edit";
        channels = [dtvChannels load:NO];
        blockedChannels = [[NSMutableArray alloc] init];
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
        //NSIndexPath *indexpath = (NSIndexPath*)[[_mainTableView indexPathsForVisibleRows] objectAtIndex:0];
        
    } else {
        //Going into edit mode
        isEditing = YES;
        rightButton.title = @"Done";
        channels = [dtvChannels load:YES];
        blockedChannels = [dtvChannels loadBlockedChannels:channels];
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
    }
    
    [mainTableView reloadData];
}

- (IBAction) showNumberPad:(id)sender {
    
    if (!currentDevice) {
        return;
    }
    
    [commandText becomeFirstResponder];
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

- (IBAction) closeCommands:(id)sender {
    commandText.text = @"";
    [commandText resignFirstResponder];
}

- (IBAction) showCommands:(id)sender {
     [self.sideBar show];
}

- (void)panSideBar:(UIPanGestureRecognizer *)recognizer
{
    self.sideBar.isCurrentPanGestureTarget = YES;
    [self.sideBar handlePanGestureToShow:recognizer inView:self.view];
}


- (void) commandSend:(id)sender {
    // there was a text change in some control
    NSString *command = commandText.text;
    if (![command isEqualToString:@""]) {
        [dtvCommands sendCommand:command device:currentDevice];
    }
    commandText.text = @"";
}

#pragma mark - Sidebar events


- (void)sideBar:(CDRTranslucentSideBar *)sideBar didAppear:(BOOL)animated {
    
}
- (void)sideBar:(CDRTranslucentSideBar *)sideBar willAppear:(BOOL)animated {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [dtvDevices checkStatusOfDevices:devices];
    });
}
- (void)sideBar:(CDRTranslucentSideBar *)sideBar didDisappear:(BOOL)animated {

}
- (void)sideBar:(CDRTranslucentSideBar *)sideBar willDisappear:(BOOL)animated {

}


#pragma mark - Messages / Events

- (void) messageUpdatedLocations:(NSNotification *)notification {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSMutableDictionary *locations = [notification object];
    [self promptForLocation:locations];
}


- (void) messageAPIDown:(NSNotification *)notification {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Connection Error"
                                                                   message:@"Error accessing directv guide" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* accept = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:accept];
    [self presentViewController:alert animated:YES completion:nil];
    
}


- (void) messageDownloadChannelLogos:(NSNotification *)notification {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    channels = [notification object];
    allChannels = [notification object];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.labelText = @"Downloading channel logos";
        hud.detailsLabelText = @"for first use";
        [dtvChannels downloadChannelImages:channels];
    });
    
}

- (void) messageUpdatedChannels:(NSNotification *)notification {
    channels = [notification object];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        sortedChannels = [dtvChannels sortChannels:channels sortBy:@"default"];
        [mainTableView reloadData];
        [self refreshGuide:nil];
        [self setDefaultNowPlayingChannel];
    });
    
}

- (void) messageUpdatedChannelsProgress:(NSNotification *)notification {
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.progress = [[notification object] floatValue];
    
}

- (void) messageUpdatedDevices:(NSNotification *)notification {
    devices = notification.object;
    
    if ([devices count] == 0) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Devices Found"
                                                                       message:@"No devices found on this wifi network." preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* accept = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:accept];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    } else {
        [sideBarTable reloadData];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }
}

- (void) messageUpdatedDevicesProgress:(NSNotification *)notification {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = [[notification object] floatValue];
    }];
}

- (void) messageNextGuideRefreshTime:(NSNotification *)notification {
    nextRefresh = [notification object];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"h:mm a"];
        overlayLabel.text = [NSString stringWithFormat:@"Next Refresh at %@",
                              [formatter stringFromDate:nextRefresh]];
        [self toggleOverlay:@"hide"];
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
    [self setNowPlaying:channel];
}

- (void) messageRefreshSideBarDevices:(NSNotification *)notification {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [sideBarTable reloadData];
    }];
}

- (void) messageUpdatedCurrentDevice:(NSNotification *)notification {
    currentDevice = notification.object;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self clearNowPlaying];
        [self displayDevice];
        [sideBarTable reloadData];
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.3);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            [self.sideBar dismiss];
        });
    }];
}




#pragma mark - UI Updates

- (void) displayDevice {
    if (currentDevice) {
        navTitle.text = [currentDevice.name capitalizedString];
        [self refreshNowPlaying:nil scrollToPlayingChanel:YES];
    } else {
        navTitle.text = @"No Device Selected";
        navSubTitle.text = @"N/A";
        [self clearNowPlaying];
    }
}

- (IBAction)refreshDevices:(id)sender {
    [refreshControl endRefreshing];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.labelText = @"Scanning wifi network for devices...";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [dtvDevices refreshDevicesForNetworks];
    });
}

-(void)hideTopContainer:(BOOL) hide {
    if (hide) {
        [UIView animateWithDuration:0.25
                         animations:^{
                             topContainer.alpha = 0.0;
                             boxTitle.text = @"";
                             boxDescription.text = @"";
                             [ratingLabel setHidden:YES];
                             [stars setHidden:YES];
                         }];
    } else {
        [UIView animateWithDuration:0.5
                         animations:^{
                             topContainer.alpha = 1.0;
                         }];
    }
}


- (void) setDefaultNowPlayingChannel {
    dtvChannel *channel = [dtvChannels getChannelByCallSign:@"HBOe" channels:channels];
    [self setNowPlaying:channel];
}

- (void) refreshNowPlaying:(id)sender scrollToPlayingChanel:(BOOL)scroll {
    if (currentDevice) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *channelNum = [dtvCommands getChannelOnDevice:currentDevice];
            dtvChannel *channel = [dtvChannels getChannelByNumber:[channelNum intValue] channels:allChannels];
            
            if (channel.identifier == 0) {
                [self clearNowPlaying];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self setNowPlaying:channel];
                    if (scroll) {
                        [self scrollToChannel:channel];
                    }
                });
            }
        });
    }
}

- (void) setNowPlaying:(dtvChannel *) channel {

   // NSLog(@"Querying Now Playing");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSDictionary *guideData = [dtvGuide getNowPlayingForChannel:channel];
        if ([[guideData allKeys] count] == 0) {
            return;
        }
        dtvGuideItem *guideItem = [guide objectForKey:[guideData allKeys][0]];
        NSDictionary *duration = [dtvGuide getDurationForChannel:guideItem];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNowPlayingForChannel:channel guideItem:guideItem duration:duration];
        });
    });

}

- (void) setNowPlayingForChannel:(dtvChannel *)channel guideItem:(dtvGuideItem*)guideItem duration:(NSDictionary *)duration {
    
    seekBar.value = [duration[@"percentage"] doubleValue];

    if ([currentProgramId isEqualToString:guideItem.programID]) {
        return;
    }
    
    [self hideTopContainer:YES];
    currentProgramId = guideItem.programID;
    
    if (guideItem.hd) {
        [hdLabel setHidden:NO];
    } else {
        [hdLabel setHidden:YES];
    }
    
    navSubTitle.text = [NSString stringWithFormat:@"%d %@", channel.number, channel.name];
    [self setDescriptionForProgramId:guideItem.programID];
    [self setBoxCoverForChannel:guideItem.imageUrl];

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
    
    NSArray *sections = [[sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *sectionKey in sections) {
        NSMutableDictionary *sectionData = [sortedChannels objectForKey:sectionKey];
        NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
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

- (void) setDescriptionForProgramId:(NSString *)programID {
    
    NSURL* programURL = [NSURL URLWithString:
                         [NSString stringWithFormat:@"https://www.directv.com/json/program/flip/%@", programID]];
    
    boxTitle.text = @"";
    boxDescription.text = @"";
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:programURL]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError)
     {
         if (data.length > 0 && connectionError == nil) {
             NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];

             if (json[@"programDetail"]) {

                 id show = json[@"programDetail"];
                 if (show[@"description"]) {
                     boxDescription.text = show[@"description"];
                 }
                 NSString *title = show[@"title"];
                 
                 if (show[@"title"] && show[@"episodeTitle"]) {
                     title = [NSString stringWithFormat:@"%@ - %@",
                              title, show[@"episodeTitle"]];
                 }
                 if (show[@"title"] && show[@"releaseYear"]) {
                     title = [NSString stringWithFormat:@"%@ (%@)",
                              title, show[@"releaseYear"]];
                 }
                 
                 if (show[@"rating"]) {
                     ratingLabel.text = show[@"rating"];
                     [ratingLabel setHidden:NO];
                 } else {
                     [ratingLabel setHidden:YES];
                 }
                 
                 if (show[@"starRatingNum"]) {
                     [self setStarRating:[show[@"starRatingNum"] doubleValue]];
                     [stars setHidden:NO];
                 } else {
                     [stars setHidden:YES];
                 }
                 
                 boxTitle.text = title;
                 
             }
         }
     }];
}

- (void) setBoxCoverForChannel:(NSString *)path {
    NSURL* imageUrl = [NSURL URLWithString:
                       [NSString stringWithFormat:@"https://dtvimages.hs.llnwd.net/e1%@", path]];
    
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:imageUrl]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError)
     {
         if (data.length > 0 && connectionError == nil) {
             UIImage *image = [UIImage imageWithData:data];
             [boxCover setImage:image];
         }
         [self hideTopContainer:NO];
     }];

}

- (void) clearNowPlaying {
    boxCover.image = [UIImage new];
    boxTitle.text = @"";
    boxDescription.text = @"";
}

#pragma mark - Guide Updates

- (void) refreshGuideForTime:(NSDate *)time {

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    CGRect frm = overlayProgress.frame;
    frm.size.width = 0;
    overlayProgress.frame = frm;
    overlayProgress.hidden = NO;
    [self toggleOverlay:@"show"];
    

    NSDate *dt = [dtvGuide getHalfHourIncrement:time];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MMM, d h:mm a"];
    overlayLabel.text = [NSString stringWithFormat:@"Loading guide for %@",
                          [formatter stringFromDate:dt]];

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
        } else {
            overlayProgress.hidden = YES;
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

- (void) toggleOverlay:(NSString *)action {
    if ([action isEqualToString:@"show"]) {
        [UIView animateWithDuration:0.5
                         animations:^{
                             overlay.alpha = 0.8;
                         }];
    } else {
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 3);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            [UIView animateWithDuration:0.5
                             animations:^{
                                 overlay.alpha = 0.0;
                             }];
        });
    }
}


@end
