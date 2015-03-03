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
#import "Guide.h"
#import "Commands.h"
#import "Clients.h"

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
    Guide *gd = [[Guide alloc] init];
    Commands *co = [[Commands alloc] init];
    Clients *cl = [[Clients alloc]  init];
    
    classChannels = ch;
    classGuide = gd;
    classCommands = co;
    classClients = cl;

    _channels = [classChannels loadChannels];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedChannels" object:_channels];
    
    _devices = [[NSMutableArray alloc] init];
    _currentDevice = [[NSMutableDictionary alloc] init];
    

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedClients:)
                                                 name:@"messageUpdatedClients" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedLocations:)
                                                 name:@"messageUpdatedLocations" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedChannels:)
                                                 name:@"messageUpdatedChannels" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedGuide:)
                                                 name:@"messageUpdatedGuide" object:nil];
    
    [self createMainView];
    
    if ([[_channels allKeys] count] == 0) {
        dispatch_after(0, dispatch_get_main_queue(), ^{
            [self promptForZipCode];
        });
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
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:@"Room" style:UIBarButtonItemStylePlain target:self action:@selector(findClients:)];
    navItem.leftBarButtonItem = leftButton;
    

    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(showDevicePicker:)];
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
    NSArray *keys = [_channels allKeys];
    return [keys count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SomeId"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SomeId"] ;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    NSArray *keys = [[_channels allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    
    id aKey = [keys objectAtIndex:indexPath.row];
    
    NSDictionary *item = [_channels objectForKey:aKey];
    cell.textLabel.text = [item objectForKey:@"title"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@",
                                 [item objectForKey:@"chNum"],
                                 [item objectForKey:@"chName"]];
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[_currentDevice allKeys] count] == 0) {
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
    
    NSArray *keys = [[_channels allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    
    id key = [keys objectAtIndex: row];
    id item = _channels[key];
    
    NSDictionary *channel = @{@"chNum":item[@"chNum"], @"device":_currentDevice};
    
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
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedLocations" object:item];
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

- (void) messageUpdatedChannels:(NSNotification *)notification {
    _channels = [notification object];
    [_mainTableView reloadData];
}

- (IBAction)findClients:(id)sender {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeIndeterminate;
    hud.labelText = @"Searching for devices...";


    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageFindClients" object:nil];
}

- (void) messageUpdatedClients:(NSNotification *)notification {
    _devices = notification.object;
    [self showDevicePicker:nil];
}

- (void) messageUpdatedGuide:(NSNotification *)notification {
    _channels = notification.object;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_mainTableView reloadData];
    }];
}

- (IBAction)showDevicePicker:(id)sender {
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
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
