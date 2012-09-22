//
//  WSApplication.h
//  WebServer
//
//  Created by Tomas Franzén on 2010-12-09.
//  Copyright 2010 Lighthead Software. All rights reserved.
//

#import <WebAppKit/WARoute.h>

@class WASessionGenerator, WASession, WARequest, WAResponse, WARequestHandler;

extern int WAApplicationMain();

@interface WAApplication : NSObject
@property(readonly, strong) WARequest *request;
@property(readonly, strong) WAResponse *response;
@property(strong) WASessionGenerator *sessionGenerator;
@property(readonly, nonatomic) WASession *session;

+ (int)run;
+ (WAApplication *)applicationOnPort:(NSUInteger)port;

- (id)init;
- (BOOL)start:(NSError**)error;
- (void)invalidate;

- (WARoute*)addRouteSelector:(SEL)sel HTTPMethod:(NSString*)method path:(NSString*)path;

- (WARoute *)handlePath:(NSString *)path forMethod:(NSString *)method with:(WARouteHandlerBlock)block;
- (WARoute *)handleGET:    path with: block;
- (WARoute *)handlePOST:   path with: block;
- (WARoute *)handlePUT:    path with: block;
- (WARoute *)handleDELETE: path with: block;

- (void)addRequestHandler:(WARequestHandler*)handler;
- (void)removeRequestHandler:(WARequestHandler*)handler;
@end