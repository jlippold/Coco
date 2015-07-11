//
//  RightViewController.m
//  dtvRemote
//
//  Created by Jed Lippold on 5/10/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "RightViewController.h"
#import "dtvDevices.h"
#import "dtvCommands.h"
#import "dtvCommand.h"
#import "dtvCustomCommand.h"
#import "Colors.h"
#import "UIImage+FontAwesome.h"

@interface RightViewController ()

@end

@implementation RightViewController {
    NSMutableDictionary *commands;
    UIView *sideBarView;
    UITableView *sideBarTable;
    dtvDevice *currentDevice;
    UINavigationItem *sideBarNavItem;
    BOOL isEditing;
    IBOutlet UIBarButtonItem *favButton;
    NSMutableArray *favoriteCommands;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    currentDevice = [dtvDevices getCurrentDevice];
    commands = [dtvCommands getCommandsForSidebar:currentDevice];
    favoriteCommands = [dtvCommands loadFavoriteCommands];
    
    if (!favoriteCommands) {
        favoriteCommands = [[NSMutableArray alloc] init];
    }
    
    isEditing = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedCurrentDevice:)
                                                 name:@"messageUpdatedCurrentDevice" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageImportedCustomCommands:)
                                                 name:@"messageImportedCustomCommands" object:nil];
    
    sideBarView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    sideBarView.backgroundColor = [Colors backgroundColor];
    
    CGRect navBarFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width * 0.75, 64.0);
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    bar.translucent = NO;
    bar.tintColor = [Colors tintColor];
    bar.barTintColor = [Colors navBGColor];
    bar.titleTextAttributes = @{NSForegroundColorAttributeName : [Colors textColor]};
    
    sideBarNavItem = [UINavigationItem alloc];
    
    if (currentDevice) {
        sideBarNavItem.title = currentDevice.name;
    } else {
        sideBarNavItem.title = @"Remote Commands";
    }
    
    
    favButton = [[UIBarButtonItem alloc]
                                  initWithImage:[UIImage imageNamed:@"images.bundle/favorite"]
                                  style:UIBarButtonItemStylePlain target:self action:@selector(chooseFavorites:)];
    
    favButton.tintColor = [Colors textColor];
    sideBarNavItem.rightBarButtonItem = favButton;
    
    [bar pushNavigationItem:sideBarNavItem animated:false];
    
    
    [sideBarView addSubview:bar];
    
    CGRect tableFrame = [[UIScreen mainScreen] bounds];
    tableFrame.size.width = tableFrame.size.width * 0.75;
    tableFrame.size.height = tableFrame.size.height - 64;
    tableFrame.origin.x = 0;
    tableFrame.origin.y = 64;
    sideBarTable = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStyleGrouped];
    sideBarTable.frame = tableFrame;
    
    sideBarTable.dataSource = self;
    sideBarTable.delegate = self;
    sideBarTable.separatorColor = [Colors seperatorColor];
    sideBarTable.backgroundColor = [UIColor clearColor];
    
    [sideBarView addSubview:sideBarTable];
    
    [self.view addSubview:sideBarView];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)chooseFavorites:(id)sender {
    if (isEditing) {
        //Going back to regular mode
        [dtvCommands saveFavoriteCommands:favoriteCommands];
        favButton.image = [UIImage imageNamed:@"images.bundle/favorite"];
        isEditing = NO;
    } else {
        //Going into edit mode
        favButton.image = [UIImage imageNamed:@"images.bundle/favortite-selected"];
        isEditing = YES;
    }
    
    [sideBarTable reloadData];
}


#pragma mark - TableView Management

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.indentationLevel = 1;
    cell.indentationWidth = 2;
    cell.backgroundColor = [Colors backgroundColor];
    cell.userInteractionEnabled = YES;
    [cell setTintColor:[Colors tintColor]];
    
    [cell.textLabel setTextColor: [Colors textColor]];
    [cell.detailTextLabel setTextColor:[Colors textColor]];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *v = (UITableViewHeaderFooterView *)view;
    v.backgroundView.backgroundColor = [Colors backgroundColor];
    v.backgroundView.alpha = 0.9;
    v.backgroundView.tintColor = [Colors tintColor];
    
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setTextColor:[Colors textColor]];
    
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray *sections = [[commands allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return [sections objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *sections = [[commands allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *sectionKey = [sections objectAtIndex:section];
    return [[commands objectForKey:sectionKey] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CellPicker"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CellPicker"];
    }
    
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    cell.userInteractionEnabled = YES;
    cell.detailTextLabel.enabled = YES;
    
    NSArray *sections = [[commands allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *sectionKey = [sections objectAtIndex:indexPath.section];
    NSMutableArray *commandArray = [commands objectForKey:sectionKey];
    
    NSArray *sortedArray = [commandArray sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *first = [(id) a sideBarSortIndex];
        NSString *second = [(id) b sideBarSortIndex];
        return [first compare:second];
    }];
    
    id obj = [sortedArray objectAtIndex:indexPath.row];
    BOOL isFavorite = NO;
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *cellImage;
    
    if ([obj isKindOfClass:[dtvCommand class]]) {
        dtvCommand *c = [sortedArray objectAtIndex:indexPath.row];
        cell.textLabel.text = c.commandDescription;
        isFavorite = [favoriteCommands containsObject:c.commandDescription];
        
        if (c.fontAwesome) {
            cellImage = [UIImage imageWithIcon:[NSString stringWithFormat:@"fa-%@", c.fontAwesome]
                               backgroundColor:[UIColor clearColor]
                                     iconColor:[Colors textColor]
                                       andSize:CGSizeMake(16, 16)];
        }
        
    } else {
        dtvCustomCommand *c = [sortedArray objectAtIndex:indexPath.row];
        cell.textLabel.text = c.commandDescription;
        isFavorite = [favoriteCommands containsObject:c.commandDescription];
        
        if (c.fontAwesome) {
            cellImage = [UIImage imageWithIcon:[NSString stringWithFormat:@"fa-%@", c.fontAwesome]
                               backgroundColor:[UIColor clearColor]
                                     iconColor:[Colors textColor]
                                       andSize:CGSizeMake(16, 16)];
        }
    }
    
    cell.detailTextLabel.text = isFavorite ? @"Favorite" : @"";
    cell.imageView.image = cellImage;
    
    
    if (isEditing) {
        
        UIImage *image = [UIImage new];
        
        if (isFavorite) {
            image = [UIImage imageNamed:@"images.bundle/favorite"];
        }
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect frame = CGRectMake(0, 0, image.size.width, image.size.height);
        button.frame = frame;
        button.userInteractionEnabled = NO;
        [button setBackgroundImage:image forState:UIControlStateNormal];
        button.backgroundColor = [UIColor clearColor];
        cell.accessoryView = button;
        
    } else {
        cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage new]];
    }
    

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[commands allKeys] count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    //cell data
    NSArray *sections = [[commands allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *sectionKey = [sections objectAtIndex:indexPath.section];
    NSMutableArray *commandArray = [commands objectForKey:sectionKey];
    NSArray *sortedArray = [commandArray sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *first = [(id) a sideBarSortIndex];
        NSString *second = [(id) b sideBarSortIndex];
        return [first compare:second];
    }];
    
    id obj = [sortedArray objectAtIndex:indexPath.row];
    if (isEditing) {

        NSString *desc;
        UIImage *image = [UIImage new];
        
        if ([obj isKindOfClass:[dtvCommand class]]) {
            dtvCommand *c = [sortedArray objectAtIndex:indexPath.row];
            desc = c.commandDescription;
        } else {
            dtvCustomCommand *c = [sortedArray objectAtIndex:indexPath.row];
            desc = c.commandDescription;
        }

        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        
        if ([favoriteCommands containsObject:desc]) {
            [favoriteCommands removeObject:desc];
            cell.detailTextLabel.text = @"";
        } else {
            [favoriteCommands addObject:desc];
            image = [UIImage imageNamed:@"images.bundle/favorite"];
            cell.detailTextLabel.text = @"Favorite";
        }

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tintColor = [Colors textColor];
        CGRect frame = CGRectMake(0, 0, image.size.width, image.size.height);
        button.frame = frame;
        button.userInteractionEnabled = NO;
        [button setBackgroundImage:image forState:UIControlStateNormal];
        button.backgroundColor = [UIColor clearColor];
        cell.accessoryView = button;
        [dtvCommands saveFavoriteCommands:favoriteCommands];
    } else {

        if ([obj isKindOfClass:[dtvCommand class]]) {
            dtvCommand *c = [sortedArray objectAtIndex:indexPath.row];
            [dtvCommands sendCommand:c.dtvCommandText device:currentDevice];
        } else {
            dtvCustomCommand *c = [sortedArray objectAtIndex:indexPath.row];
            [dtvCommands sendCustomCommand:c];
        }
    }

    
}

- (void) messageUpdatedCurrentDevice:(NSNotification *)notification {
    currentDevice = notification.object;
    sideBarNavItem.title = currentDevice.name;
    commands = [dtvCommands getCommandsForSidebar:currentDevice];
    [sideBarTable reloadData];
}

- (void) messageImportedCustomCommands:(NSNotification *)notification {
    commands = [dtvCommands getCommandsForSidebar:currentDevice];
    [sideBarTable reloadData];
}

@end
