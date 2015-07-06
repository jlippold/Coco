//
//  dtvIAP.m
//  dtvRemote
//
//  Created by Jed Lippold on 6/9/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "dtvIAP.h"

static NSString *kIdentifierMultiples = @"bz.jed.dtvRemote.multiples";

@implementation dtvIAP

// Obj-C Singleton pattern
+ (dtvIAP *)sharedInstance {
    static dtvIAP *sharedInstance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSSet *productIdentifiers = [NSSet setWithObjects:
                                     kIdentifierMultiples,
                                     nil];
        sharedInstance = [[self alloc] initWithProductIdentifiers:productIdentifiers];
    });
    return sharedInstance;
}


@end
