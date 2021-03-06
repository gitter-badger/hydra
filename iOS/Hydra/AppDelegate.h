//
//  AppDelegate.h
//  Hydra
//
//  Created by Pieter De Baets on 20/03/12.
//  Copyright (c) 2012 Zeus WPI. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kErrorTitleKey @"ErrorTitleKey"
#define kErrorDescriptionKey NSLocalizedDescriptionKey

@interface AppDelegate : UIResponder <UIApplicationDelegate,UIAlertViewDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UINavigationController *navController;

- (void)handleError:(NSError *)error;

@end
