//
//  PWInAppPurchaseHelper.h
//  Pushwoosh
//
//  Created by Vitaly Romanychev on 19.08.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>

@interface PWInAppPurchaseHelper : NSObject

+ (PWInAppPurchaseHelper *)sharedInstance;

- (void)validateProductIdentifiers:(NSArray *)productIdentifiers;

- (void)payWithIdentifier:(NSString *)identifier;

@end
