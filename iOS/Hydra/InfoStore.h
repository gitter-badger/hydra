//
//  InfoStore.h
//  Hydra
//
//  Created by Feliciaan De Palmenaer on 27/01/14.
//  Copyright (c) 2014 Zeus WPI. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const InfoStoreDidUpdateInfoNotification;

@interface InfoStore : NSObject

@property (nonatomic, strong, readonly) NSArray *infoItems;

+ (InfoStore *)sharedStore;
- (void)reloadInfoItems;

- (NSString *)padForResource:(NSString *)aResource;
- (NSString *)padForImage:(NSString *)aImage;
@end
