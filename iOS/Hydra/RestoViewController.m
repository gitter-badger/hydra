//
//  RestoViewController.m
//  Hydra
//
//  Created by Pieter De Baets on 29/06/12.
//  Copyright (c) 2012 Zeus WPI. All rights reserved.
//
#import <QuartzCore/QuartzCore.h>
#import "RestoViewController.h"
#import "RestoStore.h"
#import "RestoMenu.h"
#import "UIColor+AppColors.h"
#import "NSDate+Utilities.h"
#import "RestoMenuView.h"
#import "RestoInfoView.h"
#import "RestoMapViewController.h"

#define kRestoDaysShown 5

@interface RestoViewController () <UIScrollViewDelegate>

@property (nonatomic, unsafe_unretained) UIScrollView *scrollView;
@property (nonatomic, unsafe_unretained) UIPageControl *pageControl;
@property (nonatomic, unsafe_unretained) RestoInfoView *infoSheet;
@property (nonatomic, unsafe_unretained) RestoMenuView *menuSheetA;
@property (nonatomic, unsafe_unretained) RestoMenuView *menuSheetB;

@property (nonatomic, strong) NSArray *days;
@property (nonatomic, strong) NSMutableArray *menus;

@property (nonatomic, assign) NSUInteger pageControlUsed;

@end

@implementation RestoViewController

#pragma mark Setting up the view & viewcontroller

- (void)loadView
{
    CGRect bounds = [UIScreen mainScreen].bounds;
    self.view = [[UIView alloc] initWithFrame:bounds];
    self.view.backgroundColor = [UIColor hydraBackgroundColor];

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.pagingEnabled = YES;
    scrollView.delegate = self;
    scrollView.showsHorizontalScrollIndicator = NO;
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;

    CGRect pageControlFrame = CGRectMake(0, bounds.size.height - 36, bounds.size.width, 36);
    UIPageControl *pageControl = [[UIPageControl alloc] initWithFrame:pageControlFrame];
    pageControl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [pageControl addTarget:self action:@selector(pageChanged:)
          forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:pageControl];
    self.pageControl = pageControl;

    // Sheets
    CGSize viewSize = self.scrollView.frame.size;
    CGRect sheetFrame = CGRectMake(20, 20, viewSize.width - 40, viewSize.height - 60);

    self.menuSheetA = [self addSheet:[[RestoMenuView alloc] initWithFrame:sheetFrame]];
    self.menuSheetB = [self addSheet:[[RestoMenuView alloc] initWithFrame:sheetFrame]];
    self.infoSheet = [self addSheet:[[RestoInfoView alloc] initWithFrame:sheetFrame]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.title = @"Resto Menu";

    // Check for updates
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(reloadMenu)
                   name:RestoStoreDidReceiveMenuNotification object:nil];
    [center addObserver:self selector:@selector(reloadInfo)
                   name:RestoStoreDidUpdateInfoNotification object:nil];

    // Update views
    [self reloadMenu];
    [self reloadInfo];

    // Setup scrollview
    [self updateView:self.menuSheetA toIndex:0];
    [self updateView:self.menuSheetB toIndex:1];

    CGSize viewSize = self.scrollView.frame.size;
    self.scrollView.contentSize = CGSizeMake(viewSize.width * (self.days.count + 1), 1);
    self.scrollView.contentOffset = CGPointMake(viewSize.width, 0);

    // Setup pageControl
    self.pageControlUsed = 0;
    self.pageControl.numberOfPages = self.days.count + 1;
    self.pageControl.currentPage = 1;

    // add NavigationBar button
    UIBarButtonItem *mapButton = [[UIBarButtonItem alloc] initWithTitle:@"Kaart"
                    style:UIBarButtonItemStylePlain target:self action:@selector(mapButtonTouched:)];
    [self.navigationItem setRightBarButtonItem:mapButton];
}

- (void)viewDidUnload
{
    [super viewDidUnload];

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Nil weak references
    self.scrollView = nil;
    self.pageControl = nil;
    self.infoSheet = nil;
    self.menuSheetA = nil;
    self.menuSheetB = nil;
}

- (id)addSheet:(UIView *)contentView
{
    // Use the outer view for shadows, the contentView uses maskToBounds for rounded corners
    UIView *holderView = [[UIView alloc] initWithFrame:contentView.frame];
    holderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.scrollView addSubview:holderView];

    contentView.frame = holderView.bounds;
    contentView.autoresizingMask = holderView.autoresizingMask;
    [holderView addSubview:contentView];

    return contentView;
}

#define kPageCornerRadius 10

- (void)setupSheetStyle:(UIView *)contentView
{
    CALayer *layer = contentView.superview.layer;
    layer.cornerRadius = kPageCornerRadius;

    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:layer.bounds
                                                          cornerRadius:kPageCornerRadius];
    layer.shadowPath = shadowPath.CGPath;
    layer.shadowColor = [UIColor blackColor].CGColor;
    layer.shadowOpacity = 0.3;
    layer.shadowOffset = CGSizeMake(1.5, 3.0);

    contentView.layer.cornerRadius = kPageCornerRadius;
    contentView.layer.masksToBounds = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[GAI sharedInstance].defaultTracker trackView:@"Resto Menu"];
}

- (void)viewDidLayoutSubviews
{
    // Restyle the sheets to keep the shadow the right size
    [self setupSheetStyle:self.menuSheetA];
    [self setupSheetStyle:self.menuSheetB];
    [self setupSheetStyle:self.infoSheet];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Buttons

- (void)mapButtonTouched:(UIButton *)sender
{
    UIViewController *c = [[RestoMapViewController alloc] init];
    [self presentModalViewController:c animated:YES];
}

#pragma mark - Loading days & menus

- (void)calculateDays
{
    NSDate *day = [NSDate date];
    NSMutableArray *days = [NSMutableArray arrayWithCapacity:kRestoDaysShown];

    // Find the next 5 days to display
    while (days.count < kRestoDaysShown) {
        if ([day isTypicallyWorkday]) {
            [days addObject:day];
        }
        day = [day dateByAddingDays:1];
    }
    self.days = days;
}

- (void)reloadMenu
{
    if (!self.days.count) [self calculateDays];

    RestoStore *store = [RestoStore sharedStore];
    NSMutableArray *menus = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < self.days.count; i++) {
        id menu = [store menuForDay:self.days[i]];
        if (!menu) menu = [NSNull null];
        menus[i] = menu;
    }
    self.menus = menus;
}

- (void)setMenus:(NSMutableArray *)menus
{
    _menus = menus;

    NSUInteger currentIndex = [self.days indexOfObject:self.menuSheetA.day];
    if (currentIndex != NSNotFound) {
        [self.menuSheetA configureWithDay:self.days[currentIndex]
                                     menu:self.menus[currentIndex]];
    }

    NSUInteger nextIndex = [self.days indexOfObject:self.menuSheetB.day];
    if (nextIndex != NSNotFound) {
        [self.menuSheetB configureWithDay:self.days[nextIndex]
                                     menu:self.menus[nextIndex]];
    }
}

- (void)reloadInfo
{
    self.infoSheet.legend = [RestoStore sharedStore].legend;
}

#pragma mark - View scrolling and page changing

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat pageWidth = self.scrollView.frame.size.width;
    float fractionalPage = self.scrollView.contentOffset.x / pageWidth;

    if (self.pageControlUsed == 0) {
        self.pageControl.currentPage = round(fractionalPage);
    }

    // Nothing needs to change for the InfoView
    if (fractionalPage < 1) return;

    NSInteger lowerNumber = floor(fractionalPage) - 1;
    NSInteger upperNumber = lowerNumber + 1;

    NSDate *lowerDate = self.days[lowerNumber];
    NSDate *upperDate = nil;
    if (upperNumber < kRestoDaysShown) {
        upperDate = self.days[upperNumber];
    }

    // GOAL: apply lower and upper date to menuSheetA and menuSheetB
    // with the least amount of changes possible
    if (self.menuSheetA.day != lowerDate && self.menuSheetA.day != upperDate) {
        NSUInteger newIndex = self.menuSheetB.day == upperDate ? lowerNumber : upperNumber;
        [self updateView:self.menuSheetA toIndex:newIndex];
    }
    if (self.menuSheetB.day != lowerDate && self.menuSheetB.day != upperDate) {
        NSUInteger newIndex = self.menuSheetA.day == upperDate ? lowerNumber : upperNumber;
        [self updateView:self.menuSheetB toIndex:newIndex];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)sender
{
    self.pageControlUsed--;
}

- (void)pageChanged:(UIPageControl *)sender
{
    DLog(@"UIPageControl requesting page %d", self.pageControl.currentPage);

    CGRect newPage = self.scrollView.bounds;
    newPage.origin.x = newPage.size.width * self.pageControl.currentPage;
    [self.scrollView scrollRectToVisible:newPage animated:YES];

    // Keep track of active UIPageControl animations
    self.pageControlUsed++;
}

- (void)updateView:(RestoMenuView *)view toIndex:(NSInteger)index
{
    if (index >= kRestoDaysShown || view.day == self.days[index]) return;

    CGSize viewSize = self.view.bounds.size;
    CGRect frame = CGRectMake(viewSize.width * (index + 1) + 20, 20,
                              viewSize.width - 40, viewSize.height - 60);
    view.superview.frame = frame;

    [view configureWithDay:self.days[index] menu:self.menus[index]];
}

@end
