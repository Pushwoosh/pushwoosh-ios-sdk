//
//  PWRegisterEmail.h
//  Pushwoosh
//
//  Created by Kiselev Andrey on 02.10.2020.
//  Copyright © 2020 Pushwoosh. All rights reserved.
//

#import "PWRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWRegisterEmail : PWRequest

@property (nonatomic) NSString *email;

@end

NS_ASSUME_NONNULL_END
