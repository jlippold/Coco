//
//  SideBar.m
//  dtvRemote
//
//  Created by Jed Lippold on 4/7/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "SideBarTableView.h"
#import "Clients.h"

@implementation SideBarTableView {
    UIColor *textColor;
    UIColor *backgroundColor;
    UIColor *tableBackgroundColor;
    UIColor *seperatorColor;
    UIColor *boxBackgroundColor;
    UIColor *navBGColor;
    UIColor *tint;
}


-(id) init{
    self = [super init];
    _clients = [Clients loadClientList];
    _currentClient = [Clients getClient];

    textColor = [UIColor colorWithRed:193/255.0f green:193/255.0f blue:193/255.0f alpha:1.0f];
    backgroundColor = [UIColor colorWithRed:30/255.0f green:30/255.0f blue:30/255.0f alpha:1.0f];
    boxBackgroundColor = [UIColor colorWithRed:28/255.0f green:28/255.0f blue:28/255.0f alpha:1.0f];
    navBGColor = [UIColor colorWithRed:23/255.0f green:23/255.0f blue:23/255.0f alpha:1.0f];
    tint = [UIColor colorWithRed:30/255.0f green:147/255.0f blue:212/255.0f alpha:1.0f];
    seperatorColor = [UIColor colorWithRed:40/255.0f green:40/255.0f blue:40/255.0f alpha:1.0f];
    
    return self;
}

- (void)refresh:(UIRefreshControl *)refreshControl {
    [refreshControl endRefreshing];
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    cell.indentationLevel = 1;
    cell.indentationWidth = 2;
    //cell.accessoryType = UITableViewCellAccessoryNone;
    cell.backgroundColor = tableBackgroundColor;
    [cell.textLabel setTextColor: textColor];
    [cell.detailTextLabel setTextColor:textColor];
    
    cell.userInteractionEnabled = YES;
    [cell setTintColor:tint];
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return  18.0;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *v = (UITableViewHeaderFooterView *)view;
    v.backgroundView.backgroundColor = [UIColor blackColor];
    v.backgroundView.alpha = 0.9;
    v.backgroundView.tintColor = tint;
    
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setTextColor:textColor];
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) { //Devices
        return @"Devices";
    } else {    //Commands
        return @"Commands";
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if (section == 0) { //Devices
        return [[[_clients objectForKey:@"Simulator"] allKeys] count] + 1;
    } else {    //Commands
        return 10;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CellPicker"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CellPicker"];
    }

    if (indexPath.section == 0) {
        NSArray *keys = [[_clients objectForKey:@"Simulator"] allKeys];
        if (indexPath.row < [keys count]) {
            id key = [keys objectAtIndex:indexPath.row];
            //NSLog(@"%@", _currentClient);
            NSDictionary *client = _clients[@"Simulator"][key];
            cell.textLabel.text = client[@"name"];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"Online: %@", client[@"address"]];
            
            if ([_currentClient[@"id"] isEqualToString:client[@"id"]]) {
                [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
            }
        } else {
            cell.textLabel.text = @"Scan for devices";
            cell.detailTextLabel.text = @"Search wifi network for more devices";
        }
    }
    if (indexPath.section == 1) {
        cell.textLabel.text = @"Some Command";
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL edit = NO;
    if (indexPath.section == 0) {
        NSArray *keys = [[_clients objectForKey:@"Simulator"] allKeys];
        if (indexPath.row < [keys count]) {
            edit = YES;
        }
    }
    return edit;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        //[_objects removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}


@end
