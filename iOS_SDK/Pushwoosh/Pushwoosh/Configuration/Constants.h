//
//  Constants.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2014
//

#ifndef PushNotificationManager_Constants_h
#define PushNotificationManager_Constants_h

#define kBaseDefaultURLOld @"https://cp.pushwoosh.com/json/1.3/"
#define kBaseDefaultURLFormat @"https://%@.api.pushwoosh.com/json/1.3/"
#define kServiceHtmlContentFormatUrl @"https://%@/content/%@"
#define kNotificationAuthorizationStatusUpdated @"KeyNotificationAuthorizationStatusUpdated"

#if TARGET_OS_IPHONE

#define DEVICE_TYPE 1

#else

#define DEVICE_TYPE 7

#endif

#endif
