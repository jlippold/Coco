//
//  Command.h
//  dtvRemote
//
//  Created by Jed Lippold on 4/30/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface dtvCommand : NSObject

@property (nonatomic, strong) NSString *action;
@property (nonatomic, strong) NSString *desc;
@property (nonatomic, strong) NSString *category;


@end
