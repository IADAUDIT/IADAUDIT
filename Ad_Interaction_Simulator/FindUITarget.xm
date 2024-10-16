#import "utils.h"
#import "allResponder.h"

%hook UIView

/*
    作为一个View，找到托管自己所在页面的ViewController
*/
%new
-(NSString *)getResponderName {
    //NSString *viewName = NSStringFromClass([self class]);
    id responder = [self getViewController];
    if (responder == nil) {
        responder = [self getWindow];
        if (responder == nil) {
            return nil;
        }
    }
    NSString *responderName = NSStringFromClass([responder class]);
    return responderName;
}

/*
    作为一个View，找到自己所在页面的交互列表
*/
%new
-(NSMutableDictionary *)getViewActionInfo {
    NSString *responderName = [self getResponderName];
    if (responderName == nil) {
        return nil;
    }
    NSMutableDictionary *actionInfo = [NSMutableDictionary dictionaryWithContentsOfFile:ACTION_LIST];
    if (actionInfo == nil) {
        actionInfo = [NSMutableDictionary dictionary];
    }
    NSMutableDictionary *viewActionInfo = actionInfo[responderName];
    if (viewActionInfo == nil) {
        viewActionInfo = [NSMutableDictionary dictionary];
    }
    return viewActionInfo;
}

/*
    用于判断一个View（包括其子View）是否被交互完毕
*/
%new
-(BOOL)touchCompleted {
    // 根据UI交互列表内容判断当前View是否已经被交互过，如果交互过再考察其中所有控件是否被交互完成
    NSString *viewName = NSStringFromClass([self class]);
    NSMutableDictionary *viewActionInfo = [self getViewActionInfo];
    if ([[viewActionInfo allKeys] containsObject:viewName]) {
        // 该View存在于交互列表中，证明已经被交互过
        NSMutableArray *centerArray = viewActionInfo[viewName];
        if ([centerArray count] == 0) {
            // 已经被交互完毕
            return YES;
        }
    }
    return NO;
}

/*
    作为一个View，找到管辖自身的ViewController
*/
%new
- (UIViewController *)getViewController {
    // 经由iOS系统的事件响应链获取管辖自身的ViewController
    id nextNode = self;
    while ((![nextNode isKindOfClass: [UIViewController class]]) && (![nextNode isKindOfClass: [UIWindow class]]) && (![nextNode isKindOfClass: [UIApplication class]])) {
        nextNode = [nextNode nextResponder];
    }
    UIViewController *resultViewController = nil;
    if ([nextNode isKindOfClass: [UIViewController class]]) {
        resultViewController = nextNode;
    }
    return resultViewController;
}


/*
     作为一个View，找到自身所在的UIWindow
*/
%new
- (UIWindow *)getWindow {
    // 经由iOS系统的事件响应链获取自身所在的UIWindow
    NSLog(@"getwindow begin");
    id nextNode = [self nextResponder];
    NSLog(@"nextNode is %@", NSStringFromClass([nextNode class]));
    while (![nextNode isKindOfClass: [UIWindow class]] && nextNode != nil) {
        NSLog(@"nextNode is %@", NSStringFromClass([nextNode class]));
        if (@available(iOS 13.0, *)) {
            if ([nextNode isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)nextNode;
                UIWindow *topWindow = nil;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        topWindow = window;
                        break;
                    }
                }
                if (!topWindow) {
                    topWindow = windowScene.windows.firstObject;
                }
                return topWindow;
            }
        }
        nextNode = [nextNode nextResponder];
    }
    UIWindow *resultWindow = nextNode;
    return resultWindow;
}

%end


%hook UIWindow

/*
    获取覆盖优先级最高的Window,覆盖优先级存储在UIWindow的成员变量windowLevel中
*/

%new
+(UIWindow *)getTopMostWindow {
    // 1. 获取UIApplication的window列表
    NSMutableArray *windowList = [NSMutableArray arrayWithArray:[UIApplication sharedApplication].windows];
    
    // 2. 从window列表中获取用户可以交互的最顶层window
    CGFloat topWindowLevel = -1.0;
    UIWindow *topMostWindow = nil;
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    // tips:实验过程中发现，存在UIApplication持有的keyWindow不在windowList的情况，所以这里判断一次如果不在其中就添加上
    BOOL containsKeyWindow = [windowList containsObject: keyWindow];
    if (!containsKeyWindow) {
        [windowList addObject: keyWindow];
    }
    for(UIWindow *window in [windowList reverseObjectEnumerator]) {
        // 系统自带的UITextEffectsWindow和UIStatusBarWindow无需交互
        if ([NSStringFromClass([window class]) isEqualToString:@"UITextEffectsWindow"]||[NSStringFromClass([window class]) isEqualToString:@"UIStatusBarWindow"]) {
            continue;
        } else if ([NSStringFromClass([window class]) hasSuffix:@"EffectWindow"]){
            continue;
        }
        CGFloat currentWindowLevel = window.windowLevel;

        if (currentWindowLevel > topWindowLevel && window.hidden == NO && (![NSStringFromClass([window class]) containsString:@"Keyboard"])) {
            topWindowLevel = currentWindowLevel;
            topMostWindow = window;
        }
    }
    NSLog(@"top most window is %@ windowlevel is %lf", NSStringFromClass([topMostWindow class]), topWindowLevel );
    return topMostWindow;
}


%new
-(NSMutableArray *)getViewControllerHierarchy:(UIViewController *)viewController
{   
    NSMutableArray *result = [NSMutableArray array];

    UIViewController *topMostViewController = viewController;
    [result addObject: topMostViewController];

    if (viewController == nil) {
        return result;
    } 

    if ([viewController respondsToSelector:@selector(topViewController)]) {
        // rootViewController是NavigationController
        UINavigationController *navigationController = (UINavigationController *)viewController;
        UIViewController* childViewController = [navigationController topViewController];
        if ([childViewController respondsToSelector:@selector(selectedViewController)]) {
            // navigationcontroller持有tabbarcontroller的情况
            NSMutableArray* temp = [self getViewControllerHierarchy: childViewController];
            [result addObjectsFromArray: temp];
        } else {
            topMostViewController = childViewController;
            [result addObject:  topMostViewController];
        }
    } else if ([viewController respondsToSelector:@selector(selectedViewController)]) {
        // rootViewController是TabBarController
        UITabBarController *tabBarController = (UITabBarController *)viewController;
        UIViewController *childViewController = tabBarController.selectedViewController;
        if ([childViewController respondsToSelector:@selector(topViewController)]){
            // tabbarcontroller持有navigationcontroller的情况
            NSMutableArray* temp = [self getViewControllerHierarchy:childViewController ];
            [result addObjectsFromArray: temp];
        } else {
            topMostViewController = childViewController;
            [result addObject: topMostViewController];
        }
        
    } else {
        /*
            根据实验，存在rootViewController不是用于页面管理的NavigationController或者TabbarController的情况
            这种情况下，通常rootViewController的子Controller是用于页面管理的NavigationController或者TabbarController
            所以这里采用递归的方式对子ViewController进行检索
        */
        for (UIViewController *childController in viewController.childViewControllers ){
            NSMutableArray* temp = [self getViewControllerHierarchy: childController];
            [result addObjectsFromArray: temp];
            break;
        }
    }

    // 处理界面是Modal页面的情况
    UIViewController *presentedVC = topMostViewController.presentedViewController;
    if (presentedVC != nil) {
        NSMutableArray* temp = [self getViewControllerHierarchy: presentedVC];
        [result addObjectsFromArray: temp];
    }

    return result;
}


/*
功能：作为window，找到负责最顶层页面的ViewController
*/
%new
-(UIViewController *)getTopMostViewController {
    UIViewController *rootController = self.rootViewController;
    UIViewController *topMostViewController = [self processGetTopMostViewControllerIn: rootController];
    return topMostViewController;
}

/*
功能：作为window，依托自身持有的rootViewController找到负责最顶层页面的ViewController
*/
%new
- (UIViewController *)processGetTopMostViewControllerIn:(UIViewController *)viewController {
    // 参数viewController是某一个UIWindow持有的rootViewController
    UIViewController *topMostViewController = viewController;
    if (viewController == nil) {
        return nil;
    } 
    /*
        根据界面组织方式来寻找托管当前页面的ViewController,iOS中主流的界面组织方式有2种：
        （1）UIWindow持有NavigationController作为rootViewController,NavigationController再
            持有TabBarController管理页面ViewController;
        （2）UIWindow持有TabbarController作为rootViewController,TabbarController再
            持有NavigationController管理页面ViewController;
    */
    if ([viewController respondsToSelector:@selector(topViewController)]) {
        // rootViewController是NavigationController
        UINavigationController *navigationController = (UINavigationController *)viewController;
        UIViewController* childViewController = [navigationController topViewController];
        if ([childViewController respondsToSelector:@selector(selectedViewController)]) {
            // navigationcontroller持有tabbarcontroller的情况
            topMostViewController = [self processGetTopMostViewControllerIn: childViewController];
        } else {
            topMostViewController = childViewController;
        }
    } else if ([viewController respondsToSelector:@selector(selectedViewController)]) {
        // rootViewController是TabBarController
        UITabBarController *tabBarController = (UITabBarController *)viewController;
        UIViewController *childViewController = tabBarController.selectedViewController;
        if ([childViewController respondsToSelector:@selector(topViewController)]){
            // tabbarcontroller持有navigationcontroller的情况
            topMostViewController = [self processGetTopMostViewControllerIn:childViewController ];
        } else {
            topMostViewController = childViewController;
        }
        
    } else {
        /*
            根据实验，存在rootViewController不是用于页面管理的NavigationController或者TabbarController的情况
            这种情况下，通常rootViewController的子Controller是用于页面管理的NavigationController或者TabbarController
            所以这里采用递归的方式对子ViewController进行检索
        */
        for (UIViewController *childController in viewController.childViewControllers ){
            UIViewController *childTopMostViewController = [self processGetTopMostViewControllerIn: childController];
            
            if (childTopMostViewController != nil) {
                if (childTopMostViewController != childController){
                    topMostViewController = childTopMostViewController;
                    break;
                }
            }
        }
    }

    // 处理界面是Modal页面的情况
    UIViewController *presentedVC = topMostViewController.presentedViewController;
    if (presentedVC != nil) {
        topMostViewController = [self processGetTopMostViewControllerIn: presentedVC];
    }
    return topMostViewController;
}



%new
- (NSMutableArray *)getSubViewsAdvice:(UIView *)contentView
{
    NSMutableArray *allChildviews = [NSMutableArray array];
    NSMutableArray *childViewList = [NSMutableArray arrayWithArray:contentView.subviews];
        
    for (UIView *childView in childViewList) {
        [allChildviews addObject:childView];
        // 不需要再下去了
        //|| [childView isKindOfClass: [UIImageView class]]
        if ([childView isKindOfClass: [UIButton class]] ) {
            continue;
        }

        NSMutableArray *tempList = [self getSubViewsAdvice: childView];
        [allChildviews addObjectsFromArray:tempList];        
    }
    return allChildviews; 
}



%new
- (NSMutableArray *)getSubViewhierarchyAdvice:(UIView *)contentView
{   
    tableViewStack = [NSMutableArray array];
    subViewhierarchyDict = [NSMutableDictionary dictionary];

    NSMutableArray * temp = [NSMutableArray array];
    [temp addObject:@"Entry"];

    NSString* number1 = [NSString stringWithFormat:@"%@:%d",NSStringFromClass([contentView class]),0];
    [temp addObject:number1];

    [subViewhierarchyDict setObject:temp forKey:[NSValue valueWithNonretainedObject:contentView]];
    //subViewhierarchyDict 中保存的是 <当前的View，(父亲节点， 自己的类型，自己在父亲节点中的位置)>

    [UIWindow processGetSubViewhierarchyAdvice:contentView];

    NSMutableArray * getSubView_result = [NSMutableArray array];
    [getSubView_result addObject:subViewhierarchyDict];

    return getSubView_result;
}


// subViewhierarchyDict：<view的指针，数组[自己在父亲的index]>
%new
+(void) processGetSubViewhierarchyAdvice:(UIView *)contentView
{   
    //subViewhierarchyDict 中保存的是 <当前的View，(父亲节点， 自己的类型，自己在父亲节点中的位置)>

    //获得父亲节点的高度
    NSMutableArray *parent = subViewhierarchyDict[[NSValue valueWithNonretainedObject:contentView]];

    //TODO: contentView to parent
    NSMutableArray *childViewList = [NSMutableArray arrayWithArray:contentView.subviews];

    NSMutableDictionary *subviewCategory = [NSMutableDictionary dictionary];

    //归类，相同类别的控件归为一类。
    for(UIView *childView in childViewList){
        if(subviewCategory[NSStringFromClass([childView class])] == nil){
            subviewCategory[NSStringFromClass([childView class])] = [NSMutableArray array];
        }

        [subviewCategory[NSStringFromClass([childView class])] addObject:childView];
    }

     // UITableView入栈 等待子cell遍历
    if([contentView isKindOfClass: [UITableView class]]){
        NSLog(@"Current is UITableView");
        [tableViewStack addObject:contentView];
    }

    for (UIView *childView in childViewList) {
        NSMutableArray *myhierarchy = [parent mutableCopy];
        //现在已经有 父节点的路径：父节点类型：父节点在爷爷节点中的index

        NSUInteger index = [subviewCategory[NSStringFromClass([childView class])] indexOfObject:childView];
        NSString* myNum = [NSString stringWithFormat:@"%@:%d",NSStringFromClass([childView class]),(int)index];
        
        //选用section:Item的形式 
        if([childView isKindOfClass: [UITableViewCell class]]){
            int stackcount = [tableViewStack count];
            NSIndexPath* cell_index = [(UITableView *)[tableViewStack objectAtIndex:stackcount-1] indexPathForCell:(UITableViewCell *)childView];
            if(cell_index != nil){
                //myNum = [NSString stringWithFormat:@"%@:%d:%d",NSStringFromClass([childView class]),(int)cell_index.section,(int)cell_index.item];
                myNum = [NSString stringWithFormat:@"%@:%d",NSStringFromClass([childView class]),(int)cell_index.row];
            }
        }
        
        [myhierarchy addObject:myNum];

        [subViewhierarchyDict setObject:myhierarchy forKey:[NSValue valueWithNonretainedObject:childView]];

        // 不需要再下去了
        if ([childView isKindOfClass: [UIButton class]] 
        || [NSStringFromClass([childView class]) rangeOfString:@"UITabBarButton"].location != NSNotFound
        || [NSStringFromClass([childView class]) rangeOfString:@"UIBarBackground"].location != NSNotFound) {
            continue;
        }

        [UIWindow processGetSubViewhierarchyAdvice: childView];
    }

    // UITableView的子cell遍历结束以后 出栈
    if([contentView isKindOfClass: [UITableView class]]){
        int stackcount = [tableViewStack count];
        [tableViewStack removeObjectAtIndex:stackcount-1];
    }
}



/**
1. 容器类ViewController响应链：
    1.1 【UILayoutContainerView】: ViewController响应链的第一级节点
    1.2 【UITransitionView/UINavigationTransitionView】: ViewController响应链的第二级节点
    1.3 【UIViewControllerWrapperView】: ViewController响应链的第三级节点
2. 普通ViewController响应链:
    2.1 UIView就是ViewController响应链的第一级节点
*/
%new
-(UIView *)getTopMostView{
    UIView *topMostView = [self processGetTopMostViewWith: self];
    NSLog(@"topMostView is %@", NSStringFromClass([topMostView class]));

    return topMostView;
}


%new
-(UIView *)processGetTopMostViewWith:(UIView *)contentView {

    UIView *topMostView = nil;
    // 1. 首先获取当前contentView的subviews
    NSMutableArray *childViewList = [NSMutableArray arrayWithArray:contentView.subviews ];
    if(childViewList == nil || [childViewList count] == 0 || contentView.hidden == YES ){
        // base情况，如果当前已经是最底层的view
        return nil;
    }

    // respondController:托管当前view的ViewController
    UIViewController *respondController = [contentView getViewController];
    // pageViewController:托管当前页面的ViewController
    UIViewController *pageViewController = [self getTopMostViewController];
    // parentViewController：托管superView的viewcontroller
    //UIViewController *parentViewController = [contentView.superview getViewController];


    //NSLog(@"polyu respondController in processGetTopMo: %@", NSStringFromClass([respondController class]));
    //NSLog(@"polyu pageViewController in processGetTopMo: %@", NSStringFromClass([pageViewController class]));
    //NSLog(@"polyu parentViewController in processGetTopMo: %@", NSStringFromClass([parentViewController class]));
    
    /*
    核心思想：
    1， 通过respondCotroller和PageViewController的关系获取Window的主View
    2, 依据View尺寸判定添加在该window上的弹出view
    */
    if (contentView.frame.size.width == SCREEN_WIDTH && contentView.frame.size.height == SCREEN_HEIGHT) {
        // TODO: && [parentViewController.childViewControllers containsObject: respondController]
        if (respondController == pageViewController ) {
            // 这里直接可以获取到主页面视图View
            topMostView = contentView;
        } else {
            // 将子视图TabBar和NavigationBar放在orderedViewList最前面
            NSMutableArray *tabBarList = [NSMutableArray array];
            NSMutableArray *navigationList = [NSMutableArray array];
            for (UIView *childView in childViewList) {
                if ([childView isKindOfClass:[UITabBar class]]) {
                    [tabBarList addObject: childView];
                } else if ([NSStringFromClass([childView class]) containsString:@"tabbar" ]||[NSStringFromClass([childView class]) containsString:@"Tabbar"]||[NSStringFromClass([childView class]) containsString:@"tabBar"]||[NSStringFromClass([childView class]) containsString:@"TabBar"]) {
                    [tabBarList addObject: childView];
                } else if ([childView isKindOfClass:[UINavigationBar class]]) {
                    [navigationList addObject: childView];
                } else if ([NSStringFromClass([childView class]) containsString:@"navigationbar" ]||[NSStringFromClass([childView class]) containsString:@"Navigationbar"]||[NSStringFromClass([childView class]) containsString:@"navigationBar"]||[NSStringFromClass([childView class]) containsString:@"NavigationBar"]){
                    [navigationList addObject: childView];
                } else if([[childView getViewController] respondsToSelector:@selector(topViewController)]&& childView.frame.size.height < SCREEN_HEIGHT){
                    NSLog(@"add to navigationList:%@", NSStringFromClass([childView class]));
                    [navigationList addObject: childView];
                } else if([[childView getViewController] respondsToSelector:@selector(selectedViewController)] && childView.frame.size.height < SCREEN_HEIGHT){
                    NSLog(@"add to tabbarList:%@", NSStringFromClass([childView class]));
                    [tabBarList addObject: childView];
                }
            }
            for (UIView *childView in tabBarList) {
                [childViewList removeObject: childView];
            }
            for (UIView *childView in navigationList) {
                [childViewList removeObject: childView];
            }
            [navigationList addObjectsFromArray:tabBarList];
            [navigationList addObjectsFromArray:childViewList];
            NSMutableArray *orderedViewList = navigationList;

            // 倒序查找orderedViewList中的子视图，NavigationBar和TabBar放在最后交互
            for(UIView *chlidView in [orderedViewList reverseObjectEnumerator]) {
                topMostView = [self processGetTopMostViewWith: chlidView];
                if (topMostView != nil) {
                    // 子视图中找到了一个没被交互完成的视图以供交互
                    break;
                }
            }
        }
    } else {  
        // 这种顺序查找的，非屏幕尺寸的View就是弹出的View      
        topMostView = contentView;
    }
    // 如果该View被触发过，就返回 nil
    if ([contentView touchCompleted]) {
        return nil;
    }
    return topMostView;
}

%end