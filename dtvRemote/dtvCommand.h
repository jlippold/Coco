//
//  Command.h
//  dtvRemote
//
//  Created by Jed Lippold on 4/30/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface dtvCommand : NSObject

@property (nonatomic, strong) NSString *dtvCommandText;
@property (nonatomic, strong) NSString *commandDescription;
@property (nonatomic, strong) NSString *shortName;
@property (nonatomic, strong) NSString *sideBarCategory;
@property (nonatomic, strong) NSString *sideBarSortIndex;
@property BOOL showInNumberPad;
@property BOOL showInSideBar;
@property (nonatomic, strong) NSString *numberPadPagePosition;
@property (nonatomic, strong) NSString *numberPadPageName;


@end
