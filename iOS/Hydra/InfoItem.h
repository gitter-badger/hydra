//
//  InfoItem.h
//  Hydra
//
//  Created by Feliciaan De Palmenaer on 27/01/14.
//  Copyright (c) 2014 Zeus WPI. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RKObjectMapping;

@interface InfoItem : NSObject <NSCoding>

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, strong) NSString *appstore;
@property (nonatomic, strong) NSString *html;
@property (nonatomic, strong) NSString *image;
@property (nonatomic, strong) NSArray *subcontent;

+ (RKObjectMapping *)objectMapping;

@end
