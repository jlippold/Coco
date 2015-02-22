//
//  ViewController.m
//  dtvRemote
//
//  Created by Jed Lippold on 2/21/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "ViewController.h"

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
        [self populateChannelList];
    } else {
        NSLog(@"Channel list loaded from disk");
        [self startWhatsPlayingTimer];
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
    _webView = [[UIWebView alloc] init];
    [_webView setFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, 200)];
    [_webView setDelegate:self];
    NSURL *nsurl = [NSURL URLWithString:@"https://www.directv.com/guide"];
    NSURLRequest *nsrequest=[NSURLRequest requestWithURL:nsurl];
    [_webView loadRequest:nsrequest];
}



-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"Error loading: %@", [error description]);
}

- (void)webViewDidFinishLoad:(UIWebView *)webview {
    if ([[webview stringByEvaluatingJavaScriptFromString:@"document.readyState"] isEqualToString:@"complete"]) {
        // UIWebView object has fully loaded.
        
        NSString *data = [webview
                          stringByEvaluatingJavaScriptFromString:@"JSON.stringify(dtvClientData.guideData);"];
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        if (json[@"channels"]) {
            
            for (id item in [json objectForKey: @"channels"]) {
                
                NSDictionary *dictionary = @{@"chId" : [item objectForKey:@"chId"],
                                             @"chName" : [item objectForKey:@"chName"],
                                             @"chCall" : [item objectForKey:@"chCall"],
                                             @"chNum": [item objectForKey:@"chNum"],
                                             @"chHd": [item objectForKey:@"chHd"],
                                             @"title": @"Loading..."};
                
                [_channelList setObject:dictionary forKey:[[item objectForKey:@"chId"] stringValue]];
            }
            
        }
        _webView = nil;
        [self saveChannelList];
        [self startWhatsPlayingTimer];
        [_mainTableView reloadData];
        
    }
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
