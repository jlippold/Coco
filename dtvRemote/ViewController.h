//
//  ViewController.h
//  dtvRemote
//
//  Created by Jed Lippold on 2/21/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UITableViewDataSource,UITableViewDelegate, UIWebViewDelegate> {
    NSArray* _mainTableData;
}

@property (nonatomic, strong) NSMutableDictionary *channelList;
@property (nonatomic, strong) UITableView *mainTableView;
@property (nonatomic, strong) UIWebView *webView;

@property (nonatomic, strong) NSOperationQueue *whatsPlayingQueue;
@property (nonatomic, strong) NSTimer *whatsPlayingTimer;

@end

