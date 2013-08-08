//
//  ViewController.m
//  SimpleDatastoreList
//
//  Created by phil on 8/8/13.
//  Copyright (c) 2013 Phil Kast. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic) DBDatastore *store;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    
    // Watch for accounts being linked/unlinked:
    __weak ViewController *weakSelf = self;
    [[DBAccountManager sharedManager] addObserver:self block:^(DBAccount *account) {
        weakSelf.linkButtonItem.title = account.isLinked ? @"Unlink" : @"Link";
        
        if (account.isLinked) {
            self.store = [DBDatastore openDefaultStoreForAccount:account error:nil];
        } else {
            self.store = nil;
        }
        
        [weakSelf reload];
    }];
}

- (void)reload
{
    [self.tableView reloadData];
}

#pragma mark - UITableView stuff

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}


#pragma mark - UITextFieldDelegate


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    
    
    return NO;
}


#pragma mark - IBActions


- (IBAction)didTapLinkButton:(id)sender
{
    if ([DBAccountManager sharedManager].linkedAccount == nil) {
        [[DBAccountManager sharedManager] linkFromController:self];
    }
}

@end