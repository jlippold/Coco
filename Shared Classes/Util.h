//
//  Util.h
//  dtvRemote
//
//  Created by Jed Lippold on 7/5/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Util : NSObject

+ (void) saveObjectToDisk:(id)obj key:(NSString *)key;
+ (id) loadObjectFromDisk:(NSString *)key objectType:(NSString *)objectType;
+ (id) getDocumentsDirectory;

@end
