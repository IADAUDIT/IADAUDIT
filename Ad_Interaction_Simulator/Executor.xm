#import "utils.h"

/*
本模块的功能：
1. 每过几秒就检查页面UI元素，根据界面UI的情况做响应
2. 实现模拟点击操作
*/

%hook UIViewController

int lastDepth = 1;
int repeattimes = 0;
NSMutableString *lastUI = nil;
NSMutableArray *FinishWindowArray = nil;
NSMutableDictionary<NSString *, NSNumber *> *FinishedWindowDict = nil;
static BOOL isInitialized = NO;

-(void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!isInitialized) {
        lastUI = [[NSMutableString alloc] init];
        FinishWindowArray = [[NSMutableArray alloc] init];
        FinishedWindowDict = [[NSMutableDictionary alloc] init];
        isInitialized = YES;  // 设置为已初始化
    }
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topMostViewController = [keyWindow getTopMostViewController];
    if (self != topMostViewController) {
        return ;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
    NSMutableDictionary *pageRecord = [NSMutableDictionary dictionaryWithContentsOfFile:PAGE_RECORD];
    if (pageRecord == nil) {
        pageRecord = [NSMutableDictionary dictionary];
    }
    NSMutableArray *pageList = pageRecord[@"pagelist"];
    if (pageList == nil) {
        pageList = [NSMutableArray array];
    }
    NSMutableSet *pageSet = [NSMutableSet setWithArray: pageList];
    NSString *pageName = NSStringFromClass([self class]);
    if (![pageSet containsObject: pageName] && self.view.frame.size.height == SCREEN_HEIGHT) {
        [pageSet addObject: pageName];
        pageList = [NSMutableArray arrayWithArray:[pageSet allObjects]];
        pageRecord[@"pagelist"] = pageList;
    }
    NSString *startTime = pageRecord[@"startTime"];
    if (startTime == nil) {
        NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:0]; // 获取当前时间0秒后的时间
        NSTimeInterval time = [startDate timeIntervalSince1970];// 精确到秒(10位)
        startTime = [NSString stringWithFormat:@"%.0f", time];
        pageRecord[@"startTime"] = startTime;
    }
    NSMutableArray *travsePageNumList = pageRecord[@"pageNumList"];
    if (travsePageNumList == nil) {
        travsePageNumList = [NSMutableArray array];
    }
    NSDate *currentDate = [NSDate dateWithTimeIntervalSinceNow:0]; // 获取当前时间0秒后的时间
    NSTimeInterval currentTime = [currentDate timeIntervalSince1970];// 精确到秒(10位)
    NSTimeInterval startTimeValue = [startTime floatValue];
    NSTimeInterval pastTime = currentTime - startTimeValue;
    int pastMinute = pastTime/60;
    NSLog(@"pastMinute is %d", pastMinute );
    int alreadyRecordTime = (int)[travsePageNumList count];
    if (pastMinute > alreadyRecordTime) {
        int currentPageCount = (int)[pageList count];
        NSString *pageCount = [NSString stringWithFormat:@"%d", currentPageCount];
        [travsePageNumList addObject: pageCount];
    }
    pageRecord[@"pageNumList"] = travsePageNumList;
    bool pagerecordflag2 = [pageRecord writeToFile:PAGE_RECORD atomically: YES];
    if (!pagerecordflag2){
        NSLog(@"Failed to write File. PAGE_RECORD write failed");
    }
    });
}

%new
+ (void)checkPageState {
    // 首先判断遍历路径深度
    // 1.
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topMostViewController = [keyWindow getTopMostViewController];

    UINavigationController *navigationController = topMostViewController.navigationController;
    UITabBarController *tabbarController = topMostViewController.tabBarController;
    int currentDepth = (int)[navigationController.childViewControllers count];
    NSMutableDictionary *pathControlInfo = [NSMutableDictionary dictionaryWithContentsOfFile:PATH_CONTROL];
    if (pathControlInfo == nil) {
        pathControlInfo = [NSMutableDictionary dictionary];
    }
    NSString* currentSelectedIndex = pathControlInfo[@"currentSelectedIndex"];
    if(currentSelectedIndex == nil) {
        currentSelectedIndex = @"0";
    }
    // 如果一个tabbarItem遍历动作次数完成之后就切换
    if (currentDepth == 1) {
        // 每次currentDepth == 1时都要更新数据
        currentSelectedIndex = [NSString stringWithFormat:@"%d", (int)tabbarController.selectedIndex];
        pathControlInfo[@"currentSelectedIndex"] = currentSelectedIndex;
    }
    NSString* tabbarActionCount = pathControlInfo[currentSelectedIndex];
    if (tabbarActionCount == nil) {
        NSLog(@"tabbarActionCount is nil");
        tabbarActionCount = @"0";
    }
    //int tabbarItemCount = [tabbarController.childViewControllers count];
    int actionCount = [tabbarActionCount intValue] + 1;
    NSLog(@"current actionCount is %d max actionCount is %d", actionCount, MAX_TABBAR_ACTION);
    if (actionCount > MAX_TABBAR_ACTION && navigationController != nil) {
        // if([currentSelectedIndex intValue] + 1 >= tabbarItemCount ) {
        //     NSLog(@"app travse finished!!! currentSelectedIndex is %@ tabbarItemCount: %d",currentSelectedIndex, tabbarItemCount);
        //     return;
        // }
        NSLog(@"need to performAPI!!");
        [self performAPI];
        return;
    }
    tabbarActionCount = [NSString stringWithFormat:@"%d", actionCount];
    pathControlInfo[currentSelectedIndex] = tabbarActionCount;
    bool pathControlInfoflag = [pathControlInfo writeToFile:PATH_CONTROL atomically:YES];
    if (!pathControlInfoflag){
        NSLog(@"Failed to write File. PATH_CONTROL write failed");
    }
    
    // totalActionCount用于统计整个工具的效率
    NSMutableDictionary *pageRecord = [NSMutableDictionary dictionaryWithContentsOfFile:PAGE_RECORD];
    NSString* totalActionCountStr = pageRecord[@"totalActionCount"];
    int totalActionCount = 1;
    if (totalActionCountStr != nil) {
        totalActionCount = [totalActionCountStr intValue] + 1;
    }
    pageRecord[@"totalActionCount"] = [NSString stringWithFormat:@"%d", totalActionCount];
    NSMutableArray *actionCountList = pageRecord[@"actionCountList"];
    if (actionCountList == nil) {
        actionCountList = [NSMutableArray array];
    }
    NSMutableArray* pageList = pageRecord[@"pagelist"];
    if (totalActionCount % 5 == 0){
        int pagelistCount = (int)[pageList count];
        NSString *pagelistCountStr = [NSString stringWithFormat:@"%d", pagelistCount];
        [actionCountList addObject: pagelistCountStr];
    }
    pageRecord[@"actionCountList"] = actionCountList;
    bool pageRecordflag = [pageRecord writeToFile: PAGE_RECORD atomically: YES];
    if(!pageRecordflag){
        NSLog(@"Failed to write File. PAGE_RECORD write failed");
    }
    // 当遍历深度超过规定深度后，回退
    if (currentDepth >= MAX_DEPTH) {
        NSLog(@"currentDepth is %d max", currentDepth);
        [self performAPI];
        return;
    }

    // 采集布局树
    NSLog(@"begin to fetchLayoutTree");
    NSString *stateName = [UIView fetchLayoutTree];
    NSArray *stateNameArr = [stateName componentsSeparatedByString:@"-"];
    if (stateNameArr == nil || [stateNameArr count] != 2) {
        return;
    }
    NSString *responderName = stateNameArr[0];
    NSString *viewName = stateNameArr[1];
    
    // eventInfo是存放交互信息的字典
    NSMutableDictionary *eventInfo = [NSMutableDictionary dictionaryWithContentsOfFile:ACTION_LIST];
    if (eventInfo == nil) {
        NSLog(@"in checkPageState eventInfo is nil");
        eventInfo = [NSMutableDictionary dictionary];
    }
    NSMutableDictionary *viewEvent = eventInfo[responderName];
    NSMutableArray *centerArray = [viewEvent[viewName] mutableCopy];

    if ([centerArray count] == 0 || centerArray == nil ) {
        // 当前页面的所有UI上下文遍历完成后，回退或者改变tabbar
        NSLog(@" %@ no point to touch", stateName);
        [self performAPI];
    } else {
        [self performClickInPage: stateName];
    }
  
}

%new
+ (NSString *)captureAndSaveScreenshot {
    // 检查并创建ScreenShots子文件夹
    [self createScreenShotsFolderIfNeeded];

    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, NO, [UIScreen mainScreen].scale);
    [keyWindow.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSData *imageData = UIImagePNGRepresentation(image);
    NSString *filePath = [self screenshotFilePath];
    bool imageDataflag = [imageData writeToFile:filePath atomically:YES];
    if(!imageDataflag){
        NSLog(@"Failed to write File. imageData write failed");
    }
    NSLog(@"Screenshot saved at %@", filePath);
    NSString *extractedFilename = [filePath lastPathComponent];

    return extractedFilename;
}

%new
+ (void)createScreenShotsFolderIfNeeded {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    if (![fileManager fileExistsAtPath:ScreenShotsPath]) {
        [fileManager createDirectoryAtPath:ScreenShotsPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"Failed to create directory: %@", error.localizedDescription);
        } else {
            NSLog(@"Successfully created directory at path: %@", ScreenShotsPath);
        }
    }
}

%new
+ (NSString *)screenshotFilePath {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *timestamp = [dateFormatter stringFromDate:[NSDate date]];
    NSString *filename = [NSString stringWithFormat:@"screenshot_%@.png", timestamp];
    NSString *filePath = [ScreenShotsPath stringByAppendingPathComponent:filename];
    return filePath;
}

// 在VC中模拟点击
%new
+ (void)performClickInPage: (NSString *)stateName {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
    NSArray *stateNameArr = [stateName componentsSeparatedByString:@"-"];
    if (stateNameArr == nil || [stateNameArr count] != 2) {
        return;
    }
    NSString *responderName = stateNameArr[0];
    NSString *viewName = stateNameArr[1];
    NSLog(@"stateName : %@ responderName: %@ viewName: %@", stateName, responderName, viewName);
    
    /*
        actionInfo存储了该应用所有需要触发的事件
        Key是ViewController或者UIWindow
        Value是viewActionInfo，用来表征页面的事件
    */
    NSMutableDictionary *actionInfo = [NSMutableDictionary dictionaryWithContentsOfFile:ACTION_LIST];
    if (actionInfo == nil) {
        actionInfo = [NSMutableDictionary dictionary];
    }
    /*
        viewActionInfo存储一个页面需要触发的事件
        Key是ViewController的UIView类名
        Value是UI树
    */
    NSMutableDictionary *viewActionInfo = actionInfo[responderName];
    if(viewActionInfo == nil) {
        NSLog(@"viewActionInfo is nil");
        viewActionInfo = [NSMutableDictionary dictionary];
    }
    NSMutableArray *centerArray = [viewActionInfo[viewName] mutableCopy];
    if (centerArray == nil) {
        centerArray = [NSMutableArray array];
    }

    NSMutableDictionary *finishedDict = [NSMutableDictionary dictionaryWithContentsOfFile:FINISHED_TASK];
    if (finishedDict == nil) {
        finishedDict = [NSMutableDictionary dictionary];
    }
    NSMutableArray *finishedArray = [finishedDict[responderName] mutableCopy];
    if (finishedArray == nil) {
        finishedArray = [NSMutableArray array];
    }
    NSLog(@"in performClickInPage page %@ array count is %lu ", stateName, [centerArray count]);
    
    NSMutableDictionary *positionDict = centerArray[0];
    NSString *name = positionDict[@"name"];
    NSString *strPoint = positionDict[@"center"];
    CGPoint point = CGPointFromString(strPoint);
    NSString *gestureStr = positionDict[@"action"];
    NSString *text = positionDict[@"text"];
    NSLog(@"PTFakeTouch in %@ name is %@ point is %@ gesture is %@ text is %@", stateName, name,strPoint, gestureStr,text);
    NSLog(@"positionDict is %@", positionDict);

    if ([centerArray count] <= 1) {
        centerArray = [NSMutableArray array];
    } else {
        [centerArray removeObjectAtIndex:0];
    }
    [finishedArray addObject: positionDict];

    NSLog(@"==========================");
    viewActionInfo[viewName] = centerArray;
    actionInfo[responderName] = viewActionInfo;
    NSLog(@"viewName is %@ centerArray count is %d", viewName, (int)[centerArray count]);
    bool actionInfoFlag = [actionInfo writeToFile:ACTION_LIST atomically:YES];
    if(!actionInfoFlag){
        NSLog(@"Failed to write File. ACTION_LIST write failed");
    }
     // 截取当前屏幕并保存
    NSString *screenshotName =[self captureAndSaveScreenshot];
    // 存储已经触发过的控件，用于去重
    finishedDict[responderName] = finishedArray;
    bool FinishedDictFlag = [finishedDict writeToFile: FINISHED_TASK atomically:YES];
    if(!FinishedDictFlag){
        NSLog(@"Failed to write File. FINISHED_TASK write failed");
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([gestureStr isEqualToString:@"pan"]) {
            // 手势是滑动
            CGPoint pointSwipeTo = CGPointMake(point.x, point.y - 60);
            if (![positionDict[@"direction"] isEqualToString:@"vertical"]) {
                pointSwipeTo = CGPointMake(point.x - 30, point.y);
            }
            NSLog(@"begin to pan %@ from %@ to %@", positionDict[@"direction"], strPoint, NSStringFromCGPoint(pointSwipeTo));
            NSInteger pointId = [PTFakeMetaTouch fakeTouchId:[PTFakeMetaTouch getAvailablePointId] AtPoint:point withTouchPhase:UITouchPhaseBegan];
            [PTFakeMetaTouch fakeTouchId:pointId AtPoint:pointSwipeTo withTouchPhase:UITouchPhaseMoved];
            [PTFakeMetaTouch fakeTouchId:pointId AtPoint:pointSwipeTo withTouchPhase:UITouchPhaseEnded];
        } else {
            // 手势是点击
            NSLog(@"----------Tap-Tap-Tap-Tap---------");
            NSInteger pointId = [PTFakeMetaTouch fakeTouchId:[PTFakeMetaTouch getAvailablePointId] AtPoint:point withTouchPhase:UITouchPhaseBegan];;
            NSLog(@"Begin PTFakeMetaTouch touch at %@ pointId:%d", strPoint, (int)pointId);
            pointId = [PTFakeMetaTouch fakeTouchId:pointId AtPoint:point withTouchPhase:UITouchPhaseEnded];
            NSLog(@"End PTFakeMetaTouch touch at %@ pointId:%d", strPoint, (int)pointId);
        }
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSMutableString *logContents = [NSMutableString string];
        [logContents appendFormat:@"PTFakeTouch in %@ name is %@ point is %@ gesture is %@ text is %@\n", stateName, name, strPoint, gestureStr, text];
        [logContents appendFormat:@"Screenshot saved as: %@\n\n", screenshotName];
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:LOG_INFO];
        if (!fileHandle) {
            [[NSFileManager defaultManager] createFileAtPath:LOG_INFO contents:nil attributes:nil];
            fileHandle = [NSFileHandle fileHandleForWritingAtPath:LOG_INFO];
        }
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[logContents dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    });
    });
}

%new 
+ (void)performAPIAdvice
{   
   double screen_Width = [UIScreen mainScreen].bounds.size.width;
   double screen_Height = [UIScreen mainScreen].bounds.size.height;

    int r = arc4random_uniform(100);

    if(r > 90){
        // Swipe
        CGPoint startPoint = CGPointMake(screen_Width/2, screen_Height/2);
        CGPoint pointSwipeTo = CGPointMake(startPoint.x, startPoint.y - 60);
        NSInteger pointId = [PTFakeMetaTouch fakeTouchId:[PTFakeMetaTouch getAvailablePointId] AtPoint:startPoint withTouchPhase:UITouchPhaseBegan];
        [PTFakeMetaTouch fakeTouchId:pointId AtPoint:pointSwipeTo withTouchPhase:UITouchPhaseMoved];
        [PTFakeMetaTouch fakeTouchId:pointId AtPoint:pointSwipeTo withTouchPhase:UITouchPhaseEnded];
    }else{
        int randomX = arc4random_uniform(screen_Width);
        int randomY = arc4random_uniform(screen_Height);
        CGPoint tapPoint = CGPointMake(randomX,randomY);

        NSInteger pointId = [PTFakeMetaTouch fakeTouchId:[PTFakeMetaTouch getAvailablePointId] AtPoint:tapPoint withTouchPhase:UITouchPhaseBegan];;
        pointId = [PTFakeMetaTouch fakeTouchId:pointId AtPoint:tapPoint withTouchPhase:UITouchPhaseEnded];
        NSLog(@"click at %@", NSStringFromCGPoint(tapPoint));
    }
}

%new
+ (void)performAPI {
    NSLog(@"in performAPI");
    // 截图记录标志位
    //__block BOOL shouldCaptureScreenshot = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *topMostViewController = [UIViewController getVisibleViewController];
       // NSString *stateName = NSStringFromClass([topMostViewController class]);
        UINavigationController *navigationController = topMostViewController.navigationController; 
        if (topMostViewController.presentingViewController != nil) {
            // 说明当前操作的是presentViewController出来的ViewController
            if (navigationController != nil) {
                if ([navigationController.childViewControllers count] == 1) {
                    // 构造一个右滑手势
                    //构造一个右滑手势
                    CGPoint point = CGPointMake(SCREEN_WIDTH/2 - 30, SCREEN_HEIGHT/2);
                    CGPoint pointSwipeTo = CGPointMake(point.x + 30, point.y);
                    NSInteger pointId = [PTFakeMetaTouch fakeTouchId:[PTFakeMetaTouch getAvailablePointId] AtPoint:point withTouchPhase:UITouchPhaseBegan];
                    NSLog(@"begin to pan from %@ to %@",  NSStringFromCGPoint(point), NSStringFromCGPoint(pointSwipeTo));
                    [PTFakeMetaTouch fakeTouchId:pointId AtPoint:pointSwipeTo withTouchPhase:UITouchPhaseMoved];
                    [PTFakeMetaTouch fakeTouchId:pointId AtPoint:pointSwipeTo withTouchPhase:UITouchPhaseEnded];
                } else {
                    // 借助导航控制器回退
                    NSLog(@"before popViewControllerAnimated");
                    [navigationController popViewControllerAnimated:YES];
                }
            } else {
                // 说明被present的不是navigationcontroller,需要dismiss
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [topMostViewController dismissViewControllerAnimated:YES completion:nil];
                    NSLog(@"dismissViewControllerAnimated");
                });
            }
        } else if (navigationController != nil){
            if ([navigationController.childViewControllers count] == 1) {
                // 导航控制器中只有一个页面，无法再回退
                UITabBarController *tabbarController = [UIViewController getVisibleViewController].tabBarController;
                NSLog(@"before tabBarController：%@ index  change , selectedIndex %lu, tabbar count %lu",NSStringFromClass([tabbarController class]),tabbarController.selectedIndex, [tabbarController.childViewControllers count]);
                if (tabbarController != nil && tabbarController.selectedIndex + 1 < [tabbarController.childViewControllers count]) {
                    tabbarController.selectedIndex ++;
                }
            } else {
                // 借助导航控制器回退
                NSLog(@"before popViewControllerAnimated");
                [[UIViewController getVisibleViewController].navigationController popViewControllerAnimated:YES];
            }
        }
    });
}

%end
