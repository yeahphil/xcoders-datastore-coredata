//
//  Task.h
//  CoreDataStoreDemo
//
//  Created by phil on 7/11/13.
//  Copyright (c) 2013 Phil Kast. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Task : NSManagedObject

@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSString * taskname;
@property (nonatomic, retain) NSNumber * completed;

@end
