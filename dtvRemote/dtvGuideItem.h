//
//  dtvGuideItem.h
//  dtvRemote
//
//  Created by Jed Lippold on 5/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "dtvChannel.h"

@interface dtvGuideItem : NSObject

@property (nonatomic, strong) NSString *programID;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *episodeTitle;
@property (nonatomic, strong) NSString *imageUrl;
@property (nonatomic, strong) NSString *rating;
@property (nonatomic, strong) NSString *starRating;
@property (nonatomic, strong) NSString *upNext;
@property (nonatomic, strong) NSDate *starts;
@property (nonatomic, strong) NSDate *ends;
@property (nonatomic, strong) NSString *futureAiring;
@property (nonatomic) NSInteger duration;

@property BOOL hd;
@property BOOL onAir;

-(id) initWithJSON:(NSDictionary *) json;

@end
