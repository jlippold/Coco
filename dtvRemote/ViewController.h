//
//  ViewController.h
//  dtvRemote
//
//  Created by Jed Lippold on 2/21/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UITableViewDataSource,UITableViewDelegate> {
    NSArray* _mainTableData;
    id classChannels;
    id classGuide;
    id classClients;
    id classCommands;
}

@property (nonatomic, strong) NSMutableDictionary *channels;
@property (nonatomic, strong) NSMutableDictionary *currentDevice;
@property (nonatomic, strong) NSMutableArray *devices;

@property (nonatomic, strong) UITableView *mainTableView;
@property (nonatomic, strong) IBOutlet UINavigationBar *navbar;
@property (nonatomic, strong) UILabel *navTitle;
@property (nonatomic, strong) UILabel *navSubTitle;
@property (nonatomic, strong) UIImage *boxCover;
@property (nonatomic, strong) UILabel *boxTitle;
@property (nonatomic, strong) UILabel *boxDescription;





@end

