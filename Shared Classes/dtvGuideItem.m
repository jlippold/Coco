//
//  dtvGuideItem.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/1/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "dtvGuideItem.h"

@implementation dtvGuideItem

- (id) initWithJSON:(NSDictionary *)json {
    
    if (self = [super init])
    {
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
        
        NSDate *startDate = [dateFormatter dateFromString:json[@"airTime"]];
        NSInteger duration = [json[@"duration"] intValue];
        
        
        if (json[@"programID"]) {
            _programID = json[@"programID"];
        }
        if (json[@"title"]) {
            _title = json[@"title"];
        }
        if (json[@"title"] && json[@"episodeTitle"]) {
            _title = [NSString stringWithFormat:@"%@ - %@",
                                   json[@"title"], json[@"episodeTitle"]];
        }
        if (json[@"title"] && json[@"releaseYear"]) {
            _title = [NSString stringWithFormat:@"%@ (%@)",
                                   json[@"title"], json[@"releaseYear"]];
        }
        
        if (json[@"starRatingNum"]) {
            _starRating = json[@"starRatingNum"];
        }
        
        if (json[@"primaryImageUrl"]) {
            _imageUrl = json[@"primaryImageUrl"];
        }
        
        if ([[json[@"hd"] stringValue] isEqualToString:@"1"]) {
            _hd = YES;
        } else {
            _hd = NO;
        }
        
        if (json[@"rating"]) {
            _rating = json[@"rating"];
        }
        
        _starts = startDate;
        _duration = duration;
        _ends = [startDate dateByAddingTimeInterval:duration*60];
        _upNext = @"Not Available";
        
        _onAir = [self isNowPlaying:_starts duration:_duration];
        
    }
    
    return self;
}

- (BOOL) isNowPlaying:(NSDate *)startDate duration:(NSInteger)duration {
    NSDate *now = [[NSDate alloc] init];
    if ([startDate timeIntervalSinceDate:now] > 0) {
        return NO;
    }
    NSDate *endDate = [startDate dateByAddingTimeInterval:duration*60];
    return ([endDate timeIntervalSinceDate:now] > 0);
}

@end
