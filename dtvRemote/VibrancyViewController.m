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
    
    [UIApplication sharedApplication].statusBarHidden = NO;
    self.view.frame = [UIScreen mainScreen].bounds;
    
    pages = 2;
    
    
    _scrollView.pagingEnabled = YES;
    _scrollView.delegate = self;
    _scrollView.showsHorizontalScrollIndicator = NO;
    
    CGRect frm = _scrollView.bounds;
    frm.size.width = [UIScreen mainScreen].bounds.size.width;
    frm.size.height = [UIScreen mainScreen].bounds.size.height - 72;
    _scrollView.frame = frm;
    
    
    CGRect navBarFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, 64.0);
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    navbar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    navbar.barTintColor = [Colors navBGColor];
    navbar.translucent = YES;
    navbar.tintColor = [Colors textColor];
    navbar.titleTextAttributes = @{NSForegroundColorAttributeName : [Colors textColor]};
    
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"Close"
                                                       style:UIBarButtonItemStyleDone
                                                      target:self
                                                      action:@selector(dismissView:)];
    

    navItem = [UINavigationItem alloc];
    navItem.title = @"Commands";
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
    [self dismissViewControllerAnimated:YES completion:nil];
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
}

- (void) setupScrollView  {
    
    page1 = [[NumberPadViewController alloc] init];
    page2 = [[NumberPadViewController alloc] init];
    
    CGRect frm = _scrollView.bounds;
    page1.view.frame = frm;
    
    [_scrollView addSubview:page1.view];
    
    frm = _scrollView.bounds;
    frm.origin.x = (1*_scrollView.frame.size.width);
    page2.view.frame = frm;
    
    [_scrollView addSubview:page2.view];
    

    
    CGSize frame = _scrollView.frame.size;
    frame.width = frame.width * pages;
    
    [_scrollView setContentSize:frame];
    
    
}
@end
