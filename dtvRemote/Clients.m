//
//  Clients.m
//  dtvRemote
//
//  Created by Jed Lippold on 3/2/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "Clients.h"
#import "iNet.h"

@implementation Clients

+ (void)searchWifiForDevices {
    

    NSString *wifiAddress = [iNet getWifiAddress];
    NSOperationQueue *portScanQueue = [[NSOperationQueue alloc] init];
    portScanQueue.name = @"Scanner";
    
    NSMutableArray *foundClients = [[NSMutableArray alloc] init];
    
    __block int completed = 0;
    __block int total = 0;
    
    if ([wifiAddress containsString:@"."]) {
        NSRange range = [wifiAddress rangeOfString:@"." options:NSBackwardsSearch];
        NSString *subnet = [wifiAddress substringToIndex:range.location];
        NSMutableArray *prospectiveClients = [self getCandidates:subnet];
        
        
        total = (int)[prospectiveClients count];
        
        [portScanQueue cancelAllOperations];
        
        for (NSUInteger i = 0; i < [prospectiveClients count]; i++) {
            NSString *strUrl = [NSString stringWithFormat:@"http://%@:8080/info/getLocations",
                                [prospectiveClients objectAtIndex:i]];
            
            //NSLog(@"scanning %@", [addresses objectAtIndex:i]);
            NSURL *url = [NSURL URLWithString:strUrl];
            
            NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url
                                                          cachePolicy:1
                                                      timeoutInterval:3];
            
            [self makeRequest:request queue:portScanQueue completionHandler:
             ^(NSURLResponse *response, NSData *data, NSError *connectionError)
             {
                 id client = [prospectiveClients objectAtIndex:i];
                 if (data.length > 0 && connectionError == nil) {
                     NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                     if (json[@"locations"]) {
                         for (id item in json[@"locations"]) {
                             NSString *appendage = @"";
                             if (![[item objectForKey:@"clientAddr"] isEqualToString:@"0"]) {
                                 appendage = [NSString stringWithFormat:@"clientAddr=%@",
                                              [item objectForKey:@"clientAddr"]];
                             }
                             
                             NSDictionary *clientInfo = @{@"address" : client,
                                                          @"url": [NSString stringWithFormat:@"http://%@:8080/", client],
                                                          @"name" : [item objectForKey:@"locationName"],
                                                          @"appendage": appendage};
                             
                             [foundClients addObject:clientInfo];
                         }
                         
                     }
                 }
                 
                 completed++;
                 if (completed == total){
                     [self sendClients:foundClients];
                     NSLog(@"Completed Scanning");
                 } else {
                     long double progress =(completed*1.0/total*1.0);
                     NSNumber *nsprogress = [NSNumber numberWithDouble:progress];
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedClientsProgress"
                                                                         object:nsprogress];
                 }
             }];
        }
    } else {
        [self sendClients:foundClients];
    }
    
}


+ (void) save:(NSMutableArray *) clients {
    NSString *key = @"clients";
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    if (clients != nil) {
        [dataDict setObject:clients forKey:key];
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    [NSKeyedArchiver archiveRootObject:dataDict toFile:filePath];
}

+ (NSMutableArray *) load {
    NSString *key = @"clients";
    NSMutableArray *clients = [[NSMutableArray alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([savedData objectForKey:key] != nil) {
            clients = [[NSMutableArray alloc] initWithArray:[savedData objectForKey:key] copyItems:YES];
        }
    }
    return clients;
}



+ (void) sendClients:(NSMutableArray*) clients {
    
    [self save:clients];
    
    iNet* inet = [[iNet alloc] init];
    NSString *ssid = [inet fetchSSID];
    inet = nil;
    
    NSMutableDictionary *netClients = [[NSMutableDictionary alloc] init];
    [netClients setObject:clients forKey:ssid];
    NSLog(@"%@", netClients);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedClients" object:clients];
    
}

+ (void) makeRequest:(NSURLRequest*)request queue:(NSOperationQueue*)queue completionHandler:(void(^)(NSURLResponse *response, NSData *data, NSError *error))handler
{
    __block NSURLResponse *response = nil;
    __block NSError *error = nil;
    __block NSData *data = nil;
    
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        data = [NSURLConnection sendSynchronousRequest:request
                                     returningResponse:&response
                                                 error:&error];
    }];
    
    blockOperation.completionBlock = ^{
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            handler(response, data, error);
        }];
    };
    
    [queue addOperation:blockOperation];
}



+ (NSMutableArray *) getCandidates:(NSString *)subnet {
    NSMutableArray *range = [[NSMutableArray alloc] init];
    for (NSUInteger i = 1; i < 256; i++) {
        [range addObject:[subnet stringByAppendingString:[NSString stringWithFormat:@".%@",  @(i)]]];
    }
    return range;
}

@end
