#import "InputTaskCell.h"
#import "TasksController.h"
#import "TaskCell.h"
#import <Dropbox/Dropbox.h>

@interface TasksController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic, retain) InputTaskCell *inputTaskCell;

@end

@implementation TasksController

- (void)viewDidLoad {
    [super viewDidLoad];

	self.tableView.rowHeight = 50.0f;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}

#pragma mark -
#pragma mark Account linking

- (IBAction)didPressLink {
	[[DBAccountManager sharedManager] linkFromController:self];
}

- (IBAction)didPressUnlink {
	[[[DBAccountManager sharedManager] linkedAccount] unlink];
	[self.tableView reloadData];
}

#pragma mark -
#pragma mark NSFetchedResultsController stuff

- (NSFetchedResultsController *)fetchedResultsController
{
    if (!_fetchedResultsController) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Task"];
        fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"created" ascending:YES]];
        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                            managedObjectContext:self.managedObjectContext
                                                                              sectionNameKeyPath:nil
                                                                                       cacheName:nil];
        _fetchedResultsController.delegate = self;
        
        
        NSError *error = nil;
        [_fetchedResultsController performFetch:&error];
        if (error) {
            NSLog(@"Error while performing initial fetch: %@", error);
        }
    }
    
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
    switch (type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case NSFetchedResultsChangeUpdate:
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            break;
        case NSFetchedResultsChangeMove:
            [self.tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
            break;
        default:
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

#pragma mark -
#pragma mark UITableViewDataSource methods

- (NSInteger)numberOfTasks
{
    return [self.fetchedResultsController.sections[0] numberOfObjects];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger sectionCount = self.fetchedResultsController.sections.count;
	return MIN(sectionCount, 1);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (![DBAccountManager sharedManager].linkedAccount) {
		return 1;
	} else {
		return self.numberOfTasks + 2;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSInteger taskCount = self.numberOfTasks;
    
	if (![DBAccountManager sharedManager].linkedAccount) {
		return [tableView dequeueReusableCellWithIdentifier:@"LinkCell"];
	} else if (indexPath.row == taskCount) {
		if (!_inputTaskCell) {
			_inputTaskCell = [tableView dequeueReusableCellWithIdentifier:@"InputTaskCell"];
		}
		return _inputTaskCell;
	} else if (indexPath.row == taskCount+1) {
		return [tableView dequeueReusableCellWithIdentifier:@"UnlinkCell"];
	} else {
        TaskCell *taskCell = [tableView dequeueReusableCellWithIdentifier:@"TaskCell" forIndexPath:indexPath];

        Task *task = [self.fetchedResultsController objectAtIndexPath:indexPath];
		taskCell.taskLabel.text = task.taskname;
		UIView *checkmark = taskCell.taskCompletedView;
        checkmark.hidden = ![task.completed boolValue];
        
		return taskCell;
	}
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSInteger taskCount = self.numberOfTasks;

	if ([DBAccountManager sharedManager].linkedAccount) {
		if (indexPath.row == taskCount) {
			[self.inputTaskCell.textField becomeFirstResponder];
		} else {
			Task *task = [self.fetchedResultsController objectAtIndexPath:indexPath];
			task.completed = [task.completed boolValue] ? @NO : @YES;
            
            NSError *error = nil;
            [self.managedObjectContext save:&error];
            if (error) {
                NSLog(@"Error while saving during task complete: %@", error);
            }
		}
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return [DBAccountManager sharedManager].linkedAccount && indexPath.row < [self.fetchedResultsController.sections[0] numberOfObjects];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    Task *task = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    [self.managedObjectContext deleteObject:task];
    
    NSError *error = nil;
    [self.managedObjectContext save:&error];
    if (error) {
        NSLog(@"Error while deleting object: %@", error);
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 60.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	return self.headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	return 24.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	return [UIView new];
}


#pragma mark - UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if ([textField.text length]) {
        Task *task = [NSEntityDescription insertNewObjectForEntityForName:@"Task" inManagedObjectContext:self.managedObjectContext];
        task.taskname = textField.text;
        task.completed = @NO;
        task.created = [NSDate date];

        NSError *error = nil;
        [self.managedObjectContext save:&error];
        if (error) {
            NSLog(@"Error while saving: %@", error);
        }
        
		textField.text = nil;
	}
	
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.numberOfTasks inSection:0];
	[self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

@end
