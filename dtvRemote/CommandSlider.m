//
//  CommandSlider.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/12/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "CommandSlider.h"

@implementation CommandSlider {
    UIScrollView *commandScrollView;
    UIPageControl *commandPager;
    UIImageView *iv;
}

- (id)initWithImage:(UIImage *)image commands:(NSDictionary *)commands {
    CGRect frame = [[UIScreen mainScreen] bounds];
    self = [super initWithFrame:frame];
    if (self) {
        [self addBackgroundView:image];
        [self addVibrancyViews];
        [self setupScrollView:commandScrollView];
    }
    return self;
}

- (void) addBackgroundView:(UIImage *) image {
    iv = [[UIImageView alloc] initWithImage:image];
    iv.frame = [[UIScreen mainScreen] bounds];
    iv.contentMode = UIViewContentModeScaleToFill;
    [self addSubview:iv];
}

- (void) addVibrancyViews {
    
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    effectView.translatesAutoresizingMaskIntoConstraints = NO;
    effectView.userInteractionEnabled = YES;
    
    UIVibrancyEffect *vibrance = [UIVibrancyEffect effectForBlurEffect:blurEffect];
    UIVisualEffectView *newEffectView = [[UIVisualEffectView alloc] initWithEffect:vibrance];
    newEffectView.translatesAutoresizingMaskIntoConstraints = NO;
    newEffectView.userInteractionEnabled = YES;
    
    // Add the vibrance effect to our blur effect view
    [effectView.contentView addSubview:newEffectView];
    
    [effectView.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[v]|" options:0 metrics:nil views: @{ @"v" : newEffectView }]];
    [effectView.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[v]|" options:0 metrics:nil views: @{ @"v" : newEffectView }]];
    
    CGRect frm = [[UIScreen mainScreen] bounds];
    frm.size.height = 80;
    frm.origin.x = 0;
    frm.origin.y = 400;
    
    UILabel *test = [[UILabel alloc] initWithFrame:frm];
    test.text = @"";
    test.font = [UIFont fontWithName:@"Helvetica" size:30];
    test.textAlignment = NSTextAlignmentCenter;
    
    // Add label to the vibrance content view.
    [newEffectView.contentView addSubview:test];
    [newEffectView.contentView addConstraint:[NSLayoutConstraint constraintWithItem:test attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:newEffectView.contentView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0]];
    [newEffectView.contentView addConstraint:[NSLayoutConstraint constraintWithItem:test attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:newEffectView.contentView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0]];
    

    commandScrollView = [[UIScrollView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    commandScrollView.pagingEnabled = YES;
    commandScrollView.delegate = self;
    commandScrollView.showsHorizontalScrollIndicator = NO;
    
    frm = [[UIScreen mainScreen] bounds];
    frm.origin.y = frm.size.height - 30;
    frm.size.height = 10;
    
    commandPager = [[UIPageControl alloc] initWithFrame:frm];
    commandPager.numberOfPages = 3;
    commandPager.currentPage = 0;
    
    [newEffectView.contentView addSubview:commandScrollView];
    [newEffectView.contentView addSubview:commandPager];
    
    [self addSubview:effectView];
    
}

- (void) setupScrollView:(UIScrollView*)scrollView {
    
    UIView *v1 = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIView *v2 = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIView *v3 = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    NSArray *vArray = [[NSArray alloc] initWithObjects:v1, v2, v3, nil];
    
    for (int i=0; i<=[vArray count]-1; i++) {
        
        UIView *v = [vArray objectAtIndex:i];
        CGRect frm = [[UIScreen mainScreen] bounds];
        frm.origin.x = (i*scrollView.frame.size.width);
        v.frame = frm;
        
        UIButton *button = [[UIButton alloc] init];
        button.frame = CGRectMake(0, 0, 100, 100);
        [button setTitle:@"ON" forState:UIControlStateNormal];
        button.layer.borderColor = [UIColor redColor].CGColor;
        button.layer.borderWidth = 2.0f;
        button.layer.cornerRadius = button.bounds.size.width/2;
        
        button.titleLabel.numberOfLines = 2;
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.lineBreakMode = NSLineBreakByClipping;
        button.titleLabel.font = [UIFont fontWithName:@"Helvetica" size:42];
        [v addSubview:button];
        
        UILabel *crap = [[UILabel alloc] init];
        crap.text = @"shit tits";
        crap.adjustsFontSizeToFitWidth = YES;
        crap.lineBreakMode = NSLineBreakByClipping;
        crap.font = [UIFont fontWithName:@"Helvetica" size:16];
        crap.backgroundColor = [UIColor whiteColor];
        crap.textColor = [UIColor blackColor];

        crap.frame = CGRectMake(0, 100, 80, 80);;
        
        [v addSubview:crap];
        

        [scrollView addSubview:v];
    }
    
    CGSize frame = scrollView.frame.size;
    frame.width = frame.width * [vArray count] - 1;
    [scrollView setContentSize:frame];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self updateCommandPager];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self updateCommandPager];
}

-(void) updateCommandPager {
    
    CGFloat pageWidth = commandScrollView.frame.size.width;
    int page = floor((commandScrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
    commandPager.currentPage = page;
}

@end
