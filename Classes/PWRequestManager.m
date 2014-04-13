//
//  PWRequestManager.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRequestManager.h"

#if ! __has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

@implementation PWRequestManager

+ (PWRequestManager *) sharedManager {
	static PWRequestManager *instance = nil;
	if (!instance) {
		instance = [[PWRequestManager alloc] init];
	}
	return instance;
}

- (BOOL) sendRequest: (PWRequest *) request {
	return [self sendRequest:request error:nil];
}

- (NSString *) defaultBaseUrl {
	NSString *serviceAddressUrl = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"Pushwoosh_BASEURL"];

	if(!serviceAddressUrl) {
		serviceAddressUrl = @"https://cp.pushwoosh.com/json/1.3/";
	}
	
	return serviceAddressUrl;
}

- (BOOL) sendRequest: (PWRequest *) request error:(NSError **)retError {
	NSDictionary *requestDict = [request requestDictionary];
	   
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestDict options:0 error:nil];
    NSString *requestString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	NSString *jsonRequestData = [NSString stringWithFormat:@"{\"request\":%@}", requestString];

	//get the base url
	NSString *serviceAddressUrl = [[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"];
	if(!serviceAddressUrl)
		serviceAddressUrl = [self defaultBaseUrl];

	[[NSUserDefaults standardUserDefaults] setObject:serviceAddressUrl forKey:@"Pushwoosh_BASEURL"];

	//request part
	NSString *requestUrl = [serviceAddressUrl stringByAppendingString:[request methodName]];
	
	NSLog(@"Sending request: %@", jsonRequestData);
	NSLog(@"To urL %@", requestUrl);
	
	NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:requestUrl]];
	[urlRequest setHTTPMethod:@"POST"];
	[urlRequest addValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
	[urlRequest setHTTPBody:[jsonRequestData dataUsingEncoding:NSUTF8StringEncoding]];
	
	//Send data to server
	NSHTTPURLResponse *response = nil;
	NSError *error = nil;
	NSData * responseData = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
	urlRequest = nil;
	
	if(retError)
		*retError = error;
	
	NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
	NSLog(@"Response \"%ld %@\": string: %@", (long)[response statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], responseString);
    
    NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
	
	if(!jsonResult || [jsonResult objectForKey:@"status_code"] == nil) {
		NSString *serviceAddressUrl = [self defaultBaseUrl];
		[[NSUserDefaults standardUserDefaults] setObject:serviceAddressUrl forKey:@"Pushwoosh_BASEURL"];
	}
	
	// honor base url switch
	NSString *newBaseUrl = [jsonResult objectForKey:@"base_url"];
	if(newBaseUrl) {
		[[NSUserDefaults standardUserDefaults] setObject:newBaseUrl forKey:@"Pushwoosh_BASEURL"];
	}
	
	NSInteger pushwooshResult = [[jsonResult objectForKey:@"status_code"] intValue];
	if (response.statusCode != 200 || pushwooshResult != 200)
	{
		if(retError && !error)
			*retError = [NSError errorWithDomain:@"com.pushwoosh" code:response.statusCode userInfo:jsonResult];

		return NO;
	}
	
	[request parseResponse:jsonResult];
	
	return YES;
}

@end
