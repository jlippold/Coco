//
//  Commands.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "Commands.h"

@implementation Commands


-(id) init {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageChangeChannel:)
                                                 name:@"messageChangeChannel" object:nil];
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) messageChangeChannel:(NSNotification *)notification {
    NSDictionary *obj = [notification object];
    [self changeChannel:obj[@"chNum"] device:obj[@"device"]];
}


-(void)changeChannel:(NSString *)chNum device:(NSMutableDictionary *)device  {
    //get valid locations for zip code
    NSLog(@"%@ set to channel %@", device, chNum);
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://%@:8080/tv/tune?major=%@&%@",
                   device[@"address"], chNum, device[@"appendage"] ]];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil) {
             
         } else {
             
         }
         
     }];
}

@end
