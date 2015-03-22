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

    Channels *ch = [[Channels alloc] init];
    Guide *gd = [[Guide alloc] init];
    Commands *co = [[Commands alloc] init];
    Clients *cl = [[Clients alloc]  init];
    
    classChannels = ch;
    classGuide = gd;
    classCommands = co;
    classClients = cl;
    
    _nextRefresh = [NSDate date];
    _currentProgramId = @"";

    _channels = [classChannels loadChannels];
    _guide = [[NSMutableDictionary alloc] init];
    _sortedChannels = [[NSMutableDictionary alloc] init];
    _clients = [classClients loadClients];
    _currentClient = [[NSMutableDictionary alloc] init];
    
    _timer = [[NSTimer alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedClients:)
                                                 name:@"messageUpdatedClients" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedClientsProgress:)
                                                 name:@"messageUpdatedClientsProgress" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedChannels:)
                                                 name:@"messageUpdatedChannels" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedChannelsProgress:)
                                                 name:@"messageUpdatedChannelsProgress" object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageNextGuideRefreshTime:)
                                                 name:@"messageNextGuideRefreshTime" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuide:)
                                                 name:@"messageUpdatedGuide" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuideProgress:)
                                                 name:@"messageUpdatedGuideProgress" object:nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedLocations:)
                                                 name:@"messageUpdatedLocations" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedNowPlaying:)
                                                 name:@"messageUpdatedNowPlaying" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageChannelChanged:)
                                                 name:@"messageChannelChanged" object:nil];
    
    [self createMainView];
    
    if ([_clients count] > 0) {
        [self selectClient:(int)0];
    }
    
    if ([[_channels allKeys] count] == 0) {
        dispatch_after(0, dispatch_get_main_queue(), ^{
            [self promptForZipCode];
        });
    } else {
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"number"];
        [self refreshGuide];
    }
    
    
    

    _timer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                              target:self
                                            selector:@selector(onTimerFire:)
                                            userInfo:nil
                                             repeats:YES];
    [_timer fire];
}

-(void) onTimerFire:(id)sender {
    NSLog(@"fired");
    [self refreshNowPlaying:nil];
    
    if( [[NSDate date] timeIntervalSinceDate:_nextRefresh] >= 0 ) {
        [self refreshGuide];
    }
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
    
    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(chooseClient:)];
    _navItem.rightBarButtonItem = rightButton;
    
    [_navbar pushNavigationItem:_navItem animated:false];
    [self.view addSubview:_navbar];
}

- (void) createTopSection {

    UIColor *textColor = [UIColor colorWithRed:193/255.0f green:193/255.0f blue:193/255.0f alpha:1.0f];
    UIColor *boxBackgroundColor = [UIColor colorWithRed:28/255.0f green:28/255.0f blue:28/255.0f alpha:1.0f];
    UIColor *tint = [UIColor colorWithRed:30/255.0f green:147/255.0f blue:212/255.0f alpha:1.0f];
    
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(5, 70, 120, 180)];
    [v setBackgroundColor:boxBackgroundColor];
    
    UITapGestureRecognizer *singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(dismissKeyboard:)];
    [v addGestureRecognizer:singleFingerTap];
    
    _boxCover = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 120, 180)];
    [_boxCover setImage:[UIImage new]];
    [v addSubview:_boxCover];
    [self.view addSubview:v];
    
    
    double xOffset = 140;
    
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
                                     style:UIBarButtonItemStylePlain target:self action:@selector(stub:)];
    
    _playButton = [[UIBarButtonItem alloc]
                   initWithImage:[UIImage imageNamed:@"images.bundle/pause"]
                   style:UIBarButtonItemStylePlain target:self action:@selector(playPause:) ];
    
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
    [_seekBar setMaximumTrackTintColor:textColor];
    [_seekBar setMinimumTrackTintColor:tint];
    
    _seekBar.tintColor = textColor;
    _seekBar.thumbTintColor = textColor;
    
    [_seekBar setThumbImage:[UIImage imageNamed:@"images.bundle/scrubber"] forState:UIControlStateNormal];
    [_seekBar setThumbImage:[UIImage imageNamed:@"images.bundle/scrubber"] forState:UIControlStateSelected];
    [_seekBar setThumbImage:[UIImage imageNamed:@"images.bundle/scrubber"] forState:UIControlStateHighlighted];
    
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
    xOffset = xOffset - 10;
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(xOffset, 215, [[UIScreen mainScreen] bounds].size.width - xOffset, 44)];
    
    CGRect newFrame = _searchBar.frame;
    newFrame.size.width -= 200;
    _searchBar.frame = newFrame;
    
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
    
    UIView *overlay = [[UIView alloc] init];
    _overlayProgress = [[UIView alloc] init];
    

    
    overlay.frame = CGRectMake(0, [[UIScreen mainScreen] bounds].size.height - (toolbarHeight + overlayHeight),
                               [[UIScreen mainScreen] bounds].size.width, overlayHeight);
    
    _overlayProgress.frame = CGRectMake(0,
                                        [[UIScreen mainScreen] bounds].size.height -
                                        (toolbarHeight + progressHeight) ,
                                        0, progressHeight);
    
    _overlayProgress.opaque = YES;
    _overlayProgress.alpha = .6;
    _overlayProgress.backgroundColor = [UIColor redColor];
    
    overlay.opaque = YES;
    overlay.alpha = .6;
    overlay.backgroundColor = [UIColor blackColor];
    
     _overlayLabel = [[UILabel alloc] init];
    _overlayLabel.textColor = textColor;
    _overlayLabel.frame = overlay.frame;
    _overlayLabel.text = @"";
    _overlayLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
    _overlayLabel.textAlignment = NSTextAlignmentCenter;

    [self.view addSubview:overlay];
    [self.view addSubview:_overlayProgress];
    [self.view addSubview:_overlayLabel];
    
    _toolBar = [[UIToolbar alloc] init];
    _toolBar.clipsToBounds = YES;
    _toolBar.frame = CGRectMake(0, [[UIScreen mainScreen] bounds].size.height - toolbarHeight, [[UIScreen mainScreen] bounds].size.width, toolbarHeight);
    [_toolBar setBackgroundImage:[UIImage new] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    _toolBar.tintColor = textColor;
    
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil ];
    

    UIBarButtonItem *guideBack = [[UIBarButtonItem alloc]
                                  initWithImage:[UIImage imageNamed:@"images.bundle/left.png"]
                                  style:UIBarButtonItemStylePlain target:self action:@selector(stub:) ];
    
    UIBarButtonItem *guideForward = [[UIBarButtonItem alloc]
                                     initWithImage:[UIImage imageNamed:@"images.bundle/right"]
                                     style:UIBarButtonItemStylePlain target:self action:@selector(stub:) ];
    
    UIBarButtonItem *numberPad = [[UIBarButtonItem alloc]
                                      initWithImage:[UIImage imageNamed:@"images.bundle/numberpad.png"]
                                      style:UIBarButtonItemStylePlain target:self action:@selector(stub:) ];
    
    UIBarButtonItem *filter = [[UIBarButtonItem alloc]
                                  initWithImage:[UIImage imageNamed:@"images.bundle/filter.png"]
                                  style:UIBarButtonItemStylePlain target:self action:@selector(stub:) ];
    
    UIBarButtonItem *commands = [[UIBarButtonItem alloc]
                               initWithImage:[UIImage imageNamed:@"images.bundle/commands.png"]
                               style:UIBarButtonItemStylePlain target:self action:@selector(stub:) ];
    
    UIBarButtonItem *sort = [[UIBarButtonItem alloc]
                                 initWithImage:[UIImage imageNamed:@"images.bundle/sort.png"]
                             style:UIBarButtonItemStylePlain target:self action:@selector(sortChannels:) ];
    
    
    NSArray *buttons = [NSArray arrayWithObjects:  commands, flex , sort, flex, filter, flex, numberPad, flex, guideBack, flex, guideForward, nil];
    [_toolBar setItems:buttons animated:NO];
    
    [self.view addSubview:_toolBar];

}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    // [self doFilter];
    
    if (_searchBar.tag == 1) {
        return;
    }
    _searchBar.tag = 1;
    
    CGRect newFrame = _searchBar.frame;
    newFrame.size.width += 200;
    
    [UIView animateWithDuration:0.25
                     animations:^{
                         _searchBar.frame = newFrame;
                     }];
   
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    
    [searchBar resignFirstResponder];
    
    if ([searchBar.text isEqualToString:@""]) {
        NSLog(@"Clear");
        if (_searchBar.tag == 2) {
            return;
        }
        _searchBar.tag = 2;
        
        CGRect newFrame = _searchBar.frame;
        newFrame.size.width -= 200;
        [UIView animateWithDuration:0.50
                         animations:^{
                             _searchBar.frame = newFrame;
                         }];
    }

}
- (void)searchBarTextDoneEditing:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([searchText isEqualToString:@""]) {
    } else {
        //[self doFilter];
    }
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
    return YES;
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [_searchBar resignFirstResponder];
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
    

    cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage new]];
    
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
        cell.detailTextLabel.text = @"";
        showIsEndingSoon = NO;
    }
    
    
    UILabel *l2 = (UILabel *)[cell viewWithTag:1];
    l2.text =  [NSString stringWithFormat:@"%04d\n%@", [[channel objectForKey:@"chNum"] intValue], timeLeft];
    if (showIsEndingSoon){
        l2.textColor = red;
    } else {
        l2.textColor = textColor;
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
    if ([[_currentClient allKeys] count] == 0) {
        [self chooseClient:nil];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSArray *sections = [[_sortedChannels allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *sectionKey = [sections objectAtIndex:indexPath.section];
    NSMutableDictionary *sectionData = [_sortedChannels objectForKey:sectionKey];
    NSArray *sectionChannels = [[sectionData allKeys] sortedArrayUsingSelector: @selector(compare:)];
    id sectionChannelKey = [sectionChannels objectAtIndex:indexPath.row];
    id chId = [[sectionData objectForKey:sectionChannelKey] stringValue];
    
    NSDictionary *channel = _channels[chId];
    NSDictionary *props = @{@"chNum":channel[@"chNum"], @"device":_currentClient};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageChangeChannel" object:props];
    
    
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
         
         [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedZipCodes" object:zip];
         
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
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageSelectedLocation" object:item];
                 [view dismissViewControllerAnimated:YES completion:nil];
                 [self refreshChannels];
                 
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

- (void) refreshChannels {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.labelText = @"Downloading channel logos";
    hud.detailsLabelText = @"for first use";
}

- (void) messageUpdatedChannels:(NSNotification *)notification {
    _channels = [notification object];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_mainTableView reloadData];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"number"];
        [self refreshGuide];
    });

}

- (void) messageUpdatedChannelsProgress:(NSNotification *)notification {
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.progress = [[notification object] floatValue];
    
}

- (IBAction) chooseClient:(id)sender {
    
    if ([_clients count] == 0) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.labelText = @"Scanning wifi network for devices...";
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageFindClients" object:nil];
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
    
    for (NSUInteger i = 0; i < [_clients count]; i++) {
        id item = [_clients objectAtIndex: i];
        UIAlertAction *action = [UIAlertAction actionWithTitle: item[@"name"] style: UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            
            [self selectClient:(int)i];
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

- (void) selectClient:(int)index {
    if ([_clients count] > 0) {
        _currentClient = [_clients objectAtIndex:index];
        _navItem.title = _currentClient[@"name"];
    } else {
        [_currentClient removeAllObjects];
        _navItem.title = @"";
    }
    [self refreshNowPlaying:nil];
}

- (void) refreshNowPlaying:(id)sender {
    if ([_clients count] > 0 && [[_currentClient allKeys] count] > 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageRefreshNowPlaying" object:_currentClient];
    }
}

-(void) setNowPlaying:(NSString *)chId {
    NSDictionary *playing = [_guide objectForKey:chId];
    NSDictionary *channel = [_channels objectForKey:chId];
    
    if (!playing) {
        [self clearNowPlaying];
        return;
    }
    

    NSDictionary *duration = [Guide getDurationForChannel:playing];
    _seekBar.value = [duration[@"percentage"] doubleValue];
    
    if ([_currentProgramId isEqualToString:playing[@"programID"]]) {
        return;
    }
    _currentProgramId = playing[@"programID"];
    
    _boxTitle.text = [channel[@"chNum"] stringValue];
    
    [self setBoxCoverForChannel:playing[@"boxcover"]];
    [self setDescriptionForProgramId:playing[@"programID"]];
    
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
             NSDictionary *show = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
             if (show[@"programDetail"]) {
                 
                 if (show[@"programDetail"][@"description"]) {
                     _boxDescription.text = show[@"programDetail"][@"description"];
                 }
                 NSString *title = _boxTitle.text;
                 
                 if (show[@"programDetail"][@"title"]) {
                     title = [NSString stringWithFormat:@"%@: %@ - %@",
                              _boxTitle.text, show[@"programDetail"][@"title"], show[@"programDetail"][@"episodeTitle"]];
                 }
                 if (show[@"programDetail"][@"title"] && show[@"programDetail"][@"episodeTitle"]) {
                     title = [NSString stringWithFormat:@"%@: %@ - %@",
                              _boxTitle.text, show[@"programDetail"][@"title"], show[@"programDetail"][@"episodeTitle"]];
                 }
                 if (show[@"programDetail"][@"title"] && show[@"programDetail"][@"releaseYear"]) {
                     title = [NSString stringWithFormat:@"%@: %@ (%@)",
                             _boxTitle.text, show[@"programDetail"][@"title"], show[@"programDetail"][@"releaseYear"]];
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

- (void) messageUpdatedNowPlaying:(NSNotification *)notification {
    NSString *chNum = [notification.object stringValue];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *channelId = [classChannels getChannelIdForChannelNumber:chNum channels:_channels];
        dispatch_after(0, dispatch_get_main_queue(), ^{
            if ([channelId isEqualToString:@""]) {
                [self clearNowPlaying];
            } else {
                [self setNowPlaying:channelId];
            }
        });
    });
}


- (void) refreshGuide {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    CGRect frm = _overlayProgress.frame;
    frm.size.width = 0;
    _overlayProgress.frame = frm;
    _overlayProgress.hidden = NO;
    _overlayLabel.text = @"Refreshing guide data...";
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageRefreshGuide" object:_channels];

}

- (void) messageNextGuideRefreshTime:(NSNotification *)notification {
    _nextRefresh = [notification object];
}

- (void) messageUpdatedGuide:(NSNotification *)notification {
    _guide = notification.object;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        _overlayProgress.hidden = YES;
        _overlayLabel.text = @"Guide updated.";
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [_mainTableView reloadData];
        [self refreshNowPlaying:nil];
    }];
}

- (void) messageChannelChanged:(NSNotification *)notification {
    [self refreshNowPlaying:nil];
}

- (void) messageUpdatedGuideProgress:(NSNotification *)notification {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        float percent = [[notification object] floatValue];
        CGRect frm = _overlayProgress.frame;
        frm.size.width = [[UIScreen mainScreen] bounds].size.width * percent;
        _overlayProgress.frame = frm;
    }];
}



- (IBAction)stub:(id)sender {
    
}
- (IBAction)sortChannels:(id)sender {

    UIAlertController *view = [UIAlertController
                               alertControllerWithTitle:nil
                               message:@"Sort Channels By"
                               preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* name = [UIAlertAction actionWithTitle:@"Name" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"name"];
        [_mainTableView reloadData];
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    [view addAction:name];
    
    UIAlertAction* number = [UIAlertAction actionWithTitle:@"Number" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        _sortedChannels = [Channels sortChannels:_channels sortBy:@"number"];
        [_mainTableView reloadData];
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    [view addAction:number];
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [view dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [view addAction:cancel];
    [self presentViewController:view animated:YES completion:nil];
    
}
- (IBAction)forward:(id)sender {
    
}
- (IBAction)playPause:(id)sender {
    
}
@end
