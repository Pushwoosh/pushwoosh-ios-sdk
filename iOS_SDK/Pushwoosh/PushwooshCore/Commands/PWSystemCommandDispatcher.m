//
//  PWSystemCommandDispatcher.m
//  PushwooshCore
//
//  Created by André Kis on 26.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWSystemCommandDispatcher.h"
#import "PWSetLogLevelCommandHandler.h"
#import "PWSetBaseUrlCommandHandler.h"
#import <PushwooshCore/PushwooshLog.h>

static NSString *const kPWSystemPushKey = @"pw_system_push";
static NSString *const kPWCommandKey = @"pw_command";
static NSString *const kPWCommandsKey = @"pw_commands";

@interface PWSystemCommandDispatcher ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, id<PWSystemCommandHandler>> *handlers;

@end

@implementation PWSystemCommandDispatcher

#pragma mark - Singleton

+ (instancetype)shared {
    static PWSystemCommandDispatcher *instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

#pragma mark - Init

- (instancetype)init {
    self = [super init];
    if (self) {
        _handlers = [NSMutableDictionary dictionary];
        [self registerBuiltInHandlers];
    }
    return self;
}

#pragma mark - Built-in Handlers

- (void)registerBuiltInHandlers {
    // Register setLogLevel command handler
    [self registerHandler:[[PWSetLogLevelCommandHandler alloc] init]];

    // Register set_base_url command handler
    [self registerHandler:[[PWSetBaseUrlCommandHandler alloc] init]];
}

#pragma mark - Public Methods

- (void)registerHandler:(id<PWSystemCommandHandler>)handler {
    if (!handler || !handler.commandName) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:@"Attempted to register invalid command handler"];
        return;
    }

    @synchronized (self.handlers) {
        self.handlers[handler.commandName] = handler;
    }

    [PushwooshLog pushwooshLog:PW_LL_DEBUG
                     className:self
                       message:[NSString stringWithFormat:@"Registered command handler: %@", handler.commandName]];
}

- (void)unregisterHandlerForCommand:(NSString *)commandName {
    if (!commandName) {
        return;
    }

    @synchronized (self.handlers) {
        [self.handlers removeObjectForKey:commandName];
    }

    [PushwooshLog pushwooshLog:PW_LL_DEBUG
                     className:self
                       message:[NSString stringWithFormat:@"Unregistered command handler: %@", commandName]];
}

- (BOOL)processUserInfo:(NSDictionary *)userInfo {
    if (!userInfo || ![self isSystemPush:userInfo]) {
        return NO;
    }

    // New format: pw_commands array (multiple commands)
    NSArray *commands = userInfo[kPWCommandsKey];
    if ([commands isKindOfClass:[NSArray class]] && commands.count > 0) {
        [self processMultipleCommands:commands];
        return YES;
    }

    // Old format: single pw_command (backward compatibility)
    NSString *command = [self extractCommand:userInfo];
    if (!command) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:@"System push received but pw_command is missing"];
        return YES;
    }

    [self processSingleCommand:command value:userInfo[@"value"]];
    return YES;
}

- (void)processMultipleCommands:(NSArray *)commands {
    for (id item in commands) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSDictionary *commandDict = (NSDictionary *)item;
        NSString *command = commandDict[@"command"];
        id value = commandDict[@"value"];

        if ([command isKindOfClass:[NSString class]]) {
            [self processSingleCommand:command value:value];
        }
    }
}

- (void)processSingleCommand:(NSString *)command value:(id)value {
    @synchronized (self.handlers) {
        id<PWSystemCommandHandler> handler = self.handlers[command];

        if (!handler) {
            [PushwooshLog pushwooshLog:PW_LL_WARN
                             className:self
                               message:[NSString stringWithFormat:@"No handler registered for command: %@", command]];
            return;
        }

        [PushwooshLog pushwooshLog:PW_LL_DEBUG
                         className:self
                           message:[NSString stringWithFormat:@"Handling command: %@", command]];

        NSDictionary *commandUserInfo = @{
            kPWCommandKey: command,
            @"value": value ?: [NSNull null]
        };

        BOOL handled = [handler handleCommand:commandUserInfo];

        if (handled) {
            [PushwooshLog pushwooshLog:PW_LL_INFO
                             className:self
                               message:[NSString stringWithFormat:@"Command handled successfully: %@, value: %@", command, value ?: @"(no value)"]];
        } else {
            [PushwooshLog pushwooshLog:PW_LL_WARN
                             className:self
                               message:[NSString stringWithFormat:@"Command handler returned NO: %@", command]];
        }
    }
}

#pragma mark - Private Methods

- (BOOL)isSystemPush:(NSDictionary *)userInfo {
    id systemPushValue = userInfo[kPWSystemPushKey];

    if ([systemPushValue isKindOfClass:[NSNumber class]]) {
        return [systemPushValue integerValue] == 1;
    }

    if ([systemPushValue isKindOfClass:[NSString class]]) {
        return [systemPushValue integerValue] == 1;
    }

    return NO;
}

- (NSString *)extractCommand:(NSDictionary *)userInfo {
    id command = userInfo[kPWCommandKey];

    if ([command isKindOfClass:[NSString class]]) {
        return command;
    }

    return nil;
}

@end
