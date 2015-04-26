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
    __block NSMutableDictionary *clients = [Clients loadClientList];
    
    NSOperationQueue *portScanQueue = [[NSOperationQueue alloc] init];
    portScanQueue.name = @"Scanner";

    __block int completed = 0;
    __block int total = 0;
    
    if ([wifiAddress containsString:@"."]) {
        NSRange range = [wifiAddress rangeOfString:@"." options:NSBackwardsSearch];
        NSString *ssid = [iNet fetchSSID];
        NSString *subnet = [wifiAddress substringToIndex:range.location];
        NSMutableArray *prospectiveClients = [self getCandidates:subnet];
        
        total = (int)[prospectiveClients count];
        
        [portScanQueue cancelAllOperations];
        
        for (NSUInteger i = 0; i < [prospectiveClients count]; i++) {
            NSString *strUrl = [NSString stringWithFormat:@"http://%@:8080/info/getLocations",
                                [prospectiveClients objectAtIndex:i]];
            
            //NSLog(@"scanning %@", [prospectiveClients objectAtIndex:i]);
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
                             NSString *clientId = [NSString stringWithFormat:@"%@-%@", [item objectForKey:@"locationName"], [item objectForKey:@"clientAddr"]];
                             
                             
                             NSDictionary *clientInfo = @{@"id" : clientId,
                                                          @"address" : client,
                                                          @"url": [NSString stringWithFormat:@"http://%@:8080/", client],
                                                          @"name" : [item objectForKey:@"locationName"],
                                                          @"appendage": appendage};
                             
                             if (!clients[ssid]) {
                                 NSMutableDictionary *newClient = [[NSMutableDictionary alloc] init];
                                 [clients setObject:newClient forKey:ssid];
                             }
                             
                             if (!clients[ssid][clientId]) {
                                 [clients[ssid] setObject:[clientInfo mutableCopy] forKey:clientId];
                             }
                         }
                         
                     }
                 }
                 
                 completed++;
                 if (completed == total){
                     [self sendClients:clients];
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
        [self sendClients:clients];
    }
    
}


+ (void) saveClientList:(NSMutableDictionary *) clients {
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

+ (NSMutableDictionary *) loadClientList {
    NSString *key = @"clients";
    NSMutableDictionary *clients = [[NSMutableDictionary alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([savedData objectForKey:key] != nil) {
            //copy to a new mutatable object
            NSMutableDictionary *base = [[savedData objectForKey:key] mutableCopy];
            clients = [base mutableCopy];
        }
    }
    return clients;
}



+ (void) sendClients:(NSMutableDictionary *) clients {
    
    [self saveClientList:clients];
    NSLog(@"%@", clients);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageUpdatedClients" object:clients];
    
}

+ (void) makeRequest:(NSURLRequest*)request queue:(NSOperationQueue*)queue
   completionHandler:(void(^)(NSURLResponse *response, NSData *data, NSError *error))handler
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

+ (NSDictionary *) getClient {
    
    NSMutableDictionary *clients = self.loadClientList;
    NSString *ssid = [iNet fetchSSID];
    NSString *clientId = self.getClientId;
    
    if (!clients[ssid] || [clientId isEqualToString:@""]) {
        return nil;
    }
    
    if (clients[ssid][clientId]) {
        return clients[ssid][clientId];
    } else {
        return nil;
    }
}

+ (NSString *) getClientId {
    NSString *key = @"clientId";
    NSString *clientId = @"";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([savedData objectForKey:key] != nil) {
            clientId = [savedData objectForKey:key];
        }
    }
    
    return  clientId;
}

+ (void) setCurrentClientId:(NSString *)clientId {
    NSString *key = @"clientId";
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    if (clientId != nil) {
        [dataDict setObject:clientId forKey:key];
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:key];
    [NSKeyedArchiver archiveRootObject:dataDict toFile:filePath];
}
@end
