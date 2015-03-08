//
//  Clients.h
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Clients : NSObject

@property (nonatomic, strong) NSOperationQueue *portScanQueue;

- (id)init;
- (void)save:(NSMutableArray *) clients;
- (NSMutableArray *)loadClients;

@end
