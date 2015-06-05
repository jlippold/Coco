//
//  dtvNowPlaying.m
//  dtvRemote
//
//  Created by Jed Lippold on 6/4/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "dtvNowPlaying.h"
#import "dtvGuide.h"    
#import "dtvChannel.h"

@implementation dtvNowPlaying {
    BOOL checkedDescription;
    BOOL checkedImage;
}

- (id) init {
    return self;
}

- (void) update:(dtvChannel *)channel {

    _channel = channel;
    checkedDescription = NO;
    checkedImage = NO;
    [self setNowPlaying];
    
}

- (void) setNowPlaying {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSDictionary *guideData = [dtvGuide getNowPlayingForChannel:_channel];
        
        if ([[guideData allKeys] count] == 0) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedNowPlaying"
                                                                object:nil];
            return;
        }
        
        NSString *key = [guideData allKeys][0];
        dtvGuideItem *guideItem = guideData[key];
        
        NSDictionary *duration = [dtvGuide getDurationForChannel:guideItem];
        _percentComplete = [duration[@"percentage"] doubleValue];
        _timeLeft = [NSString stringWithFormat:@"-%@", duration[@"timeLeft"]];
        _programId = guideItem.programID;
        _HD = guideItem.hd;
        _channelImage = [dtvChannel getImageForChannel:_channel];
        
        [self getDescription];
        [self setBoxCoverForChannel:guideItem.imageUrl];
        
    });
}

- (void) getDescription  {
    
    NSURL* programURL = [NSURL URLWithString:
                         [NSString stringWithFormat:@"https://www.directv.com/json/program/flip/%@", _programId]];
    
    _title = @"";
    _synopsis = @"";
    
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:programURL]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError)
     {
         if (data.length > 0 && connectionError == nil) {
             NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
             
             if (json[@"programDetail"]) {
                 
                 id show = json[@"programDetail"];
                 if (show[@"description"]) {
                     _synopsis = show[@"description"];
                 }
                 
                 NSString *title = show[@"title"];
                 
                 if (show[@"title"] && show[@"episodeTitle"]) {
                     if (![show[@"episodeTitle"] isEqualToString:@""]) {
                         title = [NSString stringWithFormat:@"%@ - %@",
                                  title, show[@"episodeTitle"]];
                     }
                 }
                 if (show[@"title"] && show[@"releaseYear"]) {
                     title = [NSString stringWithFormat:@"%@ (%@)",
                              title, show[@"releaseYear"]];
                 }
                 
                 if (show[@"rating"]) {
                     _rating = show[@"rating"];
                 }
                 
                 if (show[@"starRatingNum"]) {
                     _stars = [show[@"starRatingNum"] doubleValue];
                 }
                 
                 _title = title;
                 
             }
         }
         checkedDescription = YES;
         
         if (checkedDescription && checkedImage) {
             [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedNowPlaying"
                                                                 object:self];
         }
     }];
}

- (void) setBoxCoverForChannel:(NSString *)path {
    NSURL* imageUrl = [NSURL URLWithString:
                       [NSString stringWithFormat:@"https://dtvimages.hs.llnwd.net/e1%@", path]];
    
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:imageUrl]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil) {
             _image = [UIImage imageWithData:data];
         }
         checkedImage = YES;
         
         if (checkedDescription && checkedImage) {
             [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedNowPlaying"
                                                                 object:self];
         }
     }];
    
}



@end

