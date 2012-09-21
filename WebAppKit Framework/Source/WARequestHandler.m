//
//  WSRequestHandler.m
//  WebServer
//
//  Created by Tomas Franzén on 2010-12-08.
//  Copyright 2010 Lighthead Software. All rights reserved.
//

#import "WARequestHandler.h"
#import "WAServerConnection.h"

#import "WARequest.h"
#import "WAResponse.h"
#import "GCDAsyncSocket.h"


@implementation WARequestHandler

- (BOOL)canHandleRequest:(WARequest*)req {
    return NO;
}


- (WARequestHandler*)handlerForRequest:(WARequest*)req {
    return self;
}


- (void)handleRequest:(WARequest*)req response:(WAResponse*)resp socket:(GCDAsyncSocket*)sock {
    [self handleRequest:req response:resp];
}


- (void)handleRequest:(WARequest*)req response:(WAResponse*)resp {}
- (void)connectionDidClose {}

@end