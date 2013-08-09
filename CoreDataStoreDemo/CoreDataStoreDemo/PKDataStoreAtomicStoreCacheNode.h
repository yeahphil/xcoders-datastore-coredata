//
//  PKDataStoreAtomicStoreCacheNode.h
//  CoreDataStoreDemo
//
//  Created by phil on 7/12/13.
//  Copyright (c) 2013 Phil Kast. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface PKDataStoreAtomicStoreCacheNode : NSAtomicStoreCacheNode

@property (nonatomic, copy) NSString *tableId;
@property (nonatomic, copy) NSString *recordId;

@end
