//
//  FTCookie.m
//  ForasteroTest
//
//  Created by Tomas Franzén on 2009-10-14.
//  Copyright 2009 Lighthead Software. All rights reserved.
//

#import "WACookie.h"


@implementation WACookie
@synthesize name=_name;
@synthesize value=_value;
@synthesize path=_path;
@synthesize domain=_domain;
@synthesize expirationDate=_expirationDate;
@synthesize secure=_secure;

- (id)initWithName:(NSString*)cookieName value:(NSString*)cookieValue expirationDate:(NSDate*)date path:(NSString*)p domain:(NSString*)d
{
    if(!(self = [super init])) return nil;

    NSParameterAssert(cookieName && cookieValue);
    self.name = cookieName;
    self.value = cookieValue;
    self.expirationDate = date;
    self.path = p;
    self.domain = d;

    return self;
}

- (id)initWithName:(NSString*)n value:(NSString*)val lifespan:(NSTimeInterval)time path:(NSString*)p domain:(NSString*)d
{
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:time];
    return [self initWithName:n value:val expirationDate:date path:p domain:d];
}

- (id)initWithName:(NSString*)n value:(NSString*)val
{
    return [self initWithName:n value:val expirationDate:nil path:nil domain:nil];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"<%@ %p: %@=%@>", [self class], self, self.name, self.value];
}

- (id)copyWithZone:(NSZone *)zone
{
    WACookie *copy = [[WACookie alloc] initWithName:self.name value:self.value expirationDate:self.expirationDate path:self.path domain:self.domain];
    copy.secure = self.secure;
    return copy;
}

- (NSString*)headerFieldValue
{
    NSMutableString *baseValue = [NSMutableString stringWithFormat:@"%@=%@", WAConstructHTTPStringValue(self.name), WAConstructHTTPStringValue(self.value)];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObject:@"1" forKey:@"Version"];

    if(self.expirationDate) {
        params[@"Max-Age"] = [NSString stringWithFormat:@"%qu", (uint64_t)[self.expirationDate timeIntervalSinceNow]];
        // Compatibility with the old Netscape spec
        params[@"Expires"] = [[[self class] expiryDateFormatter] stringFromDate:self.expirationDate];
    }

    if(self.path) params[@"Path"] = self.path;    
    if(self.domain) params[@"Domain"] = self.domain;
    if(self.secure) params[@"Secure"] = [NSNull null];

    return [baseValue stringByAppendingString:WAConstructHTTPParameterString(params)];
}

// Old Netscape date format
+ (NSDateFormatter*)expiryDateFormatter
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"EEE, dd-MMM-y HH:mm:ss 'GMT'"];
        [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
    });
    return formatter;
}

+ (NSSet*)cookiesFromHeaderValue:(NSString*)headerValue
{
    NSScanner *s = [NSScanner scannerWithString:headerValue];
    NSMutableSet *cookies = [NSMutableSet set];

    while(1) {
        NSString *name, *value;
        if(![s scanUpToString:@"=" intoString:&name]) break;
        if(![s scanString:@"=" intoString:NULL]) break;
        if(![s scanUpToString:@";" intoString:&value] && !value) break;
        [s scanString:@";" intoString:NULL];

        WACookie *c = [[WACookie alloc] initWithName:name value:value expirationDate:nil path:nil domain:nil];
        [cookies addObject:c];
    }
    return cookies;
}

+ (id)expiredCookieWithName:(NSString*)name
{
    return [[self alloc] initWithName:name value:@"" lifespan:-10000 path:nil domain:nil];
}

@end