#import "utils.h"

/**
本模块的功能
1. 处理提醒弹框
2. 处理键盘弹出
3. 处理应用之间跳转
*/

%hook UIApplication
// 处理应用跳转
- (void)openURL:(NSURL*)url options:(id)options completionHandler:(id)completion {
    NSLog(@"openURL : %@", url);
    
    return;
}

%end


%hook UIKeyboardImpl
//  键盘即将弹出的回调函数
- (void)willMoveToWindow:(id)window {
    %orig;
    // 设置定时器，在键盘弹出3秒后移除键盘
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), 
    	dispatch_get_main_queue(), ^{
    	// 移除键盘API
        [self dismissKeyboard];
    });
}
%end


%hook UIViewController

// 处理应用程序弹框
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated: (BOOL)flag completion:(id)completion {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:nil];
    });
    // NSLog(@"presentViewController: %@", NSStringFromClass([viewControllerToPresent class]));
    // if ([viewControllerToPresent isKindOfClass: [UIAlertController class]]) {
    //    NSLog(@"UIAlertController appear!");
    // }
    // if ([NSStringFromClass([viewControllerToPresent class]) isEqualToString:@"SKStoreProductViewController"]) {
    //    NSLog(@"SKStoreProductViewController appear!");
    //    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    //     	[self dismissViewControllerAnimated:YES completion:nil];
    // 	});
    // }
    // dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    //     [self dismissViewControllerAnimated:YES completion:nil];
    // });
}

%end