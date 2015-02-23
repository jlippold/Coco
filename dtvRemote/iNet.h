//
//  iNet.h
//  dtvRemote
//
//  Created by Jed Lippold on 2/22/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ifaddrs.h"
#import <sys/socket.h>
#include <arpa/inet.h>

@interface iNet : NSObject  {
 
}

@property (nonatomic, strong) NSOperationQueue *portScanQueue;

-(NSMutableArray *)findClients;

@end
