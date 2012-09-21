//
//  WSRoute.m
//  WebServer
//
//  Created by Tomas Franzén on 2010-12-09.
//  Copyright 2010 Lighthead Software. All rights reserved.
//

#import "WARoute.h"
#import "WARequest.h"
#import "WAResponse.h"
#import "WAApplication.h"
#import "WATemplate.h"
#import "WAPrivate.h"

#import <objc/runtime.h>


static NSCharacterSet *wildcardComponentCharacters;

@interface WARoute ()
@property(strong) NSArray *components;
@property(strong) NSArray *argumentWildcardMapping;

@property(readwrite, copy) NSString *method;
@property(readwrite, weak) id target;
@property(readwrite, assign) SEL action;
@end



@implementation WARoute
@synthesize components=_components;
@synthesize argumentWildcardMapping=_argumentWildcardMapping;
@synthesize method=_method;
@synthesize target=_target;
@synthesize action=_action;


+ (void)initialize {
	NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithRanges:NSMakeRange('a', 26), NSMakeRange('A', 26), NSMakeRange('0', 10), NSMakeRange(0, 0)];
	[set addCharactersInString:@"-_."];
	wildcardComponentCharacters = set;
}


+ (NSUInteger)wildcardCountInExpressionComponents:(NSArray*)components {
	NSUInteger count = 0;
	for(NSString *component in components)
		if([component hasPrefix:@"*"])
			count++;	
	return count;
}


- (void)setWildcardMappingForExpression:(NSString*)expression {
	NSMutableArray *componentStrings = [[expression componentsSeparatedByString:@"/"] mutableCopy];

	NSUInteger wildcardCount = [[self class] wildcardCountInExpressionComponents:componentStrings];
	
	if(wildcardCount > 8)
		[NSException raise:NSGenericException format:@"WARoute supports a maxumum of 6 arguments"];
	
	NSMutableArray *wildcardMapping = [NSMutableArray array];
	for(int i=0; i<wildcardCount; i++) [wildcardMapping addObject:[NSNull null]];
	
	NSUInteger wildcardCounter = 0;
	for(int i=0; i<[componentStrings count]; i++) {
		NSString *component = [componentStrings objectAtIndex:i];
		if([component hasPrefix:@"*"]) {
			NSString *indexString = [component substringFromIndex:1];
			NSUInteger argumentIndex = [indexString length] ? [indexString integerValue]-1 : wildcardCounter;
			if(argumentIndex > wildcardCount-1) {
				[NSException raise:NSInvalidArgumentException format:@"Invalid argument index %d in path expression. Must be in the range {1..%d}", (int)argumentIndex+1, (int)wildcardCount];
			}
			if([wildcardMapping objectAtIndex:argumentIndex] != [NSNull null]) {
				[NSException raise:NSInvalidArgumentException format:@"Argument index %d is used more than once in path expression.", (int)argumentIndex+1];	
			}
			[wildcardMapping replaceObjectAtIndex:argumentIndex withObject:[NSNumber numberWithUnsignedInteger:wildcardCounter]];
			[componentStrings replaceObjectAtIndex:i withObject:@"*"];
			wildcardCounter++;
		}
	}
	
	self.argumentWildcardMapping = wildcardMapping;
	self.components = componentStrings;
}


- (id)initWithPathExpression:(NSString*)expression method:(NSString*)HTTPMetod target:(id)object action:(SEL)selector {
	if(!(self = [super init])) return nil;
	NSParameterAssert(expression && HTTPMetod && object && selector);

	[self setWildcardMappingForExpression:expression];	
	NSUInteger numArgs = [[NSStringFromSelector(selector) componentsSeparatedByString:@":"] count]-1;
	
	if(numArgs != self.argumentWildcardMapping.count + 2)
		[NSException raise:NSInvalidArgumentException format:@"The action (%@) must take a number of arguments equal to the wildcard count + request + response (%d).", NSStringFromSelector(selector), (int)self.argumentWildcardMapping.count+2];
	
	self.method = HTTPMetod;
	self.action = selector;
	self.target = object;
	
	return self;
}


+ (id)routeWithPathExpression:(NSString*)expr method:(NSString*)m target:(id)object action:(SEL)selector {
	return [[self alloc] initWithPathExpression:expr method:m target:object action:selector];
}


- (BOOL)stringIsValidComponentValue:(NSString*)string {
	return [[string stringByTrimmingCharactersInSet:wildcardComponentCharacters] length] == 0;
}


- (BOOL)matchesPath:(NSString*)path wildcardValues:(NSArray**)outWildcards {
	NSArray *givenComponents = [path componentsSeparatedByString:@"/"];
	if([givenComponents count] != [self.components count]) return NO;
	NSMutableArray *wildcardValues = [NSMutableArray array];
	
	for(NSUInteger i=0; i<[self.components count]; i++) {
		NSString *givenComponent = [givenComponents objectAtIndex:i];
		NSString *component = [self.components objectAtIndex:i];
		if([component isEqual:@"*"]) {
			if(![self stringIsValidComponentValue:givenComponent])
				return NO;
			[wildcardValues addObject:givenComponent];
		} else{
			if(![givenComponent isEqual:component])
				return NO;
		}
	}
	if(outWildcards) *outWildcards = wildcardValues;
	return YES;	
}


- (BOOL)canHandleRequest:(WARequest*)request {
	return [request.method isEqual:self.method] && [self matchesPath:request.path wildcardValues:NULL];
}



- (id)callIdFunction:(IMP)function target:(id)target action:(SEL)action arguments:(__strong id *)args count:(NSUInteger)argc {
	switch(argc) {
		case 0: return function(target, action);
		case 1: return function(target, action, args[0]);
		case 2: return function(target, action, args[0], args[1]);
		case 3: return function(target, action, args[0], args[1], args[2]);
		case 4: return function(target, action, args[0], args[1], args[2], args[3]);
		case 5: return function(target, action, args[0], args[1], args[2], args[3], args[4]);
		case 6: return function(target, action, args[0], args[1], args[2], args[3], args[4], args[5]);
		case 7: return function(target, action, args[0], args[1], args[2], args[3], args[4], args[5], args[7]);
		case 8: return function(target, action, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
	}
	return nil;
}


- (void)callVoidFunction:(void(*)(id,SEL,...))function target:(id)target action:(SEL)action arguments:(__strong id*)args count:(NSUInteger)argc {
	switch(argc) {
		case 0: return function(target, action);
		case 1: return function(target, action, args[0]);
		case 2: return function(target, action, args[0], args[1]);
		case 3: return function(target, action, args[0], args[1], args[2]);
		case 4: return function(target, action, args[0], args[1], args[2], args[3]);
		case 5: return function(target, action, args[0], args[1], args[2], args[3], args[4]);
		case 6: return function(target, action, args[0], args[1], args[2], args[3], args[4], args[5]);
		case 7: return function(target, action, args[0], args[1], args[2], args[3], args[4], args[5], args[7]);
		case 8: return function(target, action, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
	}
}


- (void)handleRequest:(WARequest*)request response:(WAResponse*)response {
	NSArray *wildcardValues = nil;
	[self matchesPath:request.path wildcardValues:&wildcardValues];
	
	NSUInteger argCount = [wildcardValues count] + 2;
	id handlerArgs[argCount];

    handlerArgs[0] = request;
    NSLog(@">>>%@", request);
    handlerArgs[1] = response;
	for(int i = 0; i < [wildcardValues count]; i++) {
		NSUInteger componentIndex = [[self.argumentWildcardMapping objectAtIndex:i] unsignedIntegerValue];
		handlerArgs[i+2] = [wildcardValues objectAtIndex:componentIndex];
	}

	if([self.target respondsToSelector:@selector(setRequest:response:)])
        [self.target setRequest:request response:response];
    if([self.target respondsToSelector:@selector(preprocess)])
        [self.target preprocess];
	
	id target = self.target;
	SEL action = self.action;
	
	Method actionMethod = class_getInstanceMethod([target class], action);
	BOOL hasReturnValue = (method_getTypeEncoding(actionMethod)[0] != 'v');
	
	
	if(hasReturnValue) {
		IMP idFunction = method_getImplementation(actionMethod);
		id value = [self callIdFunction:idFunction target:target action:action arguments:handlerArgs count:argCount];
		
		if([value isKindOfClass:[WATemplate class]])
			[response appendString:[value result]];
		else if([value isKindOfClass:[NSData class]])
			[response appendBodyData:value];
		else
			[response appendString:[value description]];
	}else{
		void(*voidFunction)(id, SEL, ...) = (void(*)(id, SEL, ...)) method_getImplementation(actionMethod);
		[self callVoidFunction:voidFunction target:target action:action arguments:handlerArgs count:argCount];
	}
	
    if([self.target respondsToSelector:@selector(postprocess)])
        [target postprocess];
	if([self.target respondsToSelector:@selector(setRequest:response:)])
        [target setRequest:nil response:nil];
	[response finish];
}


@end