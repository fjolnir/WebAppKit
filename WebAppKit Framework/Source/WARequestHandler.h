//
//  WSRequestHandler.h
//  WebServer
//
//  Created by Tomas Franzén on 2010-12-08.
//  Copyright 2010 Lighthead Software. All rights reserved.
//

@class WARequest, WAResponse, GCDAsyncSocket;

@interface WARequestHandler : NSObject
- (BOOL)canHandleRequest:(WARequest*)req;
- (void)handleRequest:(WARequest*)req response:(WAResponse*)resp;
- (void)handleRequest:(WARequest*)req response:(WAResponse*)resp socket:(GCDAsyncSocket*)sock;

- (WARequestHandler*)handlerForRequest:(WARequest*)req;
- (void)connectionDidClose;
@end