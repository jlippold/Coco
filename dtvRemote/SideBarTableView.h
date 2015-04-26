//
//  SideBar.h
//  dtvRemote
//
//  Created by Jed Lippold on 4/7/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SideBarTableView : NSObject <UITableViewDataSource> {

}
@property (nonatomic, strong) NSMutableDictionary *clients;
@property (nonatomic, strong) NSDictionary *currentClient;


@end

