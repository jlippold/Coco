//
//  Util.m
//  dtvRemote
//
//  Created by Jed Lippold on 7/5/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "Util.h"

@implementation Util

+ (void) saveObjectToDisk:(id)obj key:(NSString *)key {

    if (obj == nil) {
        return;
    }
        
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    [dataDict setObject:obj forKey:key];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *storeUrl = [fileManager containerURLForSecurityApplicationGroupIdentifier:@"group.dtvRemote.shares"];
    NSString *groupPath = [[storeUrl absoluteString] substringFromIndex:6];
    NSString *filePath = [groupPath stringByAppendingPathComponent:key];
    
    [NSKeyedArchiver archiveRootObject:dataDict toFile:filePath];
}


+ (id) loadObjectFromDisk:(NSString *)key objectType:(NSString *)objectType {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *storeUrl = [fileManager containerURLForSecurityApplicationGroupIdentifier:@"group.dtvRemote.shares"];
    NSString *groupPath = [[storeUrl absoluteString] substringFromIndex:6];
    
    NSString *filePath = [groupPath stringByAppendingPathComponent:key];
    id returnedObj;
    if ([objectType isEqualToString:@"NSMutableDictionary"]) {
        returnedObj = [[NSMutableDictionary alloc] init];
    }
    if ([objectType isEqualToString:@"NSString"]) {
        returnedObj = [[NSString alloc] init];
    }
    if ([objectType isEqualToString:@"NSMutableArray"]) {
        returnedObj = [[NSMutableArray alloc] init];
    }
    
    if ([objectType isEqualToString:@"NSMutableArrayWithNil"]) {
        returnedObj = nil;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        id savedData = [NSKeyedUnarchiver unarchiveObjectWithData:data];

        if ([savedData objectForKey:key] != nil) {
            NSMutableDictionary *base = [[savedData objectForKey:key] mutableCopy];
            returnedObj = [base mutableCopy];
        }
    
    }
    return returnedObj;
}

+ (id) getDocumentsDirectory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *storeUrl = [fileManager containerURLForSecurityApplicationGroupIdentifier:@"group.dtvRemote.shares"];
    NSString *groupPath = [[storeUrl absoluteString] substringFromIndex:6];
    
    return groupPath;
}

@end
