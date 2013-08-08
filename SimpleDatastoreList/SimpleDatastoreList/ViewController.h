//
//  ViewController.h
//  SimpleDatastoreList
//
//  Created by phil on 8/8/13.
//  Copyright (c) 2013 Phil Kast. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UITextField *inputField;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *linkButtonItem;

- (IBAction)didTapLinkButton:(id)sender;

@end
