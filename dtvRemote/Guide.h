//
//  Guide.h
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Guide : NSObject

@property (nonatomic, strong) NSOperationQueue *whatsPlayingQueue;
@property (nonatomic, strong) NSMutableDictionary *channels;
@property (nonatomic, strong) NSDate *guideTime;

- (id)init;
+ (NSDictionary *)getDurationForChannel:(id)guideItem;

@end
