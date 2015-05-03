//
//  Command.m
//  dtvRemote
//
//  Created by Jed Lippold on 4/30/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "dtvCommand.h"

@implementation dtvCommand

-(void) setAction:(NSString *) val {
    action = [[NSString alloc]initWithString: val];
}

-(void) setDescription:(NSString *)val {
    description = [[NSString alloc] initWithString: val];
}

- (NSString *) action {
    return action;
}
- (NSString *) description {
    return description;
}

@end
