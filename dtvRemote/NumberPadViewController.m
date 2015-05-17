//
//  NumberPadViewController.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/16/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "NumberPadViewController.h"

@interface NumberPadViewController ()

@end

@implementation NumberPadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //button tap events
    for (int n = 1; n <= 12; n++) {
        
        int tag = n + 100;
        UIButton *button = (UIButton *)[self.view viewWithTag:tag];
        button.layer.borderColor = [UIColor whiteColor].CGColor;
        button.layer.borderWidth = 2.0f;
        button.layer.cornerRadius = 40;
        button.layer.masksToBounds = YES;
        [button setTitle:[NSString stringWithFormat:@"%d", n] forState:UIControlStateNormal];

        [button addTarget:self action:@selector(buttonHighlight:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(buttonRemoveHighlight:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    //labels
    for (int n = 1; n <= 12; n++) {
        int tag = n + 200;
        UILabel *label= (UILabel *)[self.view viewWithTag:tag];
        label.text = [NSString stringWithFormat:@"Label %d", n];
    }
    
    //bottom 3
    for (int n = 1; n <= 3; n++) {
        UIButton *button = (UIButton *)[self.view viewWithTag:n];
        button.layer.cornerRadius = 4;
        button.layer.masksToBounds = YES;
        [button setTitle:[NSString stringWithFormat:@"bottom %d", n] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(buttonHighlight:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(buttonRemoveHighlight:) forControlEvents:UIControlEventTouchUpInside];
    }
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction) buttonHighlight:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.backgroundColor = [UIColor whiteColor];

}

-(IBAction) buttonRemoveHighlight:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.backgroundColor = [UIColor clearColor];
}


@end
