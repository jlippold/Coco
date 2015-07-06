//
//  Colors.h
//  dtvRemote
//
//  Created by Jed Lippold on 5/9/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface Colors : NSObject


+ (UIImage *) imageWithColor:(UIColor *)color;
+ (NSMutableArray *) getMainColors:(UIImage*) img;
+ (UIColor *) textColor;
+ (UIColor *) lightTextColor;
+ (UIColor *) backgroundColor;
+ (UIColor *) boxBackgroundColor;
+ (UIColor *) navBGColor;
+ (UIColor *) navClearColor;
+ (UIColor *) tintColor;
+ (UIColor *) seperatorColor;
+ (UIColor *) blueColor;
+ (UIColor *) greenColor;
+ (UIColor *) redColor;
+ (UIColor *) transparentColor;

@end

