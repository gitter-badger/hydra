//
//  InfoItem.m
//  Hydra
//
//  Created by Feliciaan De Palmenaer on 27/01/14.
//  Copyright (c) 2014 Zeus WPI. All rights reserved.
//

#import "InfoItem.h"

#import <RestKit/RestKit.h>

@implementation InfoItem

- (NSString *)description
{
    return [NSString stringWithFormat:@"<InfoItem: %@>", self.title];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if (self = [super init]) {
        _title = [decoder decodeObjectForKey:@"title"];
        _url = [decoder decodeObjectForKey:@"url"];
        _appstore = [decoder decodeObjectForKey:@"appstore"];
        _html = [decoder decodeObjectForKey:@"html"];
        _image = [decoder decodeObjectForKey:@"image"];
        _subcontent = [decoder decodeObjectForKey:@"subcontent"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.url forKey:@"url"];
    [coder encodeObject:self.appstore forKey:@"appstore"];
    [coder encodeObject:self.html forKey:@"html"];
    [coder encodeObject:self.image forKey:@"image"];
    [coder encodeObject:self.subcontent forKey:@"subcontent"];
}

+ (RKObjectMapping *)objectMapping
{
    RKObjectMapping *infoItemMapping = [RKObjectMapping mappingForClass:self];
    [infoItemMapping addAttributeMappingsFromArray:@[@"title", @"url", @"image", @"html"]];
    [infoItemMapping addAttributeMappingsFromDictionary:@{@"url-ios": @"appstore"}];
    
    RKRelationshipMapping *subcontent = [RKRelationshipMapping relationshipMappingFromKeyPath:@"subcontent"
                                                                              toKeyPath:@"subcontent"
                                                                            withMapping:infoItemMapping];

    [infoItemMapping addPropertyMapping:subcontent];
    return infoItemMapping;
}

@end
