//
//  ViewController.m
//  dtvRemote
//
//  Created by Jed Lippold on 2/21/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "ViewController.h"
#import "iNet.h"


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

- (void) initiate {
    [self loadChannelList];
    if (!_channelList) {
        _channelList = [[NSMutableDictionary alloc] init];
    }
    [self createViews];
    
    _whatsPlayingQueue = [[NSOperationQueue alloc] init];
    _whatsPlayingQueue.name = @"Whats Playing";
    _whatsPlayingQueue.maxConcurrentOperationCount = 3;
    
    if ([[_channelList allKeys] count] == 0) {
        dispatch_after(0, dispatch_get_main_queue(), ^{
            [self populateChannelList];
        });
    } else {
        NSLog(@"Channel list loaded from disk");
        
        iNet* inet = [[iNet alloc] init];
        NSMutableArray *clients = [inet findClients];
        
        NSLog(@"%@", clients);
//        [self startWhatsPlayingTimer];
    }
}

- (void) createViews {
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
    NSArray *keys = [_channelList allKeys];
    id aKey = [keys objectAtIndex:indexPath.row];
    
    NSDictionary *item = [_channelList objectForKey:aKey];
    cell.textLabel.text = [item objectForKey:@"title"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@",
                                 [item objectForKey:@"chNum"],
                                 [item objectForKey:@"chName"]];
    return cell;
    
}

- (void) saveChannelList {
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] initWithCapacity:3];
    if (_channelList != nil) {
        [dataDict setObject:_channelList forKey:@"channelList"];
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:@"appData"];
    [NSKeyedArchiver archiveRootObject:dataDict toFile:filePath];
}

- (void) loadChannelList {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:@"appData"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([savedData objectForKey:@"channelList"] != nil) {
            _channelList = [[NSMutableDictionary alloc] initWithDictionary:[savedData objectForKey:@"channelList"]];
        }
    }
    
}

- (void) populateChannelList {
    NSLog(@"Loading Channel list...");
    
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
             [self populateChannelList];
             return;
         }
         
         //get valid locations for zip code
         NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.directv.com/json/zipcode/%@", zip]];
         [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                            queue:[NSOperationQueue mainQueue]
                                completionHandler:^(NSURLResponse *response,
                                                    NSData *data,
                                                    NSError *connectionError)
          {
              
              if (data.length > 0 && connectionError == nil) {
                  //update channelList with currently playing title
                  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                  NSMutableDictionary *zipCodes = [[NSMutableDictionary alloc] init];
                  
                  if (json[@"zipCodes"]) {
                      for (id item in [json objectForKey: @"zipCodes"]) {
                          NSString *zip = [item objectForKey:@"zipCode"];
                          NSDictionary *dictionary = @{@"zipCode" : [item objectForKey:@"zipCode"],
                                                       @"state" : [item objectForKey:@"state"],
                                                       @"countyName" : [item objectForKey:@"countyName"],
                                                       @"timeZone": item[@"timeZone"][@"tzId"] };
                          [zipCodes setObject:dictionary forKey:zip];
                      }
                  }
                  NSLog(@"%lu", (unsigned long)[zipCodes count]);
                  
                  NSArray *foundZipCodes = [zipCodes allKeys];
                  
                  if ([foundZipCodes count] == 0 ) {
                      //somethings wrong, ask again for zip
                      [self populateChannelList];
                      return;
                  } else {
                      
                      UIAlertController *view = [UIAlertController
                                                 alertControllerWithTitle:@"Confirm your location"
                                                 message:@""
                                                 preferredStyle:UIAlertControllerStyleActionSheet];
                      
                      for (NSUInteger i = 0; i < [foundZipCodes count]; i++) {
                          
                          id key = [foundZipCodes objectAtIndex: i];
                          id item = zipCodes[key];
                          UIAlertAction *action = [UIAlertAction actionWithTitle: item[@"countyName"] style: UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                              
                              [self loadChannelListFromLocation:item];
                              
                              [view dismissViewControllerAnimated:YES completion:nil];
                          }];
                          [view addAction:action];
                      }
                      
                      
                      UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
                          [view dismissViewControllerAnimated:YES completion:nil];
                          [self populateChannelList];
                          return;
                      }];
                      
                      [view addAction:cancel];
                      [self presentViewController:view animated:YES completion:nil];
                  }
                  
              } else {
                  [self populateChannelList];
                  return;
              }
              
          }];
         
     }];
    
    [alert addAction:accept];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"zip"];
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = @"10001";
        
    }];
    
    
    [self presentViewController:alert animated:YES completion:nil];

}

- (void) loadChannelListFromLocation:(id)location {
    NSLog(@"%@",location);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.directv.com/guide"]];
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    NSString *cookie = [NSString stringWithFormat:@"dtve-prospect-state=%@; dtve-prospect-zip=%@%%7C%@;",
                        location[@"state"], location[@"zipCode"],
                        [location[@"timeZone"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    [mutableRequest addValue:cookie forHTTPHeaderField:@"Cookie"];
    
    request = [mutableRequest copy];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:
     ^(NSURLResponse *response, NSData *data, NSError *error) {
         NSString *responseText = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
         for (NSString *line in [responseText componentsSeparatedByString:@"\n"]) {
             NSString *searchTerm = @"var dtvClientData = ";
             if ([line hasPrefix:@"<!--[if gt IE 8]>"] && [line containsString:searchTerm]) {
                 NSRange range = [line rangeOfString:searchTerm];
                 NSString *json = [line substringFromIndex:(range.location + searchTerm.length)];
                 NSRange endrange = [json rangeOfString:@"};"];
                 json = [json substringToIndex:endrange.location+1];
                 [self getJsonFromText:json];
             }
         }
     }];
    
}

- (void) getJsonFromText:(NSString *)text {
    NSLog(@"JSON: %@", text);
    
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    if (json[@"guideData"]) {
        id root = json[@"guideData"];
        if (root[@"channels"]) {
            for (id item in [root objectForKey: @"channels"]) {
                
                NSDictionary *dictionary = @{@"chId" : [item objectForKey:@"chId"],
                                             @"chName" : [item objectForKey:@"chName"],
                                             @"chCall" : [item objectForKey:@"chCall"],
                                             @"chNum": [item objectForKey:@"chNum"],
                                             @"chHd": [item objectForKey:@"chHd"],
                                             @"title": @"Loading..."};
                
                [_channelList setObject:dictionary forKey:[[item objectForKey:@"chId"] stringValue]];
            }
            
        }
        
    }
    
    [self saveChannelList];
    [self startWhatsPlayingTimer];
    [_mainTableView reloadData];
    
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
                             NSString *chId = [[item objectForKey:@"chId"] stringValue];
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




@end
