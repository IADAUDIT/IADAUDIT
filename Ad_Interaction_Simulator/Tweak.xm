#import "utils.h"

/*
该模块负责开启整个流程
*/

%hook UIWindow

static dispatch_once_t onceToken;

- (void)makeKeyAndVisible {
    %orig;
    dispatch_once(&onceToken, ^{
        NSFileManager * manager = [NSFileManager defaultManager];
        // 页面遍历历史记录
        if ([manager fileExistsAtPath:PAGE_HISTORY]) {
            [manager removeItemAtPath:PAGE_HISTORY error:nil];
        }
        // 行为列表
        if ([manager fileExistsAtPath:ACTION_LIST]) {
            [manager removeItemAtPath:ACTION_LIST error:nil];
        }
        // 文本集合
        if ([manager fileExistsAtPath:TEXT_INFO]) {
            [manager removeItemAtPath:TEXT_INFO error:nil];
        }
        // // 界面UI视图树字典
        // if ([manager fileExistsAtPath:LAYOUT_INFO]) {
        //     [manager removeItemAtPath:LAYOUT_INFO error:nil];
        // }
        // 触发过的控件
        if ([manager fileExistsAtPath:FINISHED_TASK]) {
            [manager removeItemAtPath:FINISHED_TASK error:nil];
        }
        // 界面UI路径集合
        if ([manager fileExistsAtPath:UIPATH_SET]) {
            [manager removeItemAtPath:UIPATH_SET error:nil];
        }
        // 界面记录集合
        if ([manager fileExistsAtPath:PAGE_RECORD]) {
            [manager removeItemAtPath:PAGE_RECORD error:nil];
        }
        // 路径控制配置文件
        if ([manager fileExistsAtPath:PATH_CONTROL]) {
            [manager removeItemAtPath:PATH_CONTROL error:nil];
        }

        // if ([manager fileExistsAtPath:LOG_INFO]) {
        //     [manager removeItemAtPath:LOG_INFO error:nil];
        // }

        // NSError *error = nil;
        // //清空ScreenShotsPath文件夹下的所有文件
        // NSArray *fileArray = [manager contentsOfDirectoryAtPath:ScreenShotsPath error:&error];
        // if(!error){
        //     for(NSString *filename in fileArray){
        //         [manager removeItemAtPath:[ScreenShotsPath stringByAppendingPathComponent:filename] error:&error];
        //     }
        // }

        // 截取当前屏幕并保存
        [UIViewController captureAndSaveScreenshot];


        //开启一个定时器，每5秒查询当前页面的
        NSTimer *timer = [NSTimer timerWithTimeInterval:5.0 target:[UIViewController class] selector:@selector(checkPageState) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    });
}

%end





