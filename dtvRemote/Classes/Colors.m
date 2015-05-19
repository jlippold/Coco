//
//  Colors.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/9/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "Colors.h"

@implementation Colors

+ (UIImage *)imageWithColor:(UIColor *)color {
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (UIColor *)averageColor:(UIImage*) img {
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char rgba[4];
    CGContextRef context = CGBitmapContextCreate(rgba, 1, 1, 8, 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), img.CGImage);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    if(rgba[3] > 0) {
        CGFloat alpha = ((CGFloat)rgba[3])/255.0;
        CGFloat multiplier = alpha/255.0;
        return [UIColor colorWithRed:((CGFloat)rgba[0])*multiplier
                               green:((CGFloat)rgba[1])*multiplier
                                blue:((CGFloat)rgba[2])*multiplier
                               alpha:alpha];
    }
    else {
        return [UIColor colorWithRed:((CGFloat)rgba[0])/255.0
                               green:((CGFloat)rgba[1])/255.0
                                blue:((CGFloat)rgba[2])/255.0
                               alpha:((CGFloat)rgba[3])/255.0];
    }
}

+ (UIColor *) textColor {
    return [UIColor colorWithRed:193/255.0f green:193/255.0f blue:193/255.0f alpha:1.0f];
}
+ (UIColor *) lightTextColor {
    return [UIColor colorWithRed:125/255.0f green:125/255.0f blue:125/255.0f alpha:1.0f];
}
+ (UIColor *) backgroundColor {
    return [UIColor colorWithRed:30/255.0f green:30/255.0f blue:30/255.0f alpha:1.0f];
}
+ (UIColor *) boxBackgroundColor {
    return [UIColor colorWithRed:28/255.0f green:28/255.0f blue:28/255.0f alpha:1.0f];
}
+ (UIColor *) navBGColor {
    return [UIColor colorWithRed:23/255.0f green:23/255.0f blue:23/255.0f alpha:1.0f];
}
+ (UIColor *) navClearColor {
    return [UIColor colorWithWhite:0.0 alpha:0.3];
}
+ (UIColor *) tintColor {
    return [UIColor colorWithRed:30/255.0f green:147/255.0f blue:212/255.0f alpha:1.0f];
}
+ (UIColor *) seperatorColor {
    return [UIColor colorWithRed:40/255.0f green:40/255.0f blue:40/255.0f alpha:1.0f];
}
+ (UIColor *) greenColor {
    return [UIColor colorWithRed:48/255.0f green:169/255.0f blue:70/255.0f alpha:1.0f];
}
+ (UIColor *) redColor {
    return [UIColor colorWithRed:199/255.0f green:29/255.0f blue:51/255.0f alpha:1.0f];
}
+ (UIColor *) blueColor {
    return [UIColor colorWithRed:0.204 green:0.459 blue:1.000 alpha:1.0];
}
+ (UIColor *) transparentColor {
    return [UIColor clearColor];
}

@end
