//
//  WSApplication.h
//  WebServer
//
//  Created by Tomas Franzén on 2010-12-09.
//  Copyright 2010 Lighthead Software. All rights reserved.
//


@class WARoute, WASessionGenerator, WASession, WARequest, WAResponse, WARequestHandler;

extern int WAApplicationMain();


@interface WAApplication : NSObject
@property(readonly, strong) WARequest *request;
@property(readonly, strong) WAResponse *response;

@property(strong) WASessionGenerator *sessionGenerator;
@property(readonly, nonatomic) WASession *session;

+ (int)run;
- (id)initWithPort:(NSUInteger)port;
- (id)initWithPort:(NSUInteger)port interface:(NSString*)interface;

- (void)invalidate;

- (void)setup;

- (WARoute*)addRouteSelector:(SEL)sel HTTPMethod:(NSString*)method path:(NSString*)path;

- (void)addRequestHandler:(WARequestHandler*)handler;
- (void)removeRequestHandler:(WARequestHandler*)handler;

- (void)preprocess;
- (void)postprocess;
@end