//
//  PWUnarchiver.h
//  Pushwoosh
//
//  Created by Kiselev Andrey on 21.12.2021.
//  Copyright © 2021 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWUnarchiver : NSObject <NSSecureCoding>

- (id)unarchivedObjectOfClasses:(NSSet<Class> *)classes data:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
