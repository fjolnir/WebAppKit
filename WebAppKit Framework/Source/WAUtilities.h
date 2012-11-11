//
//  WSUtilities.h
//  WebApp
//
//  Created by Tomas Franzén on 2010-12-18.
//  Copyright 2010 Lighthead Software. All rights reserved.
//

NSString *WAGenerateUUIDString(void);
uint64_t WANanosecondTime();
NSUInteger WAGetParameterCountForSelector(SEL selector);

NSDateFormatter *WAHTTPDateFormatter(void);
NSString *WAExtractHeaderValueParameters(NSString *fullValue, NSDictionary **outParams);
NSString *WAConstructHTTPStringValue(NSString *string);
NSString *WAConstructHTTPParameterString(NSDictionary *params);

void WASetDevelopmentMode(BOOL enable);
BOOL WAGetDevelopmentMode();