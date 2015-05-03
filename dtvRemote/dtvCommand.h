//
//  Command.h
//  dtvRemote
//
//  Created by Jed Lippold on 4/30/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface dtvCommand : NSObject {
    NSString *action;
    NSString *description;
}

-(void) setAction:(NSString *) val;
-(void) setDescription:(NSString *) val;
-(NSString *) action;
-(NSString *) description;

@end
