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

-(void)whatsOn:(NSMutableDictionary *) device {
    
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://%@:8080/tv/tune/getTuned?%@",
                   device[@"address"], device[@"appendage"] ]];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil) {
             NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
             if ((int)json[@"status"][@"code"] == 200){
                 if (json[@"major"]){
                     [[NSNotificationCenter defaultCenter]
                      postNotificationName:@"messageUpdatedNowPlaying"
                      object:json[@"major"]];
                 }
             }
         }
         
     }];
    
 
}
@end
