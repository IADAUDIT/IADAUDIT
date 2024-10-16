#import "utils.h"
%hook UIWindow

%new
+ (NSMutableArray *)readScript {
	//1.读取脚本
	NSMutableDictionary *scriptInfo = [NSMutableDictionary dictionaryWithContentsOfFile: STATIC_SCRIPT];
    if (scriptInfo == nil) {
        return nil;
    }
	//2.解析出CallBack Method
	NSArray *callBackList = [scriptInfo allKeys];
	//3.解析出发生transition事件的method
	NSMutableArray* callBackResponders = [NSMutableArray array];
	for (NSString *singleCallBackName in callBackList) {
		NSArray *callBackNameComponents = [singleCallBackName componentsSeparatedByString:@" "];
		NSString *singleCallBackResponder = [callBackNameComponents firstObject];
		[callBackResponders addObject: singleCallBackResponder];
	}
	//NSLog(@"callBackResponders is %@", callBackResponders);
	return callBackResponders;
}

%end