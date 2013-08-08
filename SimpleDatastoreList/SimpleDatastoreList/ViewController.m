//
//  ViewController.m
//  SimpleDatastoreList
//
//  Created by phil on 8/8/13.
//  Copyright (c) 2013 Phil Kast. All rights reserved.
//

#import "ViewController.h"

#define kTableName @"tasks"

@interface ViewController ()

@property (nonatomic) DBDatastore *store;
@property (nonatomic) NSArray *tasks;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    
    // Watch for accounts being linked/unlinked:
    __weak ViewController *weakSelf = self;
    [[DBAccountManager sharedManager] addObserver:self block:^(DBAccount *account) {
        [weakSelf setupAccount];
    }];
    
    [self setupAccount];
}

- (void)reload
{
    self.tasks = nil;
    [self.tableView reloadData];
}

- (void)setupAccount
{
    DBAccount *account = [DBAccountManager sharedManager].linkedAccount;
    
    // Set the login button state
    self.linkButtonItem.title = account != nil ? @"Unlink" : @"Link";
    
    if (account != nil) {
        // Open a data store
        self.store = [DBDatastore openDefaultStoreForAccount:account error:nil];
        
        // Watch for changes and sync them
        __weak ViewController *weakSelf = self;
        [self.store addObserver:self block:^{
            if (weakSelf.store.status & (DBDatastoreOutgoing | DBDatastoreIncoming)) {
                NSDictionary *changes = [weakSelf.store sync:nil];
                NSLog(@"Changes: %@", changes);
                
                [weakSelf reload];
            }
        }];
    } else {
        self.store = nil;
    }
    
    [self reload];
}

- (NSArray *)tasks
{
    if (_tasks == nil && self.store != nil) {
        DBTable *table = [self.store getTable:kTableName];
        _tasks = [table query:nil error:nil];
    }
    
    return _tasks;
}

#pragma mark - UITableView stuff

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.tasks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    DBRecord *task = self.tasks[indexPath.row];
    
    cell.textLabel.text = [task objectForKey:@"name"];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Get the item and delete it
    DBRecord *task = self.tasks[indexPath.row];
    [task deleteRecord];
    [self reload];
}


#pragma mark - UITextFieldDelegate


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    DBTable *table = [self.store getTable:kTableName];
 
    // Insert a new record into the store
    [table insert:@{ @"name": textField.text, @"created": [NSDate date] }];
    
    textField.text = nil;
    [self reload];
    
    return NO;
}


#pragma mark - IBActions


- (IBAction)didTapLinkButton:(id)sender
{
    if ([DBAccountManager sharedManager].linkedAccount == nil) {
        [[DBAccountManager sharedManager] linkFromController:self];
    } else {
        [[DBAccountManager sharedManager].linkedAccount unlink];
    }
}

@end