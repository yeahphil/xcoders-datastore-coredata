//
//  PKDataStoreAtomicStore.m
//  CoreDataStoreDemo
//
//  Created by phil on 7/11/13.
//  Copyright (c) 2013 Phil Kast. All rights reserved.
//

#import "PKDataStoreAtomicStore.h"
#import "PKDataStoreAtomicStoreCacheNode.h"
#import <InflectorKit/NSString+InflectorKit.h>
#import <Dropbox/Dropbox.h>
#import <objc/runtime.h>

static const char *PKDataStoreRecordIdentifier = "__PKDataStoreRecordIdentifier";

@interface PKDataStoreAtomicStore () {
    DBDatastore *_store;
}

@property (nonatomic) NSManagedObjectContext *syncContext;

@end

@implementation PKDataStoreAtomicStore

+ (void)initialize
{
    [NSPersistentStoreCoordinator registerStoreClass:[self class] forStoreType:[self type]];
}

+ (NSString *)type
{
    return NSStringFromClass(self);
}


- (NSString *)type
{
    return [[self class] type];
}

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator configurationName:(NSString *)configurationName URL:(NSURL *)url options:(NSDictionary *)options
{
    self = [super initWithPersistentStoreCoordinator:coordinator configurationName:configurationName URL:[NSURL URLWithString:@"arbitrary://foo"] options:options];
    if (self != nil) {
        self.syncContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [self.syncContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    
    return self;
}

#pragma mark -
#pragma mark NSAtomicStore mandatory overrides

- (BOOL)loadMetadata:(NSError *__autoreleasing *)error
{
    if (self.account == nil) {
        *error = [[NSError alloc] initWithDomain:PKDataStoreAtomicStoreErrorDomain
                                            code:0
                                        userInfo:@{NSLocalizedDescriptionKey: @"No linked account"}];
        return NO;
    } else {
        self.metadata = @{
                          NSStoreUUIDKey: [[NSProcessInfo processInfo] globallyUniqueString],
                          NSStoreTypeKey: [[self class] type]
                          };
        return YES;
    }
}


- (BOOL)load:(NSError **)error
{
    // Can't create the store until there's an account...
    if (self.account == nil) {
        *error = [[NSError alloc] initWithDomain:PKDataStoreAtomicStoreErrorDomain
                                            code:0
                                        userInfo:@{NSLocalizedDescriptionKey: @"No linked account"}];
        return NO;
    } else {
        NSArray *tables = [self.store getTables:nil];
        for (DBTable *table in tables) {
            if (![self loadTable:table]) {
                return NO;
            };
        }
        return YES;
    }
}


- (NSAtomicStoreCacheNode *)newCacheNodeForManagedObject:(NSManagedObject *)managedObject
{
    PKDataStoreAtomicStoreCacheNode *node = [[PKDataStoreAtomicStoreCacheNode alloc] initWithObjectID:managedObject.objectID];
    NSString *tableName = [self tableNameForEntityName:managedObject.entity.name];
    NSString *recordId = [self referenceObjectForObjectID:managedObject.objectID];
    
    DBTable *table = [self.store getTable:tableName];
    DBRecord *record = [table getRecord:recordId error:nil];
    
    node.propertyCache = [record.fields mutableCopy];
    node.tableId = table.tableId;
    node.recordId = record.recordId;
    
    return node;
}

// Use the recordId as the reference object
// This requires inserting
- (id)newReferenceObjectForManagedObject:(NSManagedObject *)managedObject
{
    if (managedObject == nil) {
        return nil;
    }
    
    NSString *tableName = [self tableNameForEntityName:managedObject.entity.name];
    DBTable *table = [self.store getTable:tableName];
    
    NSDictionary *properties = [self propertiesForManagedObject:managedObject];
    
    DBRecord *record = [self recordForManagedObject:managedObject table:table];
    if (record) {
        // Exists... update if necessary
        // These gymnastics are necessary to prevent object changes from syncs from 
        [self updateChangedFields:properties onRecord:record];
    } else {
        // Doesn't exist. Insert, then set the identifier on the managed object.
        record = [table insert:properties];
        [self setIdentifierForRecord:record managedObject:managedObject];
    }
    
    return record.recordId;
}

- (BOOL)save:(NSError **)error
{
    [self.store sync:nil];
    return YES;
}

// Copy changes to managedObject back into the backing DBRecord
- (void)updateCacheNode:(PKDataStoreAtomicStoreCacheNode *)node fromManagedObject:(NSManagedObject *)managedObject
{
    if (![node isKindOfClass:[PKDataStoreAtomicStoreCacheNode class]]) {
        NSLog(@"Bad cached node!");
        return;
    }
    
    DBTable *table = [self.store getTable:node.tableId];
    DBError *dbError = nil;
    DBRecord *record = [table getRecord:node.recordId error:nil];
    
    if (dbError) {
        NSLog(@"error fetching backing record: %@", dbError);
    } else {
        // update the property cache
        for (id key in [node.propertyCache allKeys]) {
            id value = [managedObject valueForKey:key];
            if (key) {
                node.propertyCache[key] = value;
            }
        }

        // update the backing store
        [self updateChangedFields:node.propertyCache onRecord:record];
    }
}

- (void)willRemoveCacheNodes:(NSSet *)cacheNodes
{
    for (PKDataStoreAtomicStoreCacheNode *node in cacheNodes) {
        DBTable *table = [self.store getTable:node.tableId];
        DBRecord *record = [table getRecord:node.recordId error:nil];
        [record deleteRecord];
    }
}

#pragma mark -
#pragma mark Internals

// Load cache nodes for each record in a table
// WARN: Proof of concept only, slow, relatively big memory footprint, not great for real world use
- (BOOL)loadTable:(DBTable *)table
{
    NSArray *records = [table query:nil error:nil];
    NSMutableSet *cacheNodes = [NSMutableSet setWithCapacity:records.count];
    
    NSEntityDescription *entity = [self entityForTableName:table.tableId];
    
    if (!entity) {
        return NO;
    }
    
    for (DBRecord *record in records) {
        PKDataStoreAtomicStoreCacheNode *node = [self cacheNodeForEntity:entity record:record];
        [cacheNodes addObject:node];
    }
    
    [self addCacheNodes:cacheNodes];
    
    return YES;
}

// Create a new cache node from a DataStore record
- (PKDataStoreAtomicStoreCacheNode *)cacheNodeForEntity:(NSEntityDescription *)entity record:(DBRecord *)record
{
    NSManagedObjectID *objectID = [self objectIDForEntity:entity referenceObject:record.recordId];
    PKDataStoreAtomicStoreCacheNode *node = [[PKDataStoreAtomicStoreCacheNode alloc] initWithObjectID:objectID];
    node.propertyCache = [record.fields mutableCopy];
    node.recordId = record.recordId;
    node.tableId = record.table.tableId;
    
    return node;
}

- (void)setIdentifierForRecord:(DBRecord *)record managedObject:(NSManagedObject *)managedObject
{
    NSString *recordId = record.recordId;
    objc_setAssociatedObject(managedObject, PKDataStoreRecordIdentifier, recordId, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)identifierForManagedObject:(NSManagedObject *)managedObject
{
    id identifier = objc_getAssociatedObject(managedObject, PKDataStoreRecordIdentifier);

    return identifier;
}

- (DBRecord *)recordForManagedObject:(NSManagedObject *)managedObject table:(DBTable *)table
{
    NSString *recordId = [self identifierForManagedObject:managedObject];
    
    if (recordId == nil) {
        return nil;
    } else {
        return [table getRecord:recordId error:nil];
    }
}

- (NSDictionary *)propertiesForManagedObject:(NSManagedObject *)managedObject
{
    NSArray *propertyList = [[managedObject.entity propertiesByName] allKeys];
    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:propertyList.count];
    
    for (NSString *propertyName in propertyList) {
        id prop = [managedObject valueForKey:propertyName];
        if (prop) {
            properties[propertyName] = prop;
        }
    }
    
    return properties;
}

- (void)updateChangedFields:(NSDictionary *)potentialChanges onRecord:(DBRecord *)record
{
    for (id key in [potentialChanges allKeys]) {
        id value  = potentialChanges[key];
        if (![value isEqual:record.fields[key]]) {
            if (value != nil) {
                [record setObject:value forKey:key];
            } else {
                [record removeObjectForKey:key];
            }
        }
    }
}

#pragma mark -
#pragma mark Translators

- (NSString *)tableNameForEntityName:(NSString *)entityName
{
    return [[entityName lowercaseString] pluralizedString];
}

- (NSEntityDescription *)entityForTableName:(NSString *)tableName
{
    NSString *name = [[tableName singularizedString] capitalizedString];
    
    return [[self.persistentStoreCoordinator.managedObjectModel entitiesByName] objectForKey:name];
}

#pragma mark -
#pragma mark Syncing

- (void)processChanges:(NSDictionary *)changeDict
{
    NSLog(@"change dict: %@", changeDict);
    
    for (id key in [changeDict allKeys]) {
        NSEntityDescription *entity = [self entityForTableName:key];
        
        for (DBRecord *record in changeDict[key]) {
            NSManagedObjectID *objectId = [self objectIDForEntity:entity referenceObject:record.recordId];
            
            [self.syncContext performBlockAndWait:^{
                NSManagedObject *managedObject = [self.syncContext existingObjectWithID:objectId error:nil];
                if (record.isDeleted && managedObject != nil) {
                    // a delete
                    [self.syncContext deleteObject:managedObject];
                } else {
                    // an insert or update
                    if (managedObject == nil || managedObject.objectID.isTemporaryID) {
                        // Insert a new managed object
                        // This is OK, because newCacheNodeForManagedObject and newReferenceObjectForManagedObject won't be called until the context is saved.
                        managedObject = [NSEntityDescription insertNewObjectForEntityForName:entity.name inManagedObjectContext:self.syncContext];

                        // For an object created from an external sync,
                        // set the record identifier by hand, so that we can detect and avoid creating duplicate records in the backing store
                        [self setIdentifierForRecord:record managedObject:managedObject];
                    }
                    
                    for (id fieldKey in record.fields.allKeys) {
                        [managedObject setValue:record.fields[fieldKey] forKey:fieldKey];
                    }
                }
            }];
        }
        
        [self.syncContext performBlockAndWait:^{
            NSError *error = nil;
            [self.syncContext save:&error];
            if (error) {
                NSLog(@"save error: %@", error);
            }
        }];
    }
    
}

#pragma mark -
#pragma mark helpers

- (DBAccount *)account
{
    return [DBAccountManager sharedManager].linkedAccount;
}

- (DBDatastore *)store {
    if (!_store) {
        _store = [DBDatastore openDefaultStoreForAccount:self.account error:nil];
        [self setupObservation];
    }
    return _store;
}

- (void)setupObservation
{
    __weak PKDataStoreAtomicStore *weakSelf = self;
    [_store addObserver:self block:^{
        PKDataStoreAtomicStore *self = weakSelf;
        
        if (self.store.status & (DBDatastoreIncoming | DBDatastoreOutgoing)) {
            NSDictionary *changeDict = [self.store sync:nil];
            [self processChanges:changeDict];
        }
    }];
}

#pragma mark -

- (void)dealloc
{
    [_store removeObserver:self];
}

@end
