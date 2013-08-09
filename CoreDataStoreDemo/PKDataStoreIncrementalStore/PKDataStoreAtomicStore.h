//
//  PKDataStoreAtomicStore.h
//  CoreDataStoreDemo
//
//  Created by phil on 7/11/13.
//  Copyright (c) 2013 Phil Kast. All rights reserved.
//

#import <CoreData/CoreData.h>

#define PKDataStoreAtomicStoreErrorDomain @"PKDataStoreAtomicStoreErrorDomain" 

@interface PKDataStoreAtomicStore : NSAtomicStore

+ (NSString *)type;

@end
