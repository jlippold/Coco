//
//  Colors.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/9/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "Colors.h"
#import "CCColorCube.h"

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


+ (NSMutableArray *) getMainColors:(UIImage*) img {
    
    CCColorCube *colorCube = [[CCColorCube alloc] init];
    int total = 4;
    NSMutableArray *colors = [[colorCube extractBrightColorsFromImage:img avoidColor:nil count:total] mutableCopy];
    
    if (colors.count == 0) {
        return nil;
    }
    
    for (int i = 0; i < (total-1); i++) {
        if (i >= colors.count) {
            UIColor *first = [colors objectAtIndex:0];
            [colors addObject:first];
        } else {
            UIColor *safeColor = [self getNonDarkColor:[colors objectAtIndex:i]];
            [colors setObject:safeColor atIndexedSubscript:i];
        }

    }
    return colors;
}


+ (UIColor *)getNonDarkColor:(UIColor*)someColor {
    
    const CGFloat *componentColors = CGColorGetComponents(someColor.CGColor);
    
    CGFloat darknessScore = (((componentColors[0]*255) * 299) + ((componentColors[1]*255) * 587) + ((componentColors[2]*255) * 114)) / 1000;
    
    if (darknessScore < 100) {
        return [self changeBrightness:someColor amount:1.5];
    } else {
        return someColor;
    }
    
}

+ (UIColor*)changeBrightness:(UIColor*)color amount:(CGFloat)amount
{
    
    CGFloat hue, saturation, brightness, alpha;
    if ([color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        brightness += (amount-1.0);
        brightness = MAX(MIN(brightness, 1.0), 0.0);
        return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
    }
    
    CGFloat white;
    if ([color getWhite:&white alpha:&alpha]) {
        white += (amount-1.0);
        white = MAX(MIN(white, 1.0), 0.0);
        return [UIColor colorWithWhite:white alpha:alpha];
    }
    
    return nil;
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
