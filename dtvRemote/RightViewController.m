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
#import "Colors.h"

@interface RightViewController ()

@end

@implementation RightViewController {
    NSArray *commands;
    UIView *sideBarView;
    UITableView *sideBarTable;
    dtvDevice *currentDevice;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    currentDevice = [dtvDevices getCurrentDevice];
    commands = [dtvCommands getArrayOfCommands];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdatedCurrentDevice:)
                                                 name:@"messageUpdatedCurrentDevice" object:nil];
    
    sideBarView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    CGRect navBarFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width * 0.75, 64.0);
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    bar.translucent = NO;
    bar.tintColor = [Colors tintColor];
    bar.barTintColor = [Colors navBGColor];
    bar.titleTextAttributes = @{NSForegroundColorAttributeName : [Colors textColor]};
    
    UINavigationItem *sideBarNavItem = [UINavigationItem alloc];
    sideBarNavItem.title = @"Remote Commands";
    [bar pushNavigationItem:sideBarNavItem animated:false];
    
    [sideBarView addSubview:bar];
    
    CGRect tableFrame = [[UIScreen mainScreen] bounds];
    tableFrame.size.width = tableFrame.size.width * 0.75;
    tableFrame.size.height = tableFrame.size.height - 64;
    tableFrame.origin.x = 0;
    tableFrame.origin.y = 64;
    sideBarTable = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
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
    v.backgroundView.backgroundColor = [UIColor blackColor];
    v.backgroundView.alpha = 0.9;
    v.backgroundView.tintColor = [Colors tintColor];
    
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setTextColor:[Colors textColor]];
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Commands";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [commands count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CellPicker"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CellPicker"];
    }
    
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    cell.userInteractionEnabled = YES;
    cell.detailTextLabel.enabled = YES;
    
    if (indexPath.section == 0) {
        dtvCommand *c = [commands objectAtIndex:indexPath.row];
        cell.textLabel.text = c.description;
        cell.detailTextLabel.text = c.action;
    }
  
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    dtvCommand *c = [commands objectAtIndex:indexPath.row];
    [dtvCommands sendCommand:c.action device:currentDevice];
}

- (void) messageUpdatedCurrentDevice:(NSNotification *)notification {
    currentDevice = notification.object;
}

@end
