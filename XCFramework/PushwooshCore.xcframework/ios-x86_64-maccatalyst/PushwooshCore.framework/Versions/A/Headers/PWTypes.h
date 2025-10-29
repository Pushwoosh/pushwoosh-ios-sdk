//
//  PWTypes.h
//  PushwooshCore
//
//  Created by André Kis on 20.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^PushwooshRegistrationHandler)(NSString * _Nullable token, NSError * _Nullable error);
typedef void (^PushwooshGetTagsHandler)(NSDictionary * _Nullable tags);
typedef void (^PushwooshErrorHandler)(NSError * _Nullable error);
