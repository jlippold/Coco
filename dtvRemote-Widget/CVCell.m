//
//  CVCell.m
//  dtvRemote
//
//  Created by Jed Lippold on 7/11/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "CVCell.h"
#import "dtvCommands.h"
#import "dtvCustomCommand.h"
#import "SharedVars.h"

@implementation CVCell


- (void)awakeFromNib {
    // Initialization code
}

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        NSArray *arrayOfViews = [[NSBundle mainBundle] loadNibNamed:@"CVCell" owner:self options:nil];
        
        if ([arrayOfViews count] < 1) {
            return nil;
        }
        
        if (![[arrayOfViews objectAtIndex:0] isKindOfClass:[UICollectionViewCell class]]) {
            return nil;
        }
        
        self = [arrayOfViews objectAtIndex:0];
    }
    return self;
    
}

- (IBAction)tapped:(id)sender {
    
    NSInteger tag = [(UIGestureRecognizer *)sender view].tag;
    NSInteger idx;
    
    if (tag < 200) {
        idx = tag - 100;
        NSString *chId = [[SharedVars sharedInstance].favoriteChannels objectAtIndex:idx];
        dtvChannel *channel = [SharedVars sharedInstance].channels[chId];
        [dtvCommands changeChannel:channel device:[SharedVars sharedInstance].currentDevice];
    } else {
        idx = tag - 200;
        
        id obj = [[SharedVars sharedInstance].favoriteCommands objectAtIndex:idx];
        if ([obj isKindOfClass:[dtvCommand class]]) {
            dtvCommand *c = [[SharedVars sharedInstance].favoriteCommands objectAtIndex:idx];
            [dtvCommands sendCommand:c.dtvCommandText device:[SharedVars sharedInstance].currentDevice];
        } else {
            dtvCustomCommand *c = [[SharedVars sharedInstance].favoriteCommands objectAtIndex:idx];
            [dtvCommands sendCustomCommand:c];
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageStartSpinner" object:nil];


}

@end
