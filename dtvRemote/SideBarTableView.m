//
//  SideBar.m
//  dtvRemote
//
//  Created by Jed Lippold on 4/7/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "SideBarTableView.h"
#import "Clients.h"

@implementation SideBarTableView


-(id) init{
    self = [super init];
    _clients = [Clients loadClientList];
    _currentClient = [Clients getClient];
    return self;
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.indentationLevel = 1;
    cell.indentationWidth = 2;
    cell.accessoryType = UITableViewCellAccessoryDetailButton;
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
        return [[[_clients objectForKey:@"Simulator"] allKeys] count];
    } else {    //Commands
        return 10;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CellPicker"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithFrame:CGRectZero];
    }
    
    if (indexPath.section == 0) {
        NSArray *keys = [[_clients objectForKey:@"Simulator"] allKeys];
        id key = [keys objectAtIndex:indexPath.row];
        NSDictionary *client = _clients[@"Simulator"][key];
        cell.textLabel.text = client[@"name"];
    
    }
    if (indexPath.section == 1) {
        cell.textLabel.text = @"Some Command";
    }

    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 2;
}


@end
