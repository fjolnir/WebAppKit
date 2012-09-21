//
//  TLConditionalExpression.h
//  WebAppKit
//
//  Created by Tomas Franzén on 2011-04-12.
//  Copyright 2011 Lighthead Software. All rights reserved.
//

#import "TLStatement.h"

@interface TLConditional : TLStatement {
    NSArray *conditions;
    NSArray *consequents;
}

- (id)initWithConditions:(NSArray*)conds consequents:(NSArray*)bodies;

@end