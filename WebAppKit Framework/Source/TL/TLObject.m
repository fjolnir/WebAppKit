//
//  TLObjectExpression.m
//  WebAppKit
//
//  Created by Tomas Franzén on 2011-04-12.
//  Copyright 2011 Lighthead Software. All rights reserved.
//

#import "TLObject.h"


@implementation TLObject

- (id)initWithObject:(id)obj {
    self = [super init];
    object = obj;
    return self;
}

- (id)evaluateWithScope:(TLScope *)scope {
    return object;
}

- (BOOL)constant {
    return [object isKindOfClass:[NSNumber class]];
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<Object: %@>", object];
}

+ (TLExpression*)trueValue {
    return [[TLObject alloc] initWithObject:@YES];
}

+ (TLExpression*)falseValue {
    return [[TLObject alloc] initWithObject:@NO];
}

+ (TLExpression*)nilValue {
    return [[TLObject alloc] initWithObject:nil];    
}

@end