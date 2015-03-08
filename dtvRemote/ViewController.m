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

    _channels = [classChannels loadChannels];
    _guide = [[NSMutableDictionary alloc] init];
    _clients = [classClients loadClients];
    _currentClient = [[NSMutableDictionary alloc] init];
    

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedClients:)
                                                 name:@"messageUpdatedClients" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedClientsProgress:)
                                                 name:@"messageUpdatedClientsProgress" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedLocations:)
                                                 name:@"messageUpdatedLocations" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedChannels:)
                                                 name:@"messageUpdatedChannels" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedChannelsProgress:)
                                                 name:@"messageUpdatedChannelsProgress" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuide:)
                                                 name:@"messageUpdatedGuide" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuideProgress:)
                                                 name:@"messageUpdatedGuideProgress" object:nil];
    
    [self createMainView];
    
    if ([[_channels allKeys] count] == 0) {
        dispatch_after(0, dispatch_get_main_queue(), ^{
            [self promptForZipCode];
        });
    } else {
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
    
    
    /*
    _navTitle = [[UILabel alloc] init];
    _navTitle.translatesAutoresizingMaskIntoConstraints = YES;
    _navTitle.text = @"Living Room";
    _navTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:17];
    [_navTitle setTextColor:textColor];
    _navTitle.tintColor = navTint;
    _navTitle.textAlignment = NSTextAlignmentCenter;
    _navTitle.frame = CGRectMake(0, 28, [[UIScreen mainScreen] bounds].size.width, 20);
    
    _navSubTitle = [[UILabel alloc] init];
    _navSubTitle.translatesAutoresizingMaskIntoConstraints = YES;
    _navSubTitle.text = @"202 - CNN";
    _navSubTitle.font = [UIFont fontWithName:@"Helvetica" size:14];
    [_navSubTitle setTextColor: textColor];
    _navSubTitle.textAlignment = NSTextAlignmentCenter;
    _navSubTitle.frame = CGRectMake(0, 44, [[UIScreen mainScreen] bounds].size.width, 20);
    [_navSubTitle setFont:[UIFont systemFontOfSize:14]];
    */
    
    NSDictionary* barButtonItemAttributes =  @{NSFontAttributeName: [UIFont fontWithName:@"Helvetica" size:14.0f],
                                               NSForegroundColorAttributeName: navTint};
    
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateNormal];
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateHighlighted];
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateSelected];
    [[UIBarButtonItem appearance] setTitleTextAttributes: barButtonItemAttributes forState:UIControlStateDisabled];
    

    
    _navItem = [UINavigationItem alloc];
    _navItem.title = @"";
    
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:@"Room" style:UIBarButtonItemStylePlain target:self action:@selector(findClients:)];
    _navItem.leftBarButtonItem = leftButton;
    
    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(showDevicePicker:)];
    _navItem.rightBarButtonItem = rightButton;
    
    [_navbar pushNavigationItem:_navItem animated:false];
    [self.view addSubview:_navbar];
}

- (void) createTopSection {

    UIColor *textColor = [UIColor colorWithRed:193/255.0f green:193/255.0f blue:193/255.0f alpha:1.0f];
    UIColor *boxBackgroundColor = [UIColor colorWithRed:28/255.0f green:28/255.0f blue:28/255.0f alpha:1.0f];
    UIColor *tint = [UIColor colorWithRed:30/255.0f green:147/255.0f blue:212/255.0f alpha:1.0f];
    
    _boxCover = [[UIImage alloc] init];
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(5, 70, 120, 140)];
    [v setBackgroundColor:boxBackgroundColor];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    [iv setImage:_boxCover];
    [v addSubview:iv];
    [self.view addSubview:v];
    
    
    double xOffset = 140;
    
    _boxTitle = [[UILabel alloc] init];
    _boxTitle.translatesAutoresizingMaskIntoConstraints = YES;
    _boxTitle.text = @"Spaceballs 3: The search for spaceballs 2";
    _boxTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:17];
    [_boxTitle setTextColor:textColor];
    _boxTitle.textAlignment = NSTextAlignmentLeft;
    _boxTitle.frame = CGRectMake(xOffset, 82, [[UIScreen mainScreen] bounds].size.width - xOffset, 14);
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
    _seekBar.value = 20;
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
    _boxDescription.numberOfLines = 3;
    _boxDescription.text = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
    _boxDescription.font = [UIFont fontWithName:@"Helvetica" size:14];
    [_boxDescription setTextColor: textColor];
    _boxDescription.textAlignment = NSTextAlignmentLeft;
    _boxDescription.frame = CGRectMake(xOffset, 165, [[UIScreen mainScreen] bounds].size.width - xOffset, 40);
    [self.view addSubview:_boxDescription];
}

- (void) createTableView {
    double tableXOffset = 215;
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
    _overlayLabel.text = @"Last updated at 9:30 am";
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
                                 style:UIBarButtonItemStylePlain target:self action:@selector(stub:) ];
    
    
    NSArray *buttons = [NSArray arrayWithObjects:  commands, flex , sort, flex, filter, flex, numberPad, flex, guideBack, flex, guideForward, nil];
    [_toolBar setItems:buttons animated:NO];
    
    [self.view addSubview:_toolBar];

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *keys = [_channels allKeys];
    return [keys count];
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
    NSArray *keys = [_channels allKeys];
    id aKey = [keys objectAtIndex:indexPath.row];
    
    cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage new]];

    NSDictionary *channel = [_channels objectForKey:aKey];
    NSDictionary *guideItem = [_guide objectForKey:aKey];
    
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
        
        NSDate *now = [NSDate new];
        NSDate *ends = [guideItem objectForKey:@"ends"];
        /*
         NSDate *starts = [guideItem objectForKey:@"starts"];
         NSTimeInterval duration = [ends timeIntervalSinceDate:starts];
         NSTimeInterval elasped = [now timeIntervalSinceDate:starts];
         double percentage = (elasped/duration)*100.0;
         if (percentage > 75) {
         showIsEndingSoon = YES;
         }
         */
        
        NSCalendar *calendar = [NSCalendar currentCalendar];
        [calendar setTimeZone:[NSTimeZone localTimeZone]];
        NSUInteger unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute;
        NSDateComponents *components = [calendar components:unitFlags
                                                   fromDate: now
                                                     toDate: ends
                                                    options:0];
        
        timeLeft = [NSString stringWithFormat:@"%02ld:%02ld", [components hour], [components minute]];
        
        if ([components hour] == 0 && [components minute] <= 10) {
            showIsEndingSoon = YES;
        }
        
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
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:@"Please Choose a device"
                              message:nil
                              delegate:self
                              cancelButtonTitle:nil
                              otherButtonTitles:@"OK", nil];
        [alert show];
        return;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    //NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    NSArray *keys = [_channels allKeys];
    
    id key = [keys objectAtIndex: row];
    id item = _channels[key];
    
    NSDictionary *channel = @{@"chNum":item[@"chNum"], @"device":_currentClient};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageChangeChannel" object:channel];
    
    
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
        [self refreshGuide];
    });

}

- (void) messageUpdatedChannelsProgress:(NSNotification *)notification {
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.progress = [[notification object] floatValue];
    
}

- (IBAction) findClients:(id)sender {
    
    if ([_clients count] == 0) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.labelText = @"Scanning wifi network for devices...";
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageFindClients" object:nil];
    } else {
        [self showDevicePicker:nil];
    }

}

- (void) messageUpdatedClients:(NSNotification *)notification {
    _clients = notification.object;
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [self showDevicePicker:nil];
}

- (void) messageUpdatedClientsProgress:(NSNotification *)notification {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = [[notification object] floatValue];
    }];
}

- (IBAction)showDevicePicker:(id)sender {
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    UIAlertController *view = [UIAlertController
                               alertControllerWithTitle:@""
                               message:@"Choose a device"
                               preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSUInteger i = 0; i < [_clients count]; i++) {
        id item = [_clients objectAtIndex: i];
        UIAlertAction *action = [UIAlertAction actionWithTitle: item[@"name"] style: UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            
            _currentClient = item;
            _navItem.title = _currentClient[@"name"];
            
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
        [self findClients:nil];
        return;
    }];
    [view addAction:refresh];

    
    UIViewController *vc = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [vc presentViewController:view animated:YES completion:nil];
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

- (void) messageUpdatedGuide:(NSNotification *)notification {
    _guide = notification.object;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        _overlayProgress.hidden = YES;
        _overlayLabel.text = @"Guide updated.";
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [_mainTableView reloadData];
    }];
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

- (IBAction)rewind:(id)sender {
    
}
- (IBAction)forward:(id)sender {
    
}
- (IBAction)playPause:(id)sender {
    
}
@end
