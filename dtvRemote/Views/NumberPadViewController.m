//
//  NumberPadViewController.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/16/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "NumberPadViewController.h"
#import "dtvCommands.h"
#import "dtvCommand.h"
#import "dtvDevices.h"

@interface NumberPadViewController ()

@end

@implementation NumberPadViewController {
    NSMutableDictionary *commands;
    NSString *pageTitle;
}

- (id) initWithPageTitle:(NSString *)title {
    pageTitle = title;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    commands = [dtvCommands getCommandsForNumberPad];
    
    //set 12 button / label properties
    for (int n = 1; n <= 15; n++) {
        UIButton *button = (UIButton *)[self.view viewWithTag:n + 100];
        BOOL isRoundButton = n <= 12 ? YES : NO;
        UILabel *label;
        button.hidden = YES;
        
        if (isRoundButton) {
            label = (UILabel *)[self.view viewWithTag:n + 200];
            label.hidden = YES;
            button.layer.borderColor = [UIColor whiteColor].CGColor;
            button.layer.borderWidth = 2.0f;
            button.layer.cornerRadius = 40;
            button.layer.masksToBounds = YES;
        } else { //bottom buttons
            button.layer.cornerRadius = 4;
            button.layer.masksToBounds = YES;
        }
        
        
        dtvCommand *command = [dtvCommands getCommandAtnumberPadPagePosition:commands
                                                                        page:pageTitle
                                                                    position:[@(n) stringValue]];
        if (command) {
            button.hidden = NO;
            if (isRoundButton) {
                label.hidden = NO;
                label.text = command.commandDescription;
                [button setTitle:command.shortName forState:UIControlStateNormal];
            } else {
                [button setTitle:command.commandDescription forState:UIControlStateNormal];
            }
        }

        
        [button addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(buttonRemoveHighlight:) forControlEvents:UIControlEventTouchUpInside];
        [button addTarget:self action:@selector(buttonRemoveHighlight:) forControlEvents:UIControlEventTouchUpOutside];

    }
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction) tapped:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.backgroundColor = [UIColor whiteColor];
    
    NSString *position = [@(button.tag-100) stringValue];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        dtvCommand *command = [dtvCommands getCommandAtnumberPadPagePosition:commands
                                                                        page:pageTitle
                                                                    position:position];
        
        dtvDevice *currentDevice = [dtvDevices getCurrentDevice];
        [dtvCommands sendCommand:command.dtvCommandText device:currentDevice];

    });
}

-(IBAction) buttonRemoveHighlight:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.backgroundColor = [UIColor clearColor];
}


@end
