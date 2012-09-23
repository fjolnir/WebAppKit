//
//  WSUtilities.m
//  WebApp
//
//  Created by Tomas Franzén on 2010-12-18.
//  Copyright 2010 Lighthead Software. All rights reserved.
//

#import "WAUtilities.h"
#include <mach/mach.h>
#include <mach/mach_time.h>


NSString *WAGenerateUUIDString(void) {
    CFUUIDRef UUID = CFUUIDCreate(NULL);
    NSString *string = (__bridge_transfer NSString*)CFUUIDCreateString(NULL, UUID);
    CFRelease(UUID);
    return string;
}

uint64_t WANanosecondTime() {
    static mach_timebase_info_data_t timebaseInfo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ mach_timebase_info(&timebaseInfo); });
    return mach_absolute_time() * timebaseInfo.numer / timebaseInfo.denom;
}

NSString *WAApplicationSupportDirectory(void) {
    NSString *name = [[NSBundle mainBundle] bundleIdentifier];
    NSString *root = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    NSString *directory = [root stringByAppendingPathComponent:name];
    if(![[NSFileManager defaultManager] fileExistsAtPath:directory])
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    return directory;
}

NSUInteger WAGetParameterCountForSelector(SEL selector) {
    return [[NSStringFromSelector(selector) componentsSeparatedByString:@":"] count]-1;
}

NSDateFormatter *WAHTTPDateFormatter(void) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"E, dd MMM yyyy HH:mm:ss 'GMT'"];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    });
    return formatter;
}

NSString *WAExtractHeaderValueParameters(NSString *fullValue, NSDictionary **outParams) {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if(outParams) *outParams = params;

    NSInteger split = [fullValue rangeOfString:@";"].location;
    if(split == NSNotFound) return fullValue;
    NSString *basePart = [fullValue substringToIndex:split];
    NSString *parameterPart = [fullValue substringFromIndex:split];

    NSScanner *scanner = [NSScanner scannerWithString:parameterPart];
    for(;;) {
        if(![scanner scanString:@";" intoString:NULL]) break;        
        NSString *attribute = nil;
        if(![scanner scanUpToString:@"=" intoString:&attribute]) break;
        if(!attribute) break;
        [scanner scanString:@"=" intoString:NULL];
        if([scanner isAtEnd]) break;
        unichar c = [parameterPart characterAtIndex:[scanner scanLocation]];
        NSString *value = nil;
        if(c == '"') {
            [scanner scanString:@"\"" intoString:NULL];
            if(![scanner scanUpToString:@"\"" intoString:&value]) break;
            [scanner scanString:@"\"" intoString:NULL];
        } else {
            if(![scanner scanUpToString:@";" intoString:&value]) break;
        }

        params[attribute] = value;
    }
    return basePart;    
}

NSString *WAConstructHTTPStringValue(NSString *string) {
    static NSMutableCharacterSet *invalidTokenSet;
    if(!invalidTokenSet) {
        invalidTokenSet = [[NSCharacterSet ASCIIAlphanumericCharacterSet] mutableCopy];
        [invalidTokenSet addCharactersInString:@"-_."];
        [invalidTokenSet invert];
    }

    if([string rangeOfCharacterFromSet:invalidTokenSet].length) {
        return [NSString stringWithFormat:@"\"%@\"", [string stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
    } else {
        return string;
    }    
}

NSString *WAConstructHTTPParameterString(NSDictionary *params) {
    NSMutableString *string = [NSMutableString string];
    for(NSString *name in params) {
        id value = params[name];
        if(value == [NSNull null])
            [string appendFormat:@"; %@", WAConstructHTTPStringValue(name)];
        else
            [string appendFormat:@"; %@=%@", WAConstructHTTPStringValue(name), WAConstructHTTPStringValue(params[name])];
    }
    return string;
}

BOOL WAAppUsesBundle()
{
    static BOOL result;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        result =  [[[NSBundle mainBundle] bundlePath] hasSuffix:@"app"];
    });
    return result;
}

NSString *WAPathForResource(NSString *name, NSString *type, NSString *directory)
{
    if(WAAppUsesBundle())
        return [[NSBundle mainBundle] pathForResource:name ofType:type inDirectory:directory];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableString *path = [NSMutableString stringWithString:[fileManager currentDirectoryPath]];
    [path appendString:@"/"];
    if(directory) {
        [path appendString:directory];
        if(![directory hasSuffix:@"/"])
            [path appendString:@"/"];
    }
    [path appendString:name];
    if(type) {
        [path appendString:@"."];
        [path appendString:type];
    }

    return [fileManager fileExistsAtPath:path] ? path : nil;
}

static BOOL WADevelopmentMode;

void WASetDevelopmentMode(BOOL enable) {
    WADevelopmentMode = enable;
}

BOOL WAGetDevelopmentMode() {
    return WADevelopmentMode;
}
