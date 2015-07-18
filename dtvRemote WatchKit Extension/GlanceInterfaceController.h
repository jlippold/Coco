//
//  GlanceInterfaceController.h
//  dtvRemote
//
//  Created by Jed Lippold on 7/16/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>

@interface GlanceInterfaceController : WKInterfaceController

@property (weak, nonatomic) IBOutlet WKInterfaceLabel *NowPlayingtitle;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *deviceLabel;
@property (weak, nonatomic) IBOutlet WKInterfaceImage *channelImage;
@property (weak, nonatomic) IBOutlet WKInterfaceImage *boxCover;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *timeRemaining;
@property (weak, nonatomic) IBOutlet WKInterfaceImage *logo;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *synopsis;

@end
