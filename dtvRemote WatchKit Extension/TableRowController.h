//
//  TableRowController.h
//  dtvRemote
//
//  Created by Jed Lippold on 7/12/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>

@interface TableRowController : NSObject

@property (nonatomic, weak) IBOutlet WKInterfaceImage *image;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *label;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *imageLabel;
@end
