//
//  PWIntegrationValidator.h
//  PushwooshCore
//
//  Created by André Kis on 10.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PWIntegrationSeverity) {
    PWIntegrationSeverityOK = 0,
    PWIntegrationSeverityInfo = 1,
    PWIntegrationSeverityWarning = 2,
    PWIntegrationSeverityError = 3
};

/// Single result of one integration check rule.
@interface PWIntegrationFinding : NSObject

@property (nonatomic, readonly) NSString *ruleId;
@property (nonatomic, readonly) PWIntegrationSeverity severity;
@property (nonatomic, readonly) NSString *message;
@property (nonatomic, readonly, nullable) NSString *fixHint;

+ (instancetype)findingWithRule:(NSString *)ruleId
                       severity:(PWIntegrationSeverity)severity
                        message:(NSString *)message
                        fixHint:(nullable NSString *)fixHint;

@end

/// Startup-time integration health check.
///
/// Validates the host app's Pushwoosh integration (Info.plist keys,
/// Notification Service Extension wiring, optional-module consistency) and prints a
/// single consolidated report to the console via `PushwooshLog`.
///
/// Safety contract:
/// - warning-only — never changes SDK behavior
/// - runs once per launch, on a background queue
/// - the whole run is wrapped in `@try/@catch`, so a failing check cannot crash the host app
/// - skipped inside app extensions and when `Pushwoosh_DISABLE_INTEGRATION_CHECK` is set
@interface PWIntegrationValidator : NSObject

/// Schedules the one-shot validation run. Safe to call multiple times.
/// `appCode` is the application code the SDK resolved at init time — it may come
/// from Info.plist or from runtime configuration (`setAppCode:` / `initializeWithAppCode:`),
/// so the appid rule does not report a false error for runtime-configured apps.
+ (void)scheduleValidationWithAppCode:(nullable NSString *)appCode;

@end

NS_ASSUME_NONNULL_END
