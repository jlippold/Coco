//
//  VibrancyViewController.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/16/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "VibrancyViewController.h"
#import "NumberPadViewController.h"
#import "Colors.h"

@interface VibrancyViewController ()

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property (nonatomic, weak) IBOutlet UIPageControl *pageControl;

@end

@implementation VibrancyViewController {
    int pages;
    UINavigationBar *navbar;
    UINavigationItem *navItem;
    NumberPadViewController *page1;
    NumberPadViewController *page2;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)])
        self.edgesForExtendedLayout = UIRectEdgeNone;
    
    self.view.frame = [UIScreen mainScreen].bounds;
    
    pages = 2;
    
    
    _scrollView.pagingEnabled = YES;
    _scrollView.delegate = self;
    _scrollView.showsHorizontalScrollIndicator = NO;
    
    
    CGRect navBarFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, 64.0);
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    
    navbar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    
    [navbar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    navbar.translucent = YES;
    navbar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    navbar.tintColor = [UIColor whiteColor];
    navbar.titleTextAttributes = @{NSForegroundColorAttributeName : [Colors textColor]};
    
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"Close"
                                                       style:UIBarButtonItemStyleDone
                                                      target:self
                                                      action:@selector(dismissView:)];
    

    navItem = [UINavigationItem alloc];
    navItem.title = @"Number Pad";
    navItem.rightBarButtonItem = closeButton;
    [navbar pushNavigationItem:navItem animated:false];
    
    [self.view addSubview:navbar];
    
    _pageControl.numberOfPages = pages;
    _pageControl.currentPage = 0;
    [self setupScrollView];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)dismissView:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^(void) {

    }];
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
    CGFloat pageWidth = _scrollView.frame.size.width;
    int page = floor((_scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
    _pageControl.currentPage = page;
    if (page == 0) {
        navItem.title = @"Number Pad";
    } else {
        navItem.title = @"Other Commands";
    }
}

- (void) setupScrollView  {
    
    page1 = [[NumberPadViewController alloc] initWithPageTitle:@"numbers"];
    page2 = [[NumberPadViewController alloc] initWithPageTitle:@"commands"];

    int offset;
    float screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    if (screenHeight <= 569) {
        offset = 55; //iphone 5s
    } else if ( screenHeight <= 668 ) {
        offset = 110; //iphone6
    } else {
        offset = 140; //iphone 6+
    }
    
    CGRect frm = [UIScreen mainScreen].bounds;
    frm.origin.y += offset;
    frm.size.height -= offset;
    
    page1.view.frame = frm;
    
    [_scrollView addSubview:page1.view];
    
    frm.origin.x = (1 * frm.size.width);
    page2.view.frame = frm;
    
    [_scrollView addSubview:page2.view];
    
    CGSize frame = frm.size;
    frame.width = frm.size.width * pages;
    
    [_scrollView setContentSize:frame];
    
}
@end
