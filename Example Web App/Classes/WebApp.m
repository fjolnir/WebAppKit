#import "WebApp.h"

@implementation WebApp

- (id)init
{
	if(!(self = [super init]))
        return nil;
    
    [self handleGET:@"/" with:^(WARequest *request, WAResponse *response) ] {
        WATemplate *template = [WATemplate templateNamed:@"index"]; // Use index.wat
        [template setValue:@"hello world" forKey:@"foo"];
        return template;
    }
    
	return self;
}

@end