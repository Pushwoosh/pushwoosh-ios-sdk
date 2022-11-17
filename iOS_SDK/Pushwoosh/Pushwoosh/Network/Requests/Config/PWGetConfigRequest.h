//
//  PWGetConfigRequest.h
//  Pushwoosh
//
//  Created by Anton Kaizer on 27/09/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWRequest.h"
#import "PWChannel.h"

@interface PWGetConfigRequest : PWRequest

@property (nonatomic) NSArray<PWChannel *> *channels;
@property (nonatomic) NSArray<NSString *> *events;
@property (nonatomic) BOOL isLoggerActive;

@end
