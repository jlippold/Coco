//
//  CVCell.h
//  dtvRemote
//
//  Created by Jed Lippold on 7/11/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CVCell : UICollectionViewCell

@property (strong, nonatomic) IBOutlet UILabel *label;
@property (strong, nonatomic) IBOutlet UIImageView *iv;

- (IBAction)tapped:(id)sender;

@end
