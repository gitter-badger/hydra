//
//  InfoViewController.m
//  Hydra
//
//  Created by Yasser Deceukelier on 19/07/12.
//  Copyright (c) 2012 Zeus WPI. All rights reserved.
//

#import "InfoViewController.h"
#import "WebViewController.h"
#import "InfoItem.h"
#import "InfoStore.h"

#import <SVProgressHUD.h>

@interface InfoViewController ()

@property (nonatomic, strong) NSArray *content;
@property (nonatomic, strong) NSString *trackedViewName;

@end

@implementation InfoViewController

#pragma mark - Initializing + loading

- (id)init
{
    InfoStore *infoStore = [InfoStore sharedStore];
    self = [self initWithContent:infoStore.infoItems];

    self.title = @"Info";
    self.trackedViewName = self.title;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(infoUpdated:)
                   name:InfoStoreDidUpdateInfoNotification object:nil];

    return self;
}

- (id)initWithContent:(NSArray *)content
{
    if (self = [super initWithStyle:UITableViewStylePlain]) {
        self.content = content;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[self tableView] setTableFooterView:[[UIView alloc] initWithFrame:CGRectZero]];
    //[[self tableView] setBounces:NO];
    
    // TODO: only on main info screen
    if ([UIRefreshControl class]) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        refreshControl.tintColor = [UIColor hydraTintColor];
        [refreshControl addTarget:self action:@selector(didPullRefreshControl:)
                 forControlEvents:UIControlEventValueChanged];

        self.refreshControl = refreshControl;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    GAI_Track(self.trackedViewName);

    if (self.content.count == 0) {
        [SVProgressHUD show];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [SVProgressHUD dismiss];
}

- (void)didPullRefreshControl:(id)sender
{
    [[InfoStore sharedStore] reloadInfoItems];
}


- (void)infoUpdated:(NSNotification *)notification
{
    // TODO ask user to reload or not
    self.content = [[InfoStore sharedStore] infoItems];
    [self.tableView reloadData];

    //Hide or update progress HUD
    if ([SVProgressHUD isVisible]) {
        if (self.content.count > 0) {
            [SVProgressHUD dismiss];
        } else {
            NSString *errorMsg = @"Geen info geladen";
            [SVProgressHUD showErrorWithStatus:errorMsg];
        }
    }

    if ([UIRefreshControl class]) {
        [self.refreshControl endRefreshing];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.content count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"InfoCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:CellIdentifier];
        // iOS7
        if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
            cell.separatorInset = UIEdgeInsetsZero;
        }
    }

    cell.contentView.backgroundColor = [UIColor whiteColor];
    cell.textLabel.backgroundColor = cell.contentView.backgroundColor;

    InfoItem *item = (self.content)[indexPath.row];
    cell.textLabel.text = item.title;
    
    UIImage *icon = [UIImage imageNamed:item.image];
    if(icon) {
        cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
        cell.imageView.image = icon;
    }
    else {
        cell.imageView.image = nil;
    }
    
    // Show an icon, depending on the subview
    if (item.appstore || item.url) {
        UIImage *linkImage = [UIImage imageNamed:@"external-link.png"];
        UIImage *highlightedLinkImage = [UIImage imageNamed:@"external-link-active.png"];
        UIImageView *linkAccessory = [[UIImageView alloc] initWithImage:linkImage
                                                       highlightedImage:highlightedLinkImage];
        linkAccessory.contentMode = UIViewContentModeScaleAspectFit;
        cell.accessoryView = linkAccessory;
    }
    else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    InfoItem *item = self.content[indexPath.row];

    // Choose a different action depending on what data is available
    if(item.subcontent){
        NSArray *subContent = item.subcontent;

        InfoViewController *c = [[InfoViewController alloc] initWithContent:subContent];
        c.title = item.title;
        c.trackedViewName = [NSString stringWithFormat:@"%@ > %@", self.trackedViewName, c.title];

        [self.navigationController pushViewController:c animated:YES];
    }
    else if(item.html) {
        WebViewController *c = [[WebViewController alloc] init];
        c.title = item.title;
        c.trackedViewName = [NSString stringWithFormat:@"%@ > %@", self.trackedViewName, c.title];
        [c loadHtml:item.html];

        [self.navigationController pushViewController:c animated:YES];
    }
    else if(item.appstore || item.url) {
        NSURL *url = nil;
        if (item.appstore) url = [NSURL URLWithString:item.appstore];
        else url = [NSURL URLWithString:item.url];

        [[UIApplication sharedApplication] openURL:url];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    else {
        NSLog(@"Unknown action in %@", item);
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

@end
