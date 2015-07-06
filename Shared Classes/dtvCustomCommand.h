//
//  dtvCustomCommand.h
//  dtvRemote
//
//  Created by Jed Lippold on 5/21/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface dtvCustomCommand : NSObject


@property BOOL isCustomCommand;
@property (nonatomic, strong) NSString *networkName;
@property (nonatomic, strong) NSString *deviceName;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, strong) NSString *method;
@property (nonatomic, strong) NSString *data;
@property (nonatomic, strong) NSString *buttonIndex;
@property (nonatomic, strong) NSString *abbreviation;
@property (nonatomic, strong) NSString *onCompleteURIScheme;

@property (nonatomic, strong) NSString *sideBarCategory;
@property (nonatomic, strong) NSString *commandDescription;
@property (nonatomic, strong) NSString *sideBarSortIndex;



@end
