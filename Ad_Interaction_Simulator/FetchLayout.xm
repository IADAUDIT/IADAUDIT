#import "utils.h"

%hook UIViewController

/**
+ (UIViewController *)getVisibleViewController
功能：
1. 获取当前应当处理的UI元素
2. 对UI元素的子控件列表进行优先由上到下，其次由左到右的排序
*/
%new
+ (UIViewController *)getVisibleViewController {
    // 1. 获取topmostwindow
    UIWindow *window = [UIWindow getTopMostWindow];
    //2. 获取topmostviewcontroller
    UIViewController *topmostController = [window getTopMostViewController];
    NSLog(@"getVisibleViewController: %@", NSStringFromClass([topmostController class]));
    return topmostController;
}

%end

/**
本模块的作用在于提取UI视图树
*/

%hook UIView
%new
+ (NSString *)fetchLayoutTree {
    // 1. 获取当前覆盖优先级最高的topmostView
    UIWindow *targetWindow = [UIWindow getTopMostWindow];
    NSLog(@"polyu targetWindow in fetchLayoutTree:%@",NSStringFromClass([targetWindow class]));
    UIView *targetView = [targetWindow getTopMostView];
    NSLog(@"polyu targetView in fetchLayoutTree:%@",NSStringFromClass([targetView class]));
    if (targetView == nil) {
        NSLog(@"targetView is Nil,return");
        // 此时说明可以触发的UI控件都已经触发完毕，需要借助API返回
        [UIViewController performAPI];
        return nil;
    }
    NSString *viewName = NSStringFromClass([targetView class]);

    // 2. 获取字典形式的当前视图，存储在layoutTreeDict中
    // 2.1 获取托管topmostView的ViewController
    id responder = [targetView getViewController];
    if (responder == nil) {
        // 如果当前Window没有添加ViewController托管，那么将当前UIWindow存为responder
        responder = [targetView getWindow];
        if (responder == nil) {
            NSLog(@"responder is Nil,return");
            return nil;
        }
    }
    NSString *responderName = NSStringFromClass([responder class]);
    NSLog(@"responderName in fetchLayoutTreeAdvice:%@",responderName);

    /* 
        layoutInfo保存具体该应用所有的视图布局信息，其中key为ViewController或者UIWindow的类名,
        Value为一个viewLayout是一个字典，key是各个View的名字，Value是布局
    */
    NSMutableDictionary *layoutInfo = [NSMutableDictionary dictionaryWithContentsOfFile: LAYOUT_INFO];
    if (layoutInfo == nil) {
        NSLog(@"layoutInfo is Nil");
        layoutInfo = [NSMutableDictionary dictionary];
    }
    // viewLayout 保存具体某一个ViewController相关的视图，其中key为视图名，Value为字符串形式的布局
    NSMutableDictionary *viewLayout = layoutInfo[responderName];
    if (viewLayout == nil) {
        NSLog(@"viewLayout is Nil");
        viewLayout = [NSMutableDictionary dictionary];
    }
    NSMutableDictionary *layoutTreeDict = [targetView fetchLayoutTreeInView];
    //[targetView collectPathFor:responderName With:layoutTreeDict];

    // 3.将字典形式的主界面UIView转换为json数据格式, 并存入字典
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:layoutTreeDict options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonStr = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    viewLayout[viewName] = jsonStr;
    layoutInfo[responderName] = viewLayout;
    NSArray *lines = [jsonStr componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSLog(@"%@", line);
    }
    [layoutInfo writeToFile: LAYOUT_INFO atomically:YES];

    // 4. 生成当前界面相关的UI交互列表
    // 如果尚未生成过此View的UI交互列表，必须进入generateEventIn的逻辑
    BOOL firstCheckView = NO;
    // 根据界面文案判断是否需要更新UI交互列表
    BOOL needRefresh = [targetView shouldRefreshFor:responderName With:layoutTreeDict];
    NSMutableDictionary *actionInfo = [NSMutableDictionary dictionaryWithContentsOfFile:ACTION_LIST];
    if (actionInfo == nil) {
        firstCheckView = YES;
    } else {
        NSMutableDictionary *viewActionInfo = actionInfo[responderName];
        if (viewActionInfo == nil) {
            firstCheckView = YES;
        } else {
            NSMutableArray *centerArray = viewActionInfo[viewName];
            if (centerArray == nil) {
                firstCheckView = YES;
            }
        }
    }
    if (needRefresh || firstCheckView) {
        [targetView generateEventIn: responderName];
        NSLog(@"need generateEvent");
    }
    NSString *layoutKey = [NSString stringWithFormat:@"%@-%@", responderName, viewName];
    return layoutKey;
}

%new
- (NSMutableDictionary *)fetchLayoutTreeInView {
    NSMutableDictionary *viewDict=[self processViewContent];
    // 此处原计划接入其他功能，目前尚未添加
    return viewDict;
}


%end