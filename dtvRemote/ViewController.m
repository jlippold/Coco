//
//  ViewController.m
//  dtvRemote
//
//  Created by Jed Lippold on 2/21/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "ViewController.h"
#import "MBProgressHUD.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <QuartzCore/QuartzCore.h>

#import "iNet.h"
#import "Channels.h"
#import "Guide.h"
#import "Commands.h"
#import "Clients.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setNeedsStatusBarAppearanceUpdate];
    [self initiate];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) initiate {
    
    _nextRefresh = [NSDate date];
    _currentProgramId = @"";
    
    _channels = [Channels load:NO];
    _allChannels = [Channels load:YES];
    
    _guide = [[NSMutableDictionary alloc] init];
    _sortedChannels = [[NSMutableDictionary alloc] init];
    _blockedChannels = [[NSMutableArray alloc] init];
    
    _ssid = [iNet fetchSSID];
    _clients = [Clients loadClientList];
    _currentClient = [Clients getClient];
    isEditing = NO;
    isPlaying = YES;
    
    _ssidTimer = [[NSTimer alloc] init];
    
    _timer = [[NSTimer alloc] init];
    
    xOffset = 140;
    searchBarMinWidth = 74;
    searchBarMaxWidth = [[UIScreen mainScreen] bounds].size.width - xOffset;
    
    
    [self registerForNotifications];
    [self createMainView];
    
    
    if ([[_channels allKeys] count] == 0) { //run initial setup
        dispatch_after(0, dispatch_get_main_queue(), ^{
            [self promptForZipCode];
        });
    } else {
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"default"];
        [self refreshGuide:nil];
    }
    
    
    if ([[_currentClient allKeys] count] != 0) {
        [self refreshNowPlaying:nil scrollToPlayingChanel:YES];
    }


    _timer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                              target:self
                                            selector:@selector(onTimerFire:)
                                            userInfo:nil
                                             repeats:YES];
    
   _ssidTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                 target:self
                                               selector:@selector(fetchSSID:)
                                               userInfo:nil
                                                repeats:YES];
    //[_timer fire];
    //[_ssidTimer fire];
}

-(void) onTimerFire:(id)sender {
    [self refreshNowPlaying:nil scrollToPlayingChanel:NO];
    
    if( [[NSDate date] timeIntervalSinceDate:_nextRefresh] >= 0 ) {
        [self refreshGuide:nil];
    }
}

- (void) registerForNotifications {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedClients:)
                                                 name:@"messageUpdatedClients" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedClientsProgress:)
                                                 name:@"messageUpdatedClientsProgress" object:nil];
    
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuidePartial:)
                                                 name:@"messageUpdatedGuidePartial" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuideProgress:)
                                                 name:@"messageUpdatedGuideProgress" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedLocations:)
                                                 name:@"messageUpdatedLocations" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageChannelChanged:)
                                                 name:@"messageChannelChanged" object:nil];
    
}

-(void) fetchSSID:(id)sender {
    self.ssid = [iNet fetchSSID];
}

- (void) selectInitialClient {
    
}

-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

- (void) createMainView {
    
    UIColor *backgroundColor = [UIColor colorWithRed:30/255.0f green:30/255.0f blue:30/255.0f alpha:1.0f];
    [self.view setBackgroundColor:backgroundColor];
    
    [self createTitleBar];
    [self createTopSection];
    [self createTableView];
    [self createToolbar];
    
}

- (void) createTitleBar {
    
    UIColor *navBGColor = [UIColor colorWithRed:23/255.0f green:23/255.0f blue:23/255.0f alpha:1.0f];
    UIColor *textColor = [UIColor colorWithRed:193/255.0f green:193/255.0f blue:193/255.0f alpha:1.0f];
    UIColor *navTint = [UIColor colorWithRed:30/255.0f green:147/255.0f blue:212/255.0f alpha:1.0f];
    
    CGRect navBarFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, 64.0);
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    _navbar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    _navbar.barTintColor = navBGColor;
    
    _navbar.translucent = NO;
    _navbar.tintColor = navTint;
    _navbar.titleTextAttributes = @{NSForegroundColorAttributeName : textColor};
    
    
    _navTitle = [[UILabel alloc] init];
    _navTitle.translatesAutoresizingMaskIntoConstraints = YES;
    _navTitle.text = @"";
    _navTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:17];
    [_navTitle setTextColor:textColor];
    _navTitle.tintColor = navTint;
    _navTitle.textAlignment = NSTextAlignmentCenter;
    _navTitle.frame = CGRectMake(0, 28, [[UIScreen mainScreen] bounds].size.width, 20);
    
    _navSubTitle = [[UILabel alloc] init];
    _navSubTitle.translatesAutoresizingMaskIntoConstraints = YES;
    _navSubTitle.text = @"";
    _navSubTitle.font = [UIFont fontWithName:@"Helvetica" size:15];
    [_navSubTitle setTextColor: textColor];
    _navSubTitle.textAlignment = NSTextAlignmentCenter;
    _navSubTitle.frame = CGRectMake(0, 44, [[UIScreen mainScreen] bounds].size.width, 20);
    [_navSubTitle setFont:[UIFont systemFontOfSize:14]];
    
    [_navbar addSubview:_navTitle];
    [_navbar addSubview:_navSubTitle];
    
    
    NSDictionary* barButtonItemAttributes =  @{NSFontAttributeName: [UIFont fontWithName:@"Helvetica" size:14.0f],
                                               NSForegroundColorAttributeName: navTint};
    
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateNormal];
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateHighlighted];
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateSelected];
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateDisabled];
    
    
    
    _navItem = [UINavigationItem alloc];
    _navItem.title = @"";
    
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:@"Room" style:UIBarButtonItemStylePlain target:self action:@selector(chooseClient:)];
    _navItem.leftBarButtonItem = leftButton;
    
    _rightButton = [[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(toggleEditMode:)];
    _navItem.rightBarButtonItem = _rightButton;
    
    [_navbar pushNavigationItem:_navItem animated:false];
    [self.view addSubview:_navbar];
}

- (void) createTopSection {
    
    UIColor *textColor = [UIColor colorWithRed:193/255.0f green:193/255.0f blue:193/255.0f alpha:1.0f];
    UIColor *boxBackgroundColor = [UIColor colorWithRed:28/255.0f green:28/255.0f blue:28/255.0f alpha:1.0f];
    UIColor *tint = [UIColor colorWithRed:30/255.0f green:147/255.0f blue:212/255.0f alpha:1.0f];
    
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(5, 70, 120, 180)];
    [v setBackgroundColor:boxBackgroundColor];
    
    //UITapGestureRecognizer *singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self
    //action:@selector(dismissKeyboard:)];
    //[v addGestureRecognizer:singleFingerTap];
    
    _boxCover = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 120, 180)];
    [_boxCover setImage:[UIImage new]];
    [v addSubview:_boxCover];
    [self.view addSubview:v];
    
    
    _boxTitle = [[UILabel alloc] init];
    _boxTitle.translatesAutoresizingMaskIntoConstraints = YES;
    _boxTitle.text = @"";
    _boxTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:17];
    [_boxTitle setTextColor:textColor];
    _boxTitle.textAlignment = NSTextAlignmentLeft;
    _boxTitle.frame = CGRectMake(xOffset, 82, [[UIScreen mainScreen] bounds].size.width - xOffset, 18);
    [self.view addSubview:_boxTitle];
    
    
    _playBar = [[UIToolbar alloc] init];
    //_playBar.clipsToBounds = YES;
    
    _playBar.tintColor = textColor;
    _playBar.frame = CGRectMake(xOffset, 106, [[UIScreen mainScreen] bounds].size.width - (xOffset+5), 40);
    [_playBar setBackgroundImage:[UIImage new] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil ];
    UIBarButtonItem *fit = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil ];
    fit.width = 15.0f;
    
    UIBarButtonItem *rewindButton = [[UIBarButtonItem alloc]
                                     initWithImage:[UIImage imageNamed:@"images.bundle/rewind.png"]
                                     style:UIBarButtonItemStylePlain target:self action:@selector(rewind:)];
    
    _playButton = [[UIBarButtonItem alloc]
                   initWithImage:[UIImage imageNamed:@"images.bundle/pause"]
                   style:UIBarButtonItemStylePlain target:self action:@selector(playpause:) ];
    
    _playButton.tintColor = textColor;
    
    UIBarButtonItem *forwardButton = [[UIBarButtonItem alloc]
                                      initWithImage:[UIImage imageNamed:@"images.bundle/forward.png"]
                                      style:UIBarButtonItemStylePlain target:self action:@selector(forward:) ];
    
    
    NSArray *buttons = [NSArray arrayWithObjects: flex, rewindButton, flex, _playButton, flex, forwardButton, flex, nil];
    [_playBar setItems: buttons animated:NO];
    
    [self.view addSubview:_playBar];
    
    
    //seekbar
    _seekBar = [[UISlider alloc] init];
    _seekBar.frame = CGRectMake(xOffset, 146, [[UIScreen mainScreen] bounds].size.width - (xOffset+5), 10);
    _seekBar.minimumValue = 0.0;
    _seekBar.maximumValue = 100.0;
    _seekBar.value = 0;
    [_seekBar setMaximumTrackTintColor:boxBackgroundColor];
    [_seekBar setMinimumTrackTintColor:tint];
    
    _seekBar.tintColor = textColor;
    _seekBar.thumbTintColor = textColor;
    _seekBar.userInteractionEnabled = NO;
    
    /*
    [_seekBar setThumbImage:[UIImage imageNamed:@"images.bundle/scrubber"] forState:UIControlStateNormal];
    [_seekBar setThumbImage:[UIImage imageNamed:@"images.bundle/scrubber"] forState:UIControlStateSelected];
    [_seekBar setThumbImage:[UIImage imageNamed:@"images.bundle/scrubber"] forState:UIControlStateHighlighted];
    */
    [_seekBar setThumbImage:[UIImage new] forState:UIControlStateNormal];
    [_seekBar setThumbImage:[UIImage new] forState:UIControlStateSelected];
    [_seekBar setThumbImage:[UIImage new] forState:UIControlStateHighlighted];
    
    [self.view addSubview:_seekBar];
    
    _boxDescription = [[UILabel alloc] init];
    _boxDescription.translatesAutoresizingMaskIntoConstraints = YES;
    _boxDescription.numberOfLines = 4;
    _boxDescription.text = @"";
    _boxDescription.font = [UIFont fontWithName:@"Helvetica" size:12];
    [_boxDescription setTextColor: textColor];
    _boxDescription.textAlignment = NSTextAlignmentLeft;
    _boxDescription.frame = CGRectMake(xOffset, 165, [[UIScreen mainScreen] bounds].size.width - xOffset, 56);
    [self.view addSubview:_boxDescription];
    
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(xOffset - 10, 215, searchBarMinWidth, 44)];
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.translucent = YES;
    _searchBar.tintColor = [UIColor whiteColor];
    _searchBar.backgroundColor = [UIColor clearColor];
    
    _searchBar.barStyle = UIBarStyleBlackOpaque;
    _searchBar.delegate = self;
    
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    
    //_searchController.searchResultsUpdater = self;
    _searchController.dimsBackgroundDuringPresentation = NO;
    _searchController.hidesNavigationBarDuringPresentation = NO;
    _searchController.searchBar.frame = _searchBar.frame;
    _searchBar.enablesReturnKeyAutomatically = NO;
    
    [self.view addSubview:_searchBar];
    
     _hdLabel= [[UILabel alloc] init];
    _hdLabel.text = @"HD";
    _hdLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    [_hdLabel setBackgroundColor:[UIColor blackColor]];
    _hdLabel.layer.cornerRadius = 5;
    _hdLabel.layer.masksToBounds = YES;
    
    [_hdLabel setTextColor:textColor];
    _hdLabel.textAlignment = NSTextAlignmentCenter;
    _hdLabel.frame = CGRectMake(7,
                               223,
                               31,
                               24);
    [_hdLabel setHidden:YES];
    
    [self.view addSubview:_hdLabel];
    
    
    _ratingLabel = [[UILabel alloc] init];
    _ratingLabel.text = @"";
    _ratingLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    [_ratingLabel setBackgroundColor:[UIColor clearColor]];
    [_ratingLabel setTextColor:textColor];
    _ratingLabel.textAlignment = NSTextAlignmentCenter;
    _ratingLabel.frame = CGRectMake(
                                   _searchBar.frame.origin.x + searchBarMinWidth + 10,
                                   223,
                                   64,
                                   29);
    
    [_hdLabel setHidden:YES];
    
    [self.view addSubview:_ratingLabel];
    
    _stars = [[UILabel alloc] init];
    _stars.text = @"★★★★★";
    _stars.font = [UIFont fontWithName:@"Helvetica-Bold" size:16];
    _stars.clipsToBounds = YES;
    _stars.adjustsFontSizeToFitWidth = NO;
    _stars.lineBreakMode = NSLineBreakByClipping;
    _stars.layer.masksToBounds = YES;
    [_stars setTextColor:[UIColor colorWithRed:0.941 green:0.812 blue:0.376 alpha:1]];  /*#f0cf60*/
    _stars.textAlignment = NSTextAlignmentLeft;
    _stars.frame = CGRectMake(
                             0,
                             223,
                             0,
                             29);
    [_stars setHidden:YES];
    [self.view addSubview:_stars];

    
}

- (void) createTableView {
    double tableXOffset = 255;
    double toolbarHeight = 40;
    
    UIColor *seperatorColor = [UIColor colorWithRed:40/255.0f green:40/255.0f blue:40/255.0f alpha:1.0f];
    UIColor *backgroundColor = [UIColor colorWithRed:30/255.0f green:30/255.0f blue:30/255.0f alpha:1.0f];
    
    
    _mainTableView = [[UITableView alloc] init];
    [_mainTableView setFrame:CGRectMake(0, tableXOffset,
                                        [[UIScreen mainScreen] bounds].size.width,
                                        [[UIScreen mainScreen] bounds].size.height-(tableXOffset+ toolbarHeight))];
    _mainTableView.dataSource = self;
    _mainTableView.delegate = self;
    
    _mainTableView.separatorColor = seperatorColor;
    _mainTableView.backgroundColor = backgroundColor;
    
    
    [self.view addSubview:_searchBar];
    [self.view addSubview:_mainTableView];
    
}


- (void) createToolbar {
    
    double toolbarHeight = 40;
    double overlayHeight = 16;
    double progressHeight = 2;
    
    UIColor *textColor = [UIColor colorWithRed:193/255.0f green:193/255.0f blue:193/255.0f alpha:1.0f];
    
    _overlay = [[UIView alloc] init];
    _overlay.opaque = YES;
    _overlay.alpha = 0;
    _overlay.backgroundColor = [UIColor blackColor];
    _overlay.frame = CGRectMake(0, [[UIScreen mainScreen] bounds].size.height - (toolbarHeight + overlayHeight),
                               [[UIScreen mainScreen] bounds].size.width, overlayHeight);
    
    _overlayProgress = [[UIView alloc] init];
    _overlayProgress.frame = CGRectMake(0, overlayHeight - progressHeight,
                                        0, progressHeight);
    
    _overlayProgress.opaque = YES;
    _overlayProgress.alpha = 0.8;
    _overlayProgress.backgroundColor = [UIColor redColor];
    

    
    _overlayLabel = [[UILabel alloc] init];
    _overlayLabel.textColor = textColor;
    _overlayLabel.frame = CGRectMake(0, 0,[[UIScreen mainScreen] bounds].size.width, overlayHeight);
    _overlayLabel.text = @"";
    _overlayLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
    _overlayLabel.textAlignment = NSTextAlignmentCenter;

    [_overlay addSubview:_overlayProgress];
    [_overlay addSubview:_overlayLabel];
    [self.view addSubview:_overlay];
    
    _toolBar = [[UIToolbar alloc] init];
    _toolBar.clipsToBounds = YES;
    _toolBar.frame = CGRectMake(0, [[UIScreen mainScreen] bounds].size.height - toolbarHeight, [[UIScreen mainScreen] bounds].size.width, toolbarHeight);
    [_toolBar setBackgroundImage:[UIImage new] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    _toolBar.tintColor = textColor;
    
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil ];
    
    /*
    UIBarButtonItem *guideBack = [[UIBarButtonItem alloc]
                                  initWithImage:[UIImage imageNamed:@"images.bundle/left.png"]
                                  style:UIBarButtonItemStylePlain target:self action:@selector(stub:) ];
    
    
    UIBarButtonItem *guideForward = [[UIBarButtonItem alloc]
                                     initWithImage:[UIImage imageNamed:@"images.bundle/right"]
                                     style:UIBarButtonItemStylePlain target:self action:@selector(stub:) ];
    */
    
    UIBarButtonItem *numberPad = [[UIBarButtonItem alloc]
                                  initWithImage:[UIImage imageNamed:@"images.bundle/numberpad.png"]
                                  style:UIBarButtonItemStylePlain target:self action:@selector(showNumberPad:) ];
    
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                             target:self
                                                                             action:@selector(refreshGuide:)];
    
    UIBarButtonItem *commands = [[UIBarButtonItem alloc]
                                 initWithImage:[UIImage imageNamed:@"images.bundle/commands.png"]
                                 style:UIBarButtonItemStylePlain target:self action:@selector(stub:) ];
    
    UIBarButtonItem *sort = [[UIBarButtonItem alloc]
                             initWithImage:[UIImage imageNamed:@"images.bundle/sort.png"]
                             style:UIBarButtonItemStylePlain target:self action:@selector(sortChannels:) ];
    
    
    NSArray *buttons = [NSArray arrayWithObjects:  commands, flex , sort, flex, numberPad, flex, refresh, nil];
    [_toolBar setItems:buttons animated:NO];
    
    [self.view addSubview:_toolBar];
    
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [self openSearchBar];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self closeSearchBar];
}

- (void)searchBarTextDoneEditing:(UISearchBar *)searchBar {
    [self closeSearchBar];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self closeSearchBar];
}

- (void) closeSearchBar {
    [_searchBar resignFirstResponder];
    if ([_searchBar.text isEqualToString:@""]) {
        if (_searchBar.tag == 2) {
            return;
        }
        _searchBar.tag = 2;
        
        CGRect newFrame = _searchBar.frame;
        newFrame.size.width = searchBarMinWidth;
        [UIView animateWithDuration:0.50
                         animations:^{
                             _searchBar.frame = newFrame;
                             _ratingLabel.alpha = 1.0;
                             _stars.alpha = 1.0;
                         }];
    }
}

- (void) openSearchBar {
    if (_searchBar.tag == 1) {
        return;
    }
    _searchBar.tag = 1;
    
    CGRect newFrame = _searchBar.frame;
    newFrame.size.width = searchBarMaxWidth;
    
    [UIView animateWithDuration:0.25
                     animations:^{
                         _searchBar.frame = newFrame;
                         _ratingLabel.alpha = 0.0;
                         _stars.alpha = 0.0;
                     }];
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
    return YES;
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self closeSearchBar];
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return  18.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[_sortedChannels allKeys] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *sections = [[_sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *sectionKey = [sections objectAtIndex:section];
    return [[[_sortedChannels objectForKey:sectionKey] allKeys] count];
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    NSArray *sections = [[_sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return [sections objectAtIndex:section];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    UIColor *backgroundColor = [UIColor colorWithRed:28/255.0f green:28/255.0f blue:28/255.0f alpha:1.0f];
    UIColor *textColor = [UIColor colorWithRed:193/255.0f green:193/255.0f blue:193/255.0f alpha:1.0f];
    UIColor *tintColor = [UIColor colorWithRed:30/255.0f green:147/255.0f blue:212/255.0f alpha:1.0f];
    
    cell.indentationLevel = 1;
    cell.indentationWidth = 2;
    
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    cell.backgroundColor = backgroundColor;
    [cell.textLabel setTextColor: textColor];
    [cell.detailTextLabel setTextColor:textColor];
    [cell setTintColor:tintColor];
    
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    UIColor *textColor = [UIColor colorWithRed:193/255.0f green:193/255.0f blue:193/255.0f alpha:1.0f];
    UIColor *red = [UIColor colorWithRed:217/255.0f green:50/255.0f blue:5/255.0f alpha:1.0f];
    UIColor *backgroundColor = [UIColor colorWithRed:28/255.0f green:28/255.0f blue:28/255.0f alpha:1.0f];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SomeId"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SomeId"];
        UILabel *label = [[UILabel alloc] init];
        label.text = @"";
        label.textColor = textColor;
        label.font = [UIFont fontWithName:@"Helvetica" size:12];
        label.numberOfLines = 2;
        label.backgroundColor = backgroundColor;
        [label setTag:1];
        label.textAlignment = NSTextAlignmentCenter;
        [label setFrame:CGRectMake([[UIScreen mainScreen] bounds].size.width - 40, 7, 40, 30)];
        [cell.contentView addSubview:label];
    }
    
    //cell data
    NSArray *sections = [[_sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *sectionKey = [sections objectAtIndex:indexPath.section];
    NSMutableDictionary *sectionData = [_sortedChannels objectForKey:sectionKey];
    NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
    id sectionChannelKey = [sectionChannels objectAtIndex:indexPath.row];
    id chId = [[sectionData objectForKey:sectionChannelKey] stringValue];
    
    NSDictionary *channel = _channels[chId];
    NSDictionary *guideItem = [_guide objectForKey:chId];

    NSString *timeLeft= @"";
    bool showIsEndingSoon = NO;
    
    if (guideItem) {
        cell.textLabel.text = [guideItem objectForKey:@"title"];
        if ([guideItem objectForKey:@"upNext"]) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"next: %@",
                                         [guideItem objectForKey:@"upNext"]];
        } else {
            cell.detailTextLabel.text = @"";
        }
        
        NSDictionary *duration = [Guide getDurationForChannel:guideItem];
        if ((int)duration[@"showIsEndingSoon"] == 1) {
            showIsEndingSoon = YES;
        }
        
        timeLeft = duration[@"timeLeft"];
        
    } else {
        cell.textLabel.text = @"Not Available";
        cell.detailTextLabel.text = @" ";
        showIsEndingSoon = NO;
    }
    
    UILabel *l2 = (UILabel *)[cell viewWithTag:1];
    
    if (isEditing) {
        [l2 setHidden:YES];
        
        cell.textLabel.text = channel[@"chName"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", channel[@"chNum"], channel[@"chCall"]];
        
        if ([_blockedChannels containsObject:chId]) {
            cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage new]];
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    } else {
        cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage new]];
        
        [l2 setHidden:NO];
        l2.text =  [NSString stringWithFormat:@"%04d\n%@", [[channel objectForKey:@"chNum"] intValue], timeLeft];
        //l2.text =  [NSString stringWithFormat:@"%@\n%@", [channel objectForKey:@"chCall"] , timeLeft];
        if (showIsEndingSoon){
            l2.textColor = red;
        } else {
            l2.textColor = textColor;
        }
    }

    
    //channel image
    UIImage *image = [UIImage new];
    NSString *cacheDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *imagePath =[cacheDirectory stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.png", [channel objectForKey:@"chLogoId"]]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        image = [UIImage imageWithContentsOfFile:imagePath];
    }
    cell.imageView.image = image;
    
    [cell setNeedsLayout];
    
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *sections = [[_sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *sectionKey = [sections objectAtIndex:indexPath.section];
    NSMutableDictionary *sectionData = [_sortedChannels objectForKey:sectionKey];
    NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
    id sectionChannelKey = [sectionChannels objectAtIndex:indexPath.row];
    id chId = [[sectionData objectForKey:sectionChannelKey] stringValue];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (isEditing) {
        
        UITableViewCell *cell =[tableView cellForRowAtIndexPath:indexPath];
        if ([_blockedChannels containsObject:chId]) {
            [_blockedChannels removeObject:chId];
            cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage new]];
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            [_blockedChannels addObject:chId];
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        [_mainTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
    } else {
        
        if ([[_currentClient allKeys] count] == 0) {
            [self chooseClient:nil];
        }
        
        [Commands changeChannel:_channels[chId][@"chNum"] device:_currentClient];
    }
    
}



- (void) promptForZipCode {
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
             [self promptForZipCode];
             return;
         }
         [Channels getLocationsForZipCode:zip];
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

- (void) messageUpdatedLocations:(NSNotification *)notification {
    NSMutableDictionary *locations = [notification object];
    [self promptForLocation:locations];
}
- (void) promptForLocation:(NSMutableDictionary *) locations {
    
    NSArray *keys = [locations allKeys];
    
    if ([keys count] == 0 ) {
        //somethings wrong, ask again for zip
        [self promptForZipCode];
        return;
    } else {
        
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
                 [Channels populateChannels:item];
                 return;
             }];
            [view addAction:action];
        }
        
        
        UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
            [view dismissViewControllerAnimated:YES completion:nil];
            [self promptForZipCode];
        }];
        
        [view addAction:cancel];
        [self presentViewController:view animated:YES completion:nil];
    }
}

- (void) messageDownloadChannelLogos:(NSNotification *)notification {
    _channels = [notification object];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.labelText = @"Downloading channel logos";
        hud.detailsLabelText = @"for first use";
        [Channels downloadChannelImages:_channels];
    });
    
}


- (void) messageUpdatedChannels:(NSNotification *)notification {
    _channels = [notification object];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_mainTableView reloadData];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"default"];
        [self refreshGuide:nil];
    });
    
}

- (void) messageUpdatedChannelsProgress:(NSNotification *)notification {
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.progress = [[notification object] floatValue];
    
}

- (IBAction) chooseClient:(id)sender {
    
    if ([[_clients[self.ssid] allKeys] count] == 0) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.labelText = @"Scanning wifi network for devices...";
        [Clients searchWifiForDevices];
    } else {
        [self showClientPicker:nil];
    }
    
}

- (void) messageUpdatedClients:(NSNotification *)notification {
    _clients = notification.object;
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [self chooseClient:nil];
}

- (void) messageUpdatedClientsProgress:(NSNotification *)notification {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = [[notification object] floatValue];
    }];
}

- (IBAction)showClientPicker:(id)sender {
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    UIAlertController *view = [UIAlertController
                               alertControllerWithTitle:@""
                               message:@"Choose a device"
                               preferredStyle:UIAlertControllerStyleActionSheet];
    
    
    
    
    for (NSString *key in [_clients objectForKey:self.ssid] ) {
        
        NSLog(@"%@", key);
        NSDictionary *client = _clients[self.ssid][key];
        
        //id item = [_clients[self.ssid] objectAtIndex: i];
        UIAlertAction *action = [UIAlertAction actionWithTitle: client[@"name"] style: UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            
            [Clients setCurrentClientId:client[@"id"]];
            _currentClient = [Clients getClient];
            [self displayClient];
            
            [view dismissViewControllerAnimated:YES completion:nil];
        }];
        [view addAction:action];
    }
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [view dismissViewControllerAnimated:YES completion:nil];
        return;
    }];
    [view addAction:cancel];
    
    UIAlertAction *refresh = [UIAlertAction actionWithTitle:@"Rescan Network" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        [view dismissViewControllerAnimated:YES completion:nil];
        [_clients removeAllObjects];
        [self chooseClient:nil];
        return;
    }];
    [view addAction:refresh];
    
    UIViewController *vc = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [vc presentViewController:view animated:YES completion:nil];
}

- (void) displayClient {
    if (_currentClient) {
        _navTitle.text = [_currentClient[@"name"] capitalizedString];
        [self refreshNowPlaying:nil scrollToPlayingChanel:YES];
    } else {
        _navTitle.text = @"";
        [self clearNowPlaying];
    }
}

- (void) refreshNowPlaying:(id)sender scrollToPlayingChanel:(BOOL)scroll {
    if (_currentClient) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *channelNum = [Commands getChannelOnClient:_currentClient];
            NSString *channelId = [Channels getChannelIdForChannelNumber:channelNum channels:_allChannels];
            
            if ([channelId isEqualToString:@""]) {
                [self clearNowPlaying];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self setNowPlaying:channelId chNum:channelNum];
                    if (scroll) {
                        [self scrollToChannel:channelNum];
                    }
                });
            }
        });
    }
}

-(void) setNowPlaying:(NSString *)chId chNum:(NSString *)chNum {

    NSDictionary *channel = [_allChannels objectForKey:chId];
    NSLog(@"Querying Now Playing");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSDictionary *guide = [Guide getNowPlayingForChannel:channel];
        if ([[guide allKeys] count] == 0) {
            return;
        }
        NSDictionary *guideData = [guide objectForKey:[guide allKeys][0]];
        NSDictionary *duration = [Guide getDurationForChannel:guideData];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNowPlayingForChannel:channel guideData:guideData duration:duration];
        });
    });

}

-(void) setNowPlayingForChannel:(id)channel guideData:(id)guideData duration:(NSDictionary *)duration {
    
    _seekBar.value = [duration[@"percentage"] doubleValue];

    if ([_currentProgramId isEqualToString:guideData[@"programID"]]) {
        return;
    }
    
    _currentProgramId = guideData[@"programID"];
    _boxTitle.text = [NSString stringWithFormat:@"%@",
                      guideData[@"title"]];
    
    if (guideData[@"hd"] && [[guideData[@"hd"] stringValue] isEqualToString:@"1"] ) {
        [_hdLabel setHidden:NO];
    } else {
        [_hdLabel setHidden:YES];
    }
    
    _navTitle.text = [_currentClient[@"name"] capitalizedString];
    _navSubTitle.text = [NSString stringWithFormat:@"%@ %@", channel[@"chNum"], channel[@"chName"]];

    [self setBoxCoverForChannel:guideData[@"boxcover"]];
    [self setDescriptionForProgramId:guideData[@"programID"]];
}

-(void) setStarRating:(double) rating {
    rating = (rating*2.0) / 100.0;
    
    UIFont *font = [UIFont fontWithName:@"Helvetica-Bold" size:16];
    NSDictionary *userAttributes = @{NSFontAttributeName: font};
    const CGSize textSize = [@"★★★★★" sizeWithAttributes: userAttributes];
    _stars.frame = CGRectMake(
                              [[UIScreen mainScreen] bounds].size.width - textSize.width - 10 ,
                              223,
                              textSize.width * rating,
                              29);
}

-(void) scrollToChannel:(NSString *)scrollToChNum {
    int row = -1;
    int section = -1;

    int sectionCounter = 0;
    int rowCounter = 0;
    
    NSArray *sections = [[_sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *sectionKey in sections) {
        NSMutableDictionary *sectionData = [_sortedChannels objectForKey:sectionKey];
        NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
        for (id sectionChannelKey in sectionChannels) {
            NSString *chId = [sectionData[sectionChannelKey] stringValue];
            NSString *chNum = [_channels[chId][@"chNum"] stringValue];
            if ([chNum isEqualToString:scrollToChNum]) {
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
        [_mainTableView scrollToRowAtIndexPath:indexPath
                             atScrollPosition:UITableViewScrollPositionTop
                                     animated:YES];
    }
}

-(void) setDescriptionForProgramId:(NSString *)programID {
    
    NSURL* programURL = [NSURL URLWithString:
                         [NSString stringWithFormat:@"https://www.directv.com/json/program/flip/%@", programID]];
    
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
                     _boxDescription.text = show[@"description"];
                 }
                 NSString *title = _boxTitle.text;
                 
                 if (show[@"title"] && show[@"episodeTitle"]) {
                     title = [NSString stringWithFormat:@"%@ - %@",
                              _boxTitle.text, show[@"episodeTitle"]];
                 }
                 if (show[@"title"] && show[@"releaseYear"]) {
                     title = [NSString stringWithFormat:@"%@ (%@)",
                              _boxTitle.text, show[@"releaseYear"]];
                 }
                 
                 if (show[@"rating"]) {
                     _ratingLabel.text = show[@"rating"];
                     [_ratingLabel setHidden:NO];
                 } else {
                     [_ratingLabel setHidden:YES];
                 }
                 
                 if (show[@"starRatingNum"]) {
                     [self setStarRating:[show[@"starRatingNum"] doubleValue]];
                     [_stars setHidden:NO];
                 } else {
                     [_stars setHidden:YES];
                 }
                 
                 _boxTitle.text = title;
                 
             }
         }
     }];
}

-(void) setBoxCoverForChannel:(NSString *)path {
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
             [_boxCover setImage:image];
         }
     }];
}



-(void) clearNowPlaying {
    _boxCover.image = [UIImage new];
    _boxTitle.text = @"";
    _boxDescription.text = @"";
}

- (IBAction) refreshGuide:(id)sender {

    if (!guideIsRefreshing) {
        guideIsRefreshing = YES;
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        CGRect frm = _overlayProgress.frame;
        frm.size.width = 0;
        _overlayProgress.frame = frm;
        _overlayProgress.hidden = NO;
        [self toggleOverlay:@"show"];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"h:mm a"];
        NSDate *dt = [Guide getHalfHourIncrement:[NSDate date]];
        _overlayLabel.text = [NSString stringWithFormat:@"Now Refreshing guide for %@",
                              [formatter stringFromDate:dt]];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [Guide refreshGuide:_channels sorted:_sortedChannels forTime:[NSDate date]];
        });
    }
}

- (void) messageNextGuideRefreshTime:(NSNotification *)notification {
    _nextRefresh = [notification object];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"h:mm a"];
        _overlayLabel.text = [NSString stringWithFormat:@"Next Refresh at %@",
                              [formatter stringFromDate:_nextRefresh]];
        [self toggleOverlay:@"hide"];
    }];
}

- (void) messageUpdatedGuide:(NSNotification *)notification {
    _guide = notification.object;
    guideIsRefreshing = NO;
    
    _channels = [Channels addChannelCategoriesFromGuide:_guide channels:_channels];
    _sortedChannels = [Channels sortChannels:_channels sortBy:@"default"];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        _overlayProgress.hidden = YES;
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [_mainTableView reloadData];
    }];
}

- (void) toggleOverlay:(NSString *)action {
    if ([action isEqualToString:@"show"]) {
        [UIView animateWithDuration:0.5
                         animations:^{
                             _overlay.alpha = 0.8;
                         }];
    } else {
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 3);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            [UIView animateWithDuration:0.5
                             animations:^{
                                 _overlay.alpha = 0.0;
                             }];
        });
    }
}

- (void) messageUpdatedGuideProgress:(NSNotification *)notification {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        float percent = [[notification object] floatValue];
        CGRect frm = _overlayProgress.frame;
        frm.size.width = [[UIScreen mainScreen] bounds].size.width * percent;
        
        [UIView animateWithDuration:0.25
                         animations:^{
                             _overlayProgress.frame = frm;
                         }];
        
    }];
}

- (void) messageUpdatedGuidePartial:(NSNotification *)notification {
    _guide = notification.object;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_mainTableView reloadData];
    }];
}

- (void) messageChannelChanged:(NSNotification *)notification {
    isPlaying = YES;
    [self refreshNowPlaying:nil scrollToPlayingChanel:NO];
}

- (IBAction)sortChannels:(id)sender {
    
    UIAlertController *view = [UIAlertController
                               alertControllerWithTitle:nil
                               message:@"Sort By"
                               preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* name = [UIAlertAction actionWithTitle:@"Channel Name" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        //save sort
        [[NSUserDefaults standardUserDefaults] setObject:@"name" forKey:@"sort"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"name"];
        [_mainTableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
        [_mainTableView reloadData];
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    [view addAction:name];
    
    UIAlertAction* number = [UIAlertAction actionWithTitle:@"Channel Number" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        //save sort
        [[NSUserDefaults standardUserDefaults] setObject:@"number" forKey:@"sort"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"number"];
        [_mainTableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
        [_mainTableView reloadData];
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    [view addAction:number];
    
    UIAlertAction* category = [UIAlertAction actionWithTitle:@"Show Type" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        //save sort
        [[NSUserDefaults standardUserDefaults] setObject:@"category" forKey:@"sort"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"category"];
        [_mainTableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
        [_mainTableView reloadData];
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    [view addAction:category];
    
    UIAlertAction* channelGroup = [UIAlertAction actionWithTitle:@"Channel Type" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        //save sort
        [[NSUserDefaults standardUserDefaults] setObject:@"channelGroup" forKey:@"sort"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"channelGroup"];
        [_mainTableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
        [_mainTableView reloadData];
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    [view addAction:channelGroup];
    
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [view addAction:cancel];
    [self presentViewController:view animated:YES completion:nil];
    
}

- (IBAction)toggleEditMode:(id)sender {
    if (isEditing) {
        //Going back to regular mode
        [Channels saveBlockedChannels:_blockedChannels];
        isEditing = NO;
        _rightButton.title = @"Edit";
        _channels = [Channels load:NO];
        _blockedChannels = [[NSMutableArray alloc] init];
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"default"];
        //NSIndexPath *indexpath = (NSIndexPath*)[[_mainTableView indexPathsForVisibleRows] objectAtIndex:0];
        
    } else {
        //Going into edit mode
        isEditing = YES;
        _rightButton.title = @"Done";
        _channels = [Channels load:YES];
        _blockedChannels = [Channels loadBlockedChannels:_channels];
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"default"];
    }

    [_mainTableView reloadData];
}

- (IBAction)showNumberPad:(id)sender {
    
    if ([[_currentClient allKeys] count] == 0) {
        return;
    }
   
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Number Pad"
                                                                   message:@"Please enter a channel"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* accept =
    [UIAlertAction actionWithTitle:@"Change Channel"
                             style:UIAlertActionStyleDefault
                           handler:^(UIAlertAction * action){
                               
                               UITextField *txtField = alert.textFields.firstObject;
                               NSString *channel = txtField.text;
                               NSLog(@"Change to: %@", channel);
                               
                               if ([channel length] > 4) {
                                   [self showNumberPad:nil];
                                   return;
                               }
                               [Commands changeChannel:channel device:_currentClient];
                               [self dismissViewControllerAnimated:YES completion:nil];
                               
                           }];
    
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = @"";
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    UIAlertAction* cancel =
    [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:
     ^(UIAlertAction * action) {
         [self dismissViewControllerAnimated:YES completion:nil];
     }];
    
    [alert addAction:accept];
    [alert addAction:cancel];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)playpause:(id)sender {
    if (isPlaying) {
        if ([Commands sendCommand:@"pause" client:_currentClient]) {
            _playButton.image = [UIImage imageNamed:@"images.bundle/play"];
            isPlaying = NO;
        }
    } else {
        if ([Commands sendCommand:@"play" client:_currentClient]) {
            _playButton.image = [UIImage imageNamed:@"images.bundle/pause"];
            isPlaying = YES;
        }
    }
}

- (IBAction)rewind:(id)sender {
    if ([Commands sendCommand:@"rew" client:_currentClient]) {
        _playButton.image = [UIImage imageNamed:@"images.bundle/play"];
        isPlaying = NO;
    }
}

- (IBAction)forward:(id)sender {
    if ([Commands sendCommand:@"ffwd" client:_currentClient]) {
        _playButton.image = [UIImage imageNamed:@"images.bundle/play"];
        isPlaying = NO;
    }
}


- (IBAction)stub:(id)sender {
    
}
@end
