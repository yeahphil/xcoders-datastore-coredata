#import <UIKit/UIKit.h>

@interface TasksController : UITableViewController

- (IBAction)didPressLink;
- (IBAction)didPressUnlink;

@property (nonatomic, weak) IBOutlet UIView *headerView;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@end
