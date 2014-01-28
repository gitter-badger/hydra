//
//  InfoStore.m
//  Hydra
//
//  Created by Feliciaan De Palmenaer on 27/01/14.
//  Copyright (c) 2014 Zeus WPI. All rights reserved.
//

#import "InfoStore.h"
#import "InfoItem.h"
#import "AppDelegate.h"

#import <RestKit/RestKit.h>
#import <AFNetworking/AFNetworking.h>
#import <SSZipArchive.h>

//#define kInfoBaseUrl @"http://zeus.ugent.be/hydra/api/1.0/info/"
#define kInfoBaseUrl @"http://kelder.zeus.ugent.be/~feliciaan/info/"
#define kInfoItemsUrl @"info-content.json"
#define kInfoResourcesUrl @"info-resources%@.zip"
#define kInfoUpdateInterval (60*60*24*7) // wait one week before updating

NSString *const InfoStoreDidUpdateInfoNotification = @"InfoStoreDidUpdateInfoNotification";

@interface InfoStore () <NSCoding>

@property (nonatomic, strong, readwrite) NSArray *infoItems;
@property (nonatomic, strong) NSDate *lastUpdated;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, strong) RKObjectManager* objectManager;

@end

@implementation InfoStore

+ (InfoStore *)sharedStore
{
    static InfoStore *sharedInstance = nil;
    if (!sharedInstance) {
        // Try restoring the store from archive
        @try {
            sharedInstance = [NSKeyedUnarchiver unarchiveObjectWithFile:self.infoCachePath];
        }
        @catch (NSException *exception) {
            NSLog(@"Got exception while reading Info archive: %@", exception);
        }
        @finally {
            if (!sharedInstance) sharedInstance = [[InfoStore alloc] init];
        }
    }
    return sharedInstance;
}

- (id)init
{
    if (self = [super init]) {
        self.infoItems = [[NSArray alloc] init];
        self.lastUpdated = [NSDate date];
        self.active = NO;
        [self updateInfoItems];
    }
    return self;
}

#pragma mark - Caching

- (id)initWithCoder:(NSCoder *)decoder
{
    if (self = [super init]) {
        self.infoItems = [decoder decodeObjectForKey:@"infoItems"];
        AssertClassOrNil(self.infoItems, NSArray);
        self.lastUpdated = [decoder decodeObjectForKey:@"lastUpdated"];
        AssertClassOrNil(self.lastUpdated, NSDate);
        self.active = NO;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.infoItems forKey:@"infoItems"];
    [coder encodeObject:self.lastUpdated forKey:@"lastUpdated"];
}

+ (NSString *)infoCachePath
{
    // Get cache directory
    NSArray *cacheDirectories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = cacheDirectories[0];
    
    return [cacheDirectory stringByAppendingPathComponent:@"info.archive"];
}

- (void)reloadInfoItems
{
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [self updateInfoItems];
}

- (void)syncStorage
{
    dispatch_queue_t async = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    dispatch_async(async, ^{
        [NSKeyedArchiver archiveRootObject:self toFile:self.class.infoCachePath];
    });
}

#pragma - mark Info fetching

- (void)updateInfoItems
{
    // Only allow one request at a time
    if (self.active) return;
    self.active = YES;

    DLog(@"update Info (last: %@ => %f)", self.lastUpdated, [self.lastUpdated timeIntervalSinceNow]);

    // Check if an update is required
    if (self.lastUpdated && [self.lastUpdated timeIntervalSinceNow] > -kInfoUpdateInterval) {
        //return;
    }

    // The RKObjectManager must be retained, otherwise reachability notifications
    // will not be received properly and all kinds of weird stuff happen
    if (!self.objectManager) {
        self.objectManager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:kInfoBaseUrl]];
    }
    
    [self.objectManager addResponseDescriptor:
     [RKResponseDescriptor responseDescriptorWithMapping:[InfoItem objectMapping]
                                                  method:RKRequestMethodGET
                                             pathPattern:kInfoItemsUrl
                                                 keyPath:nil
                                             statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)]];
    [self.objectManager getObjectsAtPath:kInfoItemsUrl
                              parameters:nil
                                 success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
                                     [self _processResult:mappingResult];
                                 }
                                 failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                     NSLog(@"Updating schamper failed: %@", error);
                                     AppDelegate *app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                                     [app handleError:error];
                                     
                                     [self _processResult:nil];
                                 }];
}

- (void)_processResult:(RKMappingResult *)mappingResult
{
    
    NSArray *objects = [mappingResult array];
    if (objects.count > 0) {
        self.infoItems = objects;
        self.lastUpdated = [NSDate date];
        self.active = NO;

        [self _updateResources]; // TODO: make it async
        [self syncStorage];
    }

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:InfoStoreDidUpdateInfoNotification object:self];
}
#pragma - mark Update Resource files
- (void)_updateResources
{
    NSString *screenType;
    if ([[UIScreen mainScreen] scale] == 2.00) { // true if retina
        screenType = @"@2x";
    }else {
        screenType = @"";
    }
    // create url
    NSString *resourceFile = [NSString stringWithFormat:kInfoResourcesUrl, screenType];
    NSURL *resourceURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",kInfoBaseUrl, resourceFile]];

    // find cache dir
    NSString *cacheDirectory = [self padForResource:@""];

    // create dir or if created nothing happens
    NSError * error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDirectory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (error != nil) {
        NSLog(@"error creating directory: %@", error);
        // TODO catch errors
    }

    // get TMP directory
    NSString *temporaryFile = [NSTemporaryDirectory() stringByAppendingPathComponent:resourceFile];
    // start download
    NSURLRequest *request = [NSURLRequest requestWithURL:resourceURL];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];

    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSData *data = responseObject;
        [data writeToFile:temporaryFile atomically:YES];
        NSError *error = nil;
        [SSZipArchive unzipFileAtPath:temporaryFile toDestination:cacheDirectory overwrite:YES password:nil error:&error];
        if (error != nil) {
            //TODO
            NSLog(@"ERROR in unarchiving: %@", error);
        }
        [self _cleanupResource:temporaryFile];

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center postNotificationName:InfoStoreDidUpdateInfoNotification object:self];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        AppDelegate *app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [app handleError:error];
        NSLog(@"ERROR: %@", error);
    }];

    [operation start];

}

- (void)_cleanupResource:(NSString *)tmpFile
{
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:tmpFile error:&error];
    if (error != nil) {
        NSLog(@"Cleanup failed: %@", error);
    }
}

- (NSString *)padForResource:(NSString *)aResource
{
    // find cache dir
    NSArray *cacheDirectories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cacheDirectories[0] stringByAppendingPathComponent:@"info"];

    return [cacheDirectory stringByAppendingPathComponent:aResource];
}

- (NSString *)padForImage:(NSString *)aImage
{
    NSString *screenType;
    if ([[UIScreen mainScreen] scale] == 2.00) { // true if retina
        screenType = @"@2x";
    }else {
        screenType = @"";
    }
    NSString *imageFile = [NSString stringWithFormat:@"%@%@.png",aImage, screenType];
    return [self padForResource:imageFile];
}

@end
