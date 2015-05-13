//
//  CommandSlider.h
//  dtvRemote
//
//  Created by Jed Lippold on 5/12/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CommandSlider : UIView <UIScrollViewDelegate>

- (id)initWithImage:(UIImage *)image commands:(NSDictionary *)commands;

@end

