//
//  ViewController.m
//  dtvRemote
//
//  Created by Jed Lippold on 2/21/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "ViewController.h"
#import "MBProgressHUD.h"
#import "iNet.h"
#import "Channels.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
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
    channels = ch;
    
    _channelList = [channels loadChannels];
    
    _devices = [[NSMutableArray alloc] init];
    _currentDevice = [[NSMutableDictionary alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pushClients:)
                                                 name:@"pushClients" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pushLocations:)
                                                 name:@"pushLocations" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pushChannelList:)
                                                 name:@"pushChannelList" object:nil];
    
    [self createMainView];
    
    _whatsPlayingQueue = [[NSOperationQueue alloc] init];
    _whatsPlayingQueue.name = @"Whats Playing";
    _whatsPlayingQueue.maxConcurrentOperationCount = 3;
    
    if ([[_channelList allKeys] count] == 0) {
        dispatch_after(0, dispatch_get_main_queue(), ^{
            [self promptForZipCode];
        });
    } else {
        NSLog(@"Channel list loaded from disk");
        [self startWhatsPlayingTimer];
    }
}

- (void) createMainView {
    
    //nav bar
    CGRect navBarFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, 64.0);
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    _navbar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    //[_navbar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    //_navbar.translucent = YES;
    //_navbar.tintColor = [UIColor whiteColor];
    //_navbar.titleTextAttributes = @{NSForegroundColorAttributeName : [UIColor whiteColor]};
    
    _navTitle = [[UILabel alloc] init];
    _navTitle.translatesAutoresizingMaskIntoConstraints = YES;
    _navTitle.text = @"Title";
    _navTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:17];
    [_navTitle setTextColor:[UIColor blackColor]];
    _navTitle.tintColor = [UIColor whiteColor];
    _navTitle.textAlignment = NSTextAlignmentCenter;
    _navTitle.frame = CGRectMake(0, 28, [[UIScreen mainScreen] bounds].size.width, 20);
    
    _navSubTitle = [[UILabel alloc] init];
    _navSubTitle.translatesAutoresizingMaskIntoConstraints = YES;
    _navSubTitle.text = @"subtitle";
    _navSubTitle.font = [UIFont fontWithName:@"Helvetica" size:15];
    [_navSubTitle setTextColor: [UIColor blackColor]];
    _navSubTitle.textAlignment = NSTextAlignmentCenter;
    _navSubTitle.frame = CGRectMake(0, 44, [[UIScreen mainScreen] bounds].size.width, 20);
    [_navSubTitle setFont:[UIFont systemFontOfSize:14]];
    
    [_navbar addSubview:_navTitle];
    [_navbar addSubview:_navSubTitle];
    
    UINavigationItem *navItem = [UINavigationItem alloc];
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self  action:@selector(findClients:)];
    navItem.leftBarButtonItem = leftButton;
    
    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self  action:@selector(showDevicePicker:)];
    navItem.rightBarButtonItem = rightButton;
    [_navbar pushNavigationItem:navItem animated:false];
    [self.view addSubview:_navbar];
    

    _boxCover = [[UIImage alloc] init];
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(10, 70, 120, 160)];
    [v setBackgroundColor:[UIColor redColor]];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    [iv setImage:_boxCover];
    [v addSubview:iv];
    [self.view addSubview:v];

    
    double xOffset = 140;
    
    _boxTitle = [[UILabel alloc] init];
    _boxTitle.translatesAutoresizingMaskIntoConstraints = YES;
    _boxTitle.text = @"Some Title";
    _boxTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:17];
    [_boxTitle setTextColor:[UIColor blackColor]];
    _boxTitle.textAlignment = NSTextAlignmentLeft;
    _boxTitle.frame = CGRectMake(xOffset, 90, [[UIScreen mainScreen] bounds].size.width - xOffset, 14);
    [self.view addSubview:_boxTitle];
    
    _boxDescription = [[UILabel alloc] init];
    _boxDescription.translatesAutoresizingMaskIntoConstraints = YES;
    _boxDescription.text = @"Some Description";
    _boxDescription.font = [UIFont fontWithName:@"Helvetica" size:15];
    [_boxDescription setTextColor: [UIColor blackColor]];
    _boxDescription.textAlignment = NSTextAlignmentLeft;
    _boxDescription.frame = CGRectMake(xOffset, 105, [[UIScreen mainScreen] bounds].size.width - xOffset, 40);
    [self.view addSubview:_boxDescription];
    
    
    
    _mainTableView = [[UITableView alloc] init];
    [_mainTableView setFrame:CGRectMake(0, 200,
                                        [[UIScreen mainScreen] bounds].size.width,
                                        [[UIScreen mainScreen] bounds].size.height-200)];
    _mainTableView.dataSource = self;
    _mainTableView.delegate = self;
    
    [self.view addSubview:_mainTableView];
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *keys = [_channelList allKeys];
    return [keys count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SomeId"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SomeId"] ;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    NSArray *keys = [[_channelList allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    
    id aKey = [keys objectAtIndex:indexPath.row];
    
    NSDictionary *item = [_channelList objectForKey:aKey];
    cell.textLabel.text = [item objectForKey:@"title"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@",
                                 [item objectForKey:@"chNum"],
                                 [item objectForKey:@"chName"]];
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    //NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    NSArray *keys = [[_channelList allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    
    id key = [keys objectAtIndex: row];
    id item = _channelList[key];
    
    [self changeChannel:item[@"chNum"]];
    
    NSLog(@"%@", item );
    
}

-(void)changeChannel:(NSString *)chNum {
    //get valid locations for zip code
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://%@:8080/tv/tune?major=%@&%@",
                   _currentDevice[@"address"], chNum, _currentDevice[@"appendage"] ]];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil) {
             
         } else {
             
         }
         
     }];
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
         
         [[NSNotificationCenter defaultCenter] postNotificationName:@"zipChosen" object:zip];
         
     }];
    
    [alert addAction:accept];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"zip"];
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = @"10001";
        
    }];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void) pushLocations:(NSNotification *)notification {
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
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"locationChosen" object:item];
                 [view dismissViewControllerAnimated:YES completion:nil];
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

- (void) pushChannelList:(NSNotification *)notification {
    _channelList = [notification object];
    [_mainTableView reloadData];
    [self startWhatsPlayingTimer];
}

-(void)startWhatsPlayingTimer {
    
    [self refreshWhatsPlaying];
    if (!_whatsPlayingTimer) {
        _whatsPlayingTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(fireTimer:) userInfo:nil repeats:YES];
    }
}

-(void)stopWhatsPlayingTimer {
    [_whatsPlayingTimer invalidate];
    _whatsPlayingTimer = nil;
}

- (void)fireTimer:(NSTimer *)timer {
    [self refreshWhatsPlaying];
}

- (void) refreshWhatsPlaying {
    
    [_whatsPlayingQueue cancelAllOperations];
    
    //Get UTC date format
    NSDate *currentDateTime = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
    NSString *localDateString = [dateFormatter stringFromDate:currentDateTime];
    
    //build a base URL for all now playing requests
    NSString *builder = @"https://www.directv.com/json/channelschedule";
    builder = [builder stringByAppendingString:@"?channels=%@"];
    builder = [builder stringByAppendingString:@"&startTime=%@"];
    builder = [builder stringByAppendingString:@"&hours=4"];
    builder = [builder stringByAppendingString:@"&chIds=%@"];
    
    NSLog(@"Base URL: %@", builder);
    
    
    //Download data in 50 channel chunks
    NSUInteger chunkSize = 50;
    int requests = ceil((double)[[_channelList allKeys] count]/chunkSize);
    NSLog(@"Total Channels: %lu", (unsigned long)[[_channelList allKeys] count]);
    NSLog(@"Requests to make: %d", requests);
    
    //add all requests to the queue
    for (NSUInteger i = 0; i < requests; i++) {
        
        NSInteger offset = i*chunkSize;
        NSString *strUrl = [NSString stringWithFormat:builder,
                            [self getJoinedArrayByProp:@"chNum" arrayOffset:offset chunkSize:chunkSize],
                            [localDateString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                            [self getJoinedArrayByProp:@"chId" arrayOffset:offset chunkSize:chunkSize]
                            ];
        
        NSLog(@"Request #%lu Fired", (unsigned long)i);
        
        NSURL *url = [NSURL URLWithString:strUrl];
        
        
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                           queue:_whatsPlayingQueue
                               completionHandler:^(NSURLResponse *response,
                                                   NSData *data,
                                                   NSError *connectionError)
         {
             
             if (data.length > 0 && connectionError == nil) {
                 //update channelList with currently playing title
                 NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                 if (json[@"schedule"]) {
                     for (id item in [json objectForKey: @"schedule"]) {
                         if (item[@"chId"] && item[@"schedules"]) {
                             NSString *chId = [NSString stringWithFormat:@"%05ld", (long)[[item objectForKey:@"chNum"] integerValue]];
                             
                             if (_channelList[chId]) {
                                 NSArray *schedule = [item objectForKey:@"schedules"];
                                 if ([schedule count]> 0) {
                                     NSDictionary *nowPlaying = schedule[0];
                                     if (nowPlaying[@"title"]) {
                                         NSMutableDictionary *subdict = [_channelList[chId] mutableCopy];
                                         subdict[@"title"] = nowPlaying[@"title"];
                                         _channelList[chId] = subdict;
                                     }
                                 }
                             }
                         }
                     }
                     
                 }
             }
             
             //reload the table on the main Queue
             [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                 [_mainTableView reloadData];
             }];
             
         }];
        
    }
}

- (NSString *)getJoinedArrayByProp:(NSString *)prop arrayOffset:(NSInteger)offset chunkSize:(NSInteger)size  {
    //returns a csv list of some property in _channelList for url building
    NSMutableArray *outArray = [[NSMutableArray alloc] init];
    
    NSArray *keys = [_channelList allKeys];
    NSUInteger totalPossible = [keys count];
    
    for (NSUInteger i = offset; i < totalPossible; i++) {
        id key = [keys objectAtIndex: i];
        id item = _channelList[key];
        if (i <= (offset + size)) {
            [outArray addObject:[item[prop] stringValue]];
        }
    }
    
    return [outArray componentsJoinedByString:@","];
}

- (IBAction)findClients:(id)sender {
    iNet* inet = [[iNet alloc] init];
    [inet findClients];
}

- (void) pushClients:(NSNotification *)notification {
    _devices = notification.object;
    [self showDevicePicker:nil];
}


- (IBAction)showDevicePicker:(id)sender {
    
    UIAlertController *view = [UIAlertController
                               alertControllerWithTitle:@"Choose A Device"
                               message:@""
                               preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSUInteger i = 0; i < [_devices count]; i++) {
        id item = [_devices objectAtIndex: i];
        UIAlertAction *action = [UIAlertAction actionWithTitle: item[@"name"] style: UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            
            _currentDevice = item;
            _navTitle.text = _currentDevice[@"name"];
            
            [view dismissViewControllerAnimated:YES completion:nil];
        }];
        [view addAction:action];
    }
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        [view dismissViewControllerAnimated:YES completion:nil];
        return;
    }];
    
    [view addAction:cancel];
    
    UIViewController *vc = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [vc presentViewController:view animated:YES completion:nil];
}




@end
