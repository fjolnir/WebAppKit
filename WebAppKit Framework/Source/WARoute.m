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

struct Block {
    void *isa;
    int flags;
    int reserved;
    void *invoke;
    struct BlockDescriptor {
        unsigned long reserved;
        unsigned long size;
        void *rest[1];
    } *descriptor;
};

static NSString *signatureForBlock(id blockObj);

@interface WARoute ()
@property(strong) NSArray *components;
@property(strong) NSArray *argumentWildcardMapping;

@property(readwrite, copy) NSString *method;
@property(readwrite, weak) id target;
@property(readwrite, assign) SEL action;

@property(readwrite, copy) WARouteHandlerBlock handlerBlock;
@property(readwrite, assign) BOOL handlerBlockReturnsVoid;

- (void)callVoidBlock:(id)block
            arguments:(__strong id *)args
                count:(NSUInteger)argc;
- (id)callIdBlock:(id)block
        arguments:(__strong id *)args
            count:(NSUInteger)argc;
- (void)callVoidFunction:(void(*)(id,SEL,...))function
                  target:(id)target
                  action:(SEL)action
               arguments:(__strong id*)args
                   count:(NSUInteger)argc;
- (id)callIdFunction:(IMP)function
              target:(id)target
              action:(SEL)action
           arguments:(__strong id *)args
               count:(NSUInteger)argc;
@end

@implementation WARoute
@synthesize components=_components;
@synthesize argumentWildcardMapping=_argumentWildcardMapping;
@synthesize method=_method;
@synthesize target=_target;
@synthesize action=_action;
@synthesize handlerBlock=_handlerBlock;

+ (void)initialize
{
    NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithRanges:NSMakeRange('a', 26), NSMakeRange('A', 26), NSMakeRange('0', 10), NSMakeRange(0, 0)];
    [set addCharactersInString:@"-_."];
    wildcardComponentCharacters = set;
}

+ (NSUInteger)wildcardCountInExpressionComponents:(NSArray*)components
{
    NSUInteger count = 0;
    for(NSString *component in components)
        if([component hasPrefix:@"*"])
            count++;    
    return count;
}

- (void)setWildcardMappingForExpression:(NSString*)expression
{
    NSMutableArray *componentStrings = [[expression componentsSeparatedByString:@"/"] mutableCopy];

    NSUInteger wildcardCount = [[self class] wildcardCountInExpressionComponents:componentStrings];

    if(wildcardCount > 8)
        [NSException raise:NSGenericException format:@"WARoute supports a maxumum of 6 arguments"];

    NSMutableArray *wildcardMapping = [NSMutableArray array];
    for(int i=0; i<wildcardCount; i++) [wildcardMapping addObject:[NSNull null]];

    NSUInteger wildcardCounter = 0;
    for(int i=0; i<[componentStrings count]; i++) {
        NSString *component = componentStrings[i];
        if([component hasPrefix:@"*"]) {
            NSString *indexString = [component substringFromIndex:1];
            NSUInteger argumentIndex = [indexString length] ? [indexString integerValue]-1 : wildcardCounter;
            if(argumentIndex > wildcardCount-1) {
                [NSException raise:NSInvalidArgumentException format:@"Invalid argument index %d in path expression. Must be in the range {1..%d} ", (int)argumentIndex+1, (int)wildcardCount];
            }
            if(wildcardMapping[argumentIndex] != [NSNull null]) {
                [NSException raise:NSInvalidArgumentException format:@"Argument index %d is used more than once in path expression.", (int)argumentIndex+1];    
            }
            wildcardMapping[argumentIndex] = @(wildcardCounter);
            componentStrings[i] = @"*";
            wildcardCounter++;
        }
    }

    self.argumentWildcardMapping = wildcardMapping;
    self.components = componentStrings;
}

- (id)initWithPathExpression:(NSString*)expression method:(NSString*)HTTPMethod target:(id)object action:(SEL)selector
{
    if(!(self = [super init]))
        return nil;
    NSParameterAssert(expression && HTTPMethod && object && selector);

    [self setWildcardMappingForExpression:expression];    
    NSUInteger numArgs = [[NSStringFromSelector(selector) componentsSeparatedByString:@":"] count]-1;

    if(numArgs != self.argumentWildcardMapping.count + 2)
        [NSException raise:NSInvalidArgumentException format:@"The action (%@) must take a number of arguments equal to the wildcard count + request + response (%d).", NSStringFromSelector(selector), (int)self.argumentWildcardMapping.count+2];

    self.method = HTTPMethod;
    self.action = selector;
    self.target = object;

    return self;
}

- (id)initWithPathExpression:(NSString*)expression method:(NSString*)HTTPMethod handler:(WARouteHandlerBlock)handler
{
    if(!(self = [super init]))
        return nil;
    NSParameterAssert(expression && HTTPMethod && handler);
    NSParameterAssert([handler isKindOfClass:NSClassFromString(@"NSBlock")]);

    // Verify the handler returns an object/boid, and only takes object params
    NSString *handlerSig = signatureForBlock(handler);
    if(!handlerSig)
        [NSException exceptionWithName:NSInvalidArgumentException
                                reason:@"Unable to get request handler type signature"
                              userInfo:@{ @"handler": handler }];
    const char *sigStr = [handlerSig UTF8String];
    self.handlerBlockReturnsVoid = sigStr[0] == _C_VOID;
    for(int i = 0; i < [handlerSig length]; ++i) {
        if(sigStr[i] != _C_ID && sigStr[i] != _C_VOID)
            [NSException exceptionWithName:NSInvalidArgumentException
                                    reason:@"Request handlers must take and return only objects"
                                  userInfo:@{ @"handler": handler }];
    }
    
    [self setWildcardMappingForExpression:expression];
    NSUInteger numArgs = [handlerSig length] - 1;
    if(numArgs != self.argumentWildcardMapping.count + 2)
        [NSException raise:NSInvalidArgumentException format:@"The handler block must take a number of arguments equal to the wildcard count + request + response (%ld).", self.argumentWildcardMapping.count+2];
    self.method       = HTTPMethod;
    self.handlerBlock = handler;

    return self;
}


+ (WARoute *)routeWithPathExpression:(NSString*)expr method:(NSString*)m target:(id)object action:(SEL)selector
{
    return [[self alloc] initWithPathExpression:expr method:m target:object action:selector];
}

+ (WARoute *)routeWithPathExpression:(NSString*)expr method:(NSString*)m handler:(WARouteHandlerBlock)handler
{
    return [[self alloc] initWithPathExpression:expr method:m handler:handler];
}

- (BOOL)stringIsValidComponentValue:(NSString*)string
{
    return [[string stringByTrimmingCharactersInSet:wildcardComponentCharacters] length] == 0;
}

- (BOOL)matchesPath:(NSString*)path wildcardValues:(NSArray**)outWildcards
{
    NSArray *givenComponents = [path componentsSeparatedByString:@"/"];
    if([givenComponents count] != [self.components count]) return NO;
    NSMutableArray *wildcardValues = [NSMutableArray array];

    for(NSUInteger i=0; i<[self.components count]; i++) {
        NSString *givenComponent = givenComponents[i];
        NSString *component = (self.components)[i];
        if([component isEqual:@"*"]) {
            if(![self stringIsValidComponentValue:givenComponent])
                return NO;
            [wildcardValues addObject:givenComponent];
        } else {
            if(![givenComponent isEqual:component])
                return NO;
        }
    }
    if(outWildcards) *outWildcards = wildcardValues;
    return YES;    
}

- (BOOL)canHandleRequest:(WARequest*)request
{
    return [request.method isEqual:self.method] && [self matchesPath:request.path wildcardValues:NULL];
}

- (void)handleRequest:(WARequest*)request response:(WAResponse*)response
{
    NSArray *wildcardValues = nil;
    [self matchesPath:request.path wildcardValues:&wildcardValues];

    NSUInteger argCount = [wildcardValues count] + 2;
    id handlerArgs[argCount];

    handlerArgs[0] = request;
    handlerArgs[1] = response;
    for(int i = 0; i < [wildcardValues count]; i++) {
        NSUInteger componentIndex = [(self.argumentWildcardMapping)[i] unsignedIntegerValue];
        handlerArgs[i+2] = wildcardValues[componentIndex];
    }

    id value = nil;
    if(_handlerBlock) {
        if(_handlerBlockReturnsVoid)
            [self callVoidBlock:_handlerBlock arguments:handlerArgs count:argCount];
        else
            value = [self callIdBlock:_handlerBlock arguments:handlerArgs count:argCount];
    } else {
        if([self.target respondsToSelector:@selector(setRequest:response:)])
            [self.target setRequest:request response:response];

        id target = self.target;
        SEL action = self.action;

        Method actionMethod = class_getInstanceMethod([target class], action);
        BOOL hasReturnValue = (method_getTypeEncoding(actionMethod)[0] != 'v');

        if(hasReturnValue) {
            IMP idFunction = method_getImplementation(actionMethod);
            value = [self callIdFunction:idFunction target:target action:action arguments:handlerArgs count:argCount];
        } else {
            void(*voidFunction)(id, SEL, ...) = (void(*)(id, SEL, ...)) method_getImplementation(actionMethod);
            [self callVoidFunction:voidFunction target:target action:action arguments:handlerArgs count:argCount];
        }
        if([self.target respondsToSelector:@selector(setRequest:response:)])
            [target setRequest:nil response:nil];
    }

    if([value isKindOfClass:[WATemplate class]])
        [response appendString:[value result]];
    else if([value isKindOfClass:[NSData class]])
        [response appendBodyData:value];
    else if(value)
        [response appendString:[value description]];

    [response finish];
}


#pragma mark Function dispatchers


- (id)callIdFunction:(IMP)function
              target:(id)target
              action:(SEL)action
           arguments:(__strong id *)args
               count:(NSUInteger)argc
{
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

- (void)callVoidFunction:(void(*)(id,SEL,...))function
                  target:(id)target
                  action:(SEL)action
               arguments:(__strong id*)args
                   count:(NSUInteger)argc
{
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

typedef id (^_idBlockTypeNoArgs)();
typedef id (^_idBlockType)(id, ...);
- (id)callIdBlock:(id)block
        arguments:(__strong id *)args
            count:(NSUInteger)argc
{
    switch(argc) {
        case 0: return ((_idBlockTypeNoArgs)block)();
        case 1: return ((_idBlockType)block)(args[0]);
        case 2: return ((_idBlockType)block)(args[0], args[1]);
        case 3: return ((_idBlockType)block)(args[0], args[1], args[2]);
        case 4: return ((_idBlockType)block)(args[0], args[1], args[2], args[3]);
        case 5: return ((_idBlockType)block)(args[0], args[1], args[2], args[3], args[4]);
        case 6: return ((_idBlockType)block)(args[0], args[1], args[2], args[3], args[4], args[5]);
        case 7: return ((_idBlockType)block)(args[0], args[1], args[2], args[3], args[4], args[5], args[7]);
        case 8: return ((_idBlockType)block)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
    }
    return nil;
}

typedef void (^_voidBlockTypeNoArgs)();
typedef void (^_voidBlockType)(id, ...);
- (void)callVoidBlock:(id)block
          arguments:(__strong id *)args
              count:(NSUInteger)argc
{
    switch(argc) {
        case 0: ((_voidBlockTypeNoArgs)block)();
        case 1: ((_voidBlockType)block)(args[0]);
        case 2: ((_voidBlockType)block)(args[0], args[1]);
        case 3: ((_voidBlockType)block)(args[0], args[1], args[2]);
        case 4: ((_voidBlockType)block)(args[0], args[1], args[2], args[3]);
        case 5: ((_voidBlockType)block)(args[0], args[1], args[2], args[3], args[4]);
        case 6: ((_voidBlockType)block)(args[0], args[1], args[2], args[3], args[4], args[5]);
        case 7: ((_voidBlockType)block)(args[0], args[1], args[2], args[3], args[4], args[5], args[7]);
        case 8: ((_voidBlockType)block)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
    }
}

@end

static NSString *signatureForBlock(id blockObj) {
    struct Block *block = (__bridge void *)blockObj;

    const int copyDisposeFlag = 1 << 25;
    const int signatureFlag   = 1 << 30;

    if(!(block->flags & signatureFlag))
        return nil;

    int index = 0;
    if(block->flags & copyDisposeFlag)
        index += 2;

    NSString *sig = [NSString stringWithUTF8String:block->descriptor->rest[index]];

    sig = [[sig componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789?"]] componentsJoinedByString:@""];

    return sig;
}
