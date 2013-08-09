//
//  PKAppDelegate.m
//  CoreDataStoreDemo
//
//  Created by phil on 7/10/13.
//  Copyright (c) 2013 Phil Kast. All rights reserved.
//

#import "AppDelegate.h"
#import <Dropbox/Dropbox.h>
#import "TasksController.h"
#import "PKDataStoreAtomicStore.h"

@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    
	[DBAccountManager setSharedManager:[[DBAccountManager alloc] initWithAppKey:@"4prvgra1hf7e5ke" secret:@"z4743oim2x95xfk"]];
    [self resetDatastore];
    
	UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Storyboard" bundle:nil];
	TasksController *root = (TasksController *)[storyboard instantiateInitialViewController];
    root.managedObjectContext = self.managedObjectContext;
    self.window.rootViewController = root;
    
    [self.window makeKeyAndVisible];
    
    return YES;
}


- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
	
	[[DBAccountManager sharedManager] handleOpenURL:url];
	
	return YES;
}


- (void)applicationWillTerminate:(UIApplication *)application
{
    [self saveContext];
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

- (void)resetDatastore
{
    DBDatastore *store = [DBDatastore openDefaultStoreForAccount:[DBAccountManager sharedManager].linkedAccount error:nil];
    for (DBTable *table in [store getTables:nil]) {
        for (DBRecord *record in [table query:@{} error:nil]) {
            [record deleteRecord];
        }
    }
    
    DBError *error = nil;
    [store sync:&error];
    if (error) {
        NSLog(@"Error: %@", error);
    } else {
        NSLog(@"Reset store...");
    }
}


#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
        [_managedObjectContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeChangesFromContextDidSaveNotification:) name:NSManagedObjectContextDidSaveNotification object:nil];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"CoreDataStoreDemo" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"CoreDataStoreDemo.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:[PKDataStoreAtomicStore type] configuration:nil URL:nil options:nil error:&error]) {
        NSLog(@"error creating store: %@", error);
        [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
    }
    
    return _persistentStoreCoordinator;
}

// Merge changes onto main context
// Note that this has to be done on the main thread
// (Otherwise you've violated CoreData threading rules, and in practice will fire off NSFetchedResultsController
// methods on a background thread)
- (void)mergeChangesFromContextDidSaveNotification:(NSNotification *)notification
{
    [self.managedObjectContext performBlock:^{
        [self.managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
    }];
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
