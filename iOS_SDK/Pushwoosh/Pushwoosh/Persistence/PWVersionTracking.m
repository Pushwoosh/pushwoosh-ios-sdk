//
//  PWVersionTracking.m
//  PWVersionTracking
//
//  Created by Luka Mirosevic on 28/01/2013.
//  Copyright (c) 2015 Goonbee. All rights reserved.
//

#import "PWVersionTracking.h"

// Allows making public interface a little simpler by hiding all singleton instance methods and presenting them as class methods
#define _controller [PWVersionTracking sharedController]

static NSString * const kPWUserDefaultsVersionTrailKey =      @"kPWVersionTrail";
static NSString * const kPWVersionsKey =                      @"kPWVersion";
static NSString * const kPWBuildsKey =                        @"kPWBuild";


@interface PWVersionTracking ()

@property (strong, nonatomic) NSDictionary                  *versionTrail;
@property (assign, nonatomic) BOOL                          isFirstLaunchEver;
@property (assign, nonatomic) BOOL                          isFirstLaunchForVersion;
@property (assign, nonatomic) BOOL                          isFirstLaunchForBuild;

@end


@implementation PWVersionTracking

#pragma mark - Storage

+ (PWVersionTracking *)sharedController {
    static PWVersionTracking *sharedController;
    @synchronized(self) {
        if (!sharedController) {
            sharedController = [PWVersionTracking new];
        }
        return sharedController;
    }
}

#pragma mark - Public API

+ (void)reset {
     [[NSUserDefaults standardUserDefaults] setObject:nil forKey:kPWUserDefaultsVersionTrailKey];
    _controller.isFirstLaunchEver = YES;
    _controller.isFirstLaunchForBuild = YES;
    _controller.isFirstLaunchForVersion = YES;
}

+ (void)track {
    BOOL needsSync = NO;
    
    //load history
    NSDictionary *oldVersionTrail = [[NSUserDefaults standardUserDefaults] objectForKey:kPWUserDefaultsVersionTrailKey];
    
    //check if its the first ever launch
    if (oldVersionTrail == nil) {
        _controller.isFirstLaunchEver = YES;
        
        _controller.versionTrail = @{kPWVersionsKey: [NSMutableArray new], kPWBuildsKey: [NSMutableArray new]};
    }
    else {
        _controller.isFirstLaunchEver = NO;
        
        //read the old datastructure out but make a deeply mutable copy of it first
        _controller.versionTrail = @{kPWVersionsKey: [oldVersionTrail[kPWVersionsKey] mutableCopy], kPWBuildsKey: [oldVersionTrail[kPWBuildsKey] mutableCopy]};
        
        needsSync = YES;
    }
    
    //check if this version was previously launched
    if ([_controller.versionTrail[kPWVersionsKey] containsObject:[self currentVersion]]) {
        _controller.isFirstLaunchForVersion = NO;
    }
    else {
        _controller.isFirstLaunchForVersion = YES;
        
        [_controller.versionTrail[kPWVersionsKey] addObject:[self currentVersion]];
        
        needsSync = YES;
    }
    
    //check if this build was previously launched
    if ([_controller.versionTrail[kPWBuildsKey] containsObject:[self currentBuild]]) {
        _controller.isFirstLaunchForBuild = NO;
    }
    else {
        _controller.isFirstLaunchForBuild = YES;
        
        [_controller.versionTrail[kPWBuildsKey] addObject:[self currentBuild]];
        
        needsSync = YES;
    }
    
    //store the new version stuff
    if (needsSync) {
        [[NSUserDefaults standardUserDefaults] setObject:_controller.versionTrail forKey:kPWUserDefaultsVersionTrailKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (BOOL)isFirstLaunchEver {
    return _controller.isFirstLaunchEver;
}

+ (BOOL)isFirstLaunchForVersion {
    return _controller.isFirstLaunchForVersion;
}

+ (BOOL)isFirstLaunchForBuild {
    return _controller.isFirstLaunchForBuild;
}

+ (BOOL)isFirstLaunchForVersion:(NSString *)version {
    if ([[self currentVersion] isEqualToString:version]) {
        return [self isFirstLaunchForVersion];
    }
    else {
        return NO;
    }
}

+ (BOOL)isFirstLaunchForBuild:(NSString *)build {
    if ([[self currentBuild] isEqualToString:build]) {
        return [self isFirstLaunchForBuild];
    }
    else {
        return NO;
    }
}

+ (void)callBlockOnFirstLaunchOfVersion:(NSString *)version block:(PWVersionTrackingHandlerBlock)block {
    if ([self isFirstLaunchForVersion:version] && block) {
        block();
    }
}

+ (void)callBlockOnFirstLaunchOfBuild:(NSString *)build block:(PWVersionTrackingHandlerBlock)block {
    if ([self isFirstLaunchForBuild:build] && block) {
        block();
    }
}

#pragma mark - Versions

+ (NSString *)currentVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

+ (NSString *)previousVersion {
    NSUInteger count = [_controller.versionTrail[kPWVersionsKey] count];
    if (count >= 2) {
        return _controller.versionTrail[kPWVersionsKey][count-2];
    }
    else return nil;
}

+ (NSString *)firstInstalledVersion {
    return [_controller.versionTrail[kPWVersionsKey] firstObject];
}

+ (NSArray *)versionHistory {
    return _controller.versionTrail[kPWVersionsKey];
}

#pragma mark - Builds

+ (NSString *)currentBuild {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
}

+ (NSString *)previousBuild {
    NSUInteger count = [_controller.versionTrail[kPWBuildsKey] count];
    if (count >= 2) {
        return _controller.versionTrail[kPWBuildsKey][count-2];
    }
    else return nil;
}

+ (NSString *)firstInstalledBuild {
    return [_controller.versionTrail[kPWBuildsKey] firstObject];
}

+ (NSArray *)buildHistory {
    return _controller.versionTrail[kPWBuildsKey];
}

@end
