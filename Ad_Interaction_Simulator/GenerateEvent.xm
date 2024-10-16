#import "utils.h"


%hook UIView

%new
-(void)generateEventIn:(NSString *)responderName {
    NSNumber *currentValue = [FinishedWindowDict objectForKey:responderName];
    if (currentValue) {
        int newValue = [currentValue intValue] + 1;
        FinishedWindowDict[responderName] = @(newValue);
    } else {
        FinishedWindowDict[responderName] = @(1);
    }
    // 1. 读取UI元素提取字典
    NSString *viewName = NSStringFromClass([self class]);
    NSLog(@"new in generateEventIn: %@-%@",responderName, viewName);
    NSMutableDictionary *layoutInfo = [NSMutableDictionary dictionaryWithContentsOfFile: LAYOUT_INFO];


    if (layoutInfo == nil) {
        return;
    }
    /*
        finishedEventDict存放应用中各个页面已经触发过的坐标，用于防止坐标的重复点击
        Key为VC名或者Window名
        Value为该VC或者Window已经触发过的事件列表
    */
    NSLog(@"read Finished task list");
    NSMutableDictionary *finishedEventDict = [NSMutableDictionary dictionaryWithContentsOfFile: FINISHED_TASK];
    if (finishedEventDict == nil) {
        NSLog(@"finishedEventDict is nil!!!");
        finishedEventDict = [NSMutableDictionary dictionary];
    }
    NSLog(@"ResponderName is %@",responderName);
    NSMutableArray *finishedEventArray = [finishedEventDict[responderName] mutableCopy];
    if (finishedEventArray == nil) {
        NSLog(@"finishedEventArray is nil!!!");
        finishedEventArray = [NSMutableArray array];
    }

    /*
        eventInfo 用于存放应用接下来需要触发的事件
        Key为VC名或者Window名
        Value为viewEvent，是一个字典、保存各个页面对应的事件
    */
    NSMutableDictionary *eventInfo = [NSMutableDictionary dictionaryWithContentsOfFile: ACTION_LIST];
    if (eventInfo == nil) {
        eventInfo = [NSMutableDictionary dictionary];
    }
    /*
        viewEvent 用于存放一个ViewController或者UIWindow中囊括的事件
        Key为某一个UIView
        Value为一个列表，存放该View对应的事件列表
    */
    NSMutableDictionary *viewEvent = eventInfo[viewName];
    if (viewEvent == nil) {
        viewEvent = [NSMutableDictionary dictionary];
    }

    NSMutableDictionary *viewLayout = layoutInfo[responderName];

    NSString *jsonStr = viewLayout[viewName];
    NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json2Dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONWritingPrettyPrinted
                                                          error:nil];
    NSMutableDictionary *layoutDict = [NSMutableDictionary dictionaryWithDictionary:json2Dict];

    NSLog(@" ");
    NSLog(@" ");
    NSLog(@" ");
    NSLog(@" ");
    NSLog(@"polyu print layoutDict in generateEventIn:"); 
    NSLog(@"%@",layoutDict);
    NSLog(@"polyu print layoutDict in generateEventIn End");


    if (layoutDict != nil) {
        NSMutableArray *eventArray = [self generateEventInDict: layoutDict];

        NSLog(@" ");
        NSLog(@"polyu print generateEventInDict eventArray  in generateEventIn:");
        NSLog(@"eventArray is %@", eventArray);
        NSLog(@"polyu print generateEventInDict eventArray in generateEventIn End");
        NSLog(@" ");

        // 存放同意坐标的点击手势
        NSMutableArray *agreeArray = [NSMutableArray array];
        // 存放可能的返回按钮，这些按钮要放在最后点击
        NSMutableArray *backArray = [NSMutableArray array];
        // 存放滑动手势
        NSMutableArray *panArray = [NSMutableArray array]; // 不具备唯一性

        NSMutableArray *totalPanArray = [NSMutableArray array];// 具备唯一性
        // 存放滑动坐标
        NSMutableSet *panPositionSet = [NSMutableSet set];
        // 存放具有优先级的tableViewCell
        
        NSMutableArray *cellArray = [NSMutableArray array];
        NSMutableArray *adClassArray = [NSMutableArray array];
        // 调整优先级
        for (NSMutableDictionary *actionDict in eventArray) {
            NSString *text = actionDict[@"text"];
            //NSString *accessibilityIdentifier = actionDict[@"accessibilityIdentifier"];
            //NSString *accessibilityLabel = actionDict[@"accessibilityLabel"];
            NSString *accessibilityIdentifier = @"TODO";
            NSString *accessibilityLabel = @"TODO";

            NSString *strPoint = actionDict[@"center"];
            NSString *name = actionDict[@"name"];
            CGPoint point = CGPointFromString(strPoint);
            CGFloat xValue = point.x;
            CGFloat yValue = point.y;
            // 返回按钮的处理
            if ([text containsString: @"返回"] || [accessibilityIdentifier containsString:@"返回"] || [accessibilityLabel containsString: @"返回"]) {
                [backArray addObject:actionDict];
            } else if ([text containsString: @"back"] || [accessibilityIdentifier containsString:@"back"] || [accessibilityLabel containsString: @"back"]) {
                [backArray addObject:actionDict];
            } else if (xValue < 50 && yValue < 50 ) {
                [backArray addObject:actionDict];
            }

            if (([text rangeOfString:@"disagree" options:NSCaseInsensitiveSearch].location == NSNotFound && [text rangeOfString:@"agree" options:NSCaseInsensitiveSearch].location == NSNotFound) ||  (![text containsString: @"不同意"] && [text containsString: @"同意"]) ) {
                [agreeArray addObject: actionDict];
            }

            if ([name containsString:@"cell"]||[name containsString:@"Cell"]) {
                [cellArray addObject: actionDict];
            }

            if ([name containsString:@"adClass"]) {
                [adClassArray addObject: actionDict];
            }

            // 如果操作手势是滑动
            if ([actionDict[@"action"] isEqualToString:@"pan"]) {
                NSLog(@"actionDict is %@", actionDict);
                NSString *panPosition = actionDict[@"center"];
           //     NSLog(@"panPosition is %@", panPosition);
           //     [totalPanArray addObject: actionDict];
                if (![panPositionSet containsObject: panPosition]) {
                    // 滑动坐标未加入过
                    [panPositionSet addObject: panPosition];
                    [panArray addObject: actionDict];
                }
            }
        }
        for (NSMutableDictionary *backDict in backArray) {
            if ([eventArray containsObject:backDict]) {
                [eventArray removeObject:backDict];
            }
        }
        for (NSMutableDictionary *panDict in totalPanArray) {
            if ([eventArray containsObject:panDict]) {
                [eventArray removeObject: panDict];
            }
        }
        NSMutableArray *transitionWidget = [UIWindow readScript];
        NSMutableArray *deleteWidgetList = [NSMutableArray array];

        //why delete TODO:-----------------
        for (NSMutableDictionary *actionDict in eventArray) {
            NSString *widgetName  = actionDict[@"name"];
            if (![transitionWidget containsObject: widgetName]) {
                //[deleteWidgetList addObject: actionDict];
            }
        }
        for (NSMutableDictionary *deleteDict in deleteWidgetList) {
            [eventArray removeObject: deleteDict];
        }
        NSLog(@"Attention!!!!!!!!! before deleteWidgetList");
        NSLog(@"deleteWidgetList is %@", deleteWidgetList);


        [eventArray addObjectsFromArray: panArray];
        [eventArray addObjectsFromArray: backArray];
        [cellArray addObjectsFromArray: eventArray];
        [adClassArray addObjectsFromArray: agreeArray];
        [adClassArray addObjectsFromArray: cellArray];
        eventArray = adClassArray;

        //复制一个eventArray
        NSMutableArray *eventArrayCopy = [NSMutableArray arrayWithArray: eventArray];
        // 把TableViewCell放在最前
        // 删除之前已经触发过的控件
        for (NSMutableDictionary *finishedDict in finishedEventArray) {
            if ([eventArray containsObject: finishedDict]) {
                [eventArray removeObject: finishedDict];
            }
            // 使用谓词删除text相同的控件
            NSString *finishedText = finishedDict[@"text"];
            NSString *finishedAcIdent = finishedDict[@"accessibilityIdentifier"];
            NSString *finishedACLabel = finishedDict[@"accessibilityLabel"];
            if (finishedText != nil) {
                NSPredicate *predicateText =  [NSPredicate predicateWithFormat:@"NOT (text CONTAINS[cd] %@)",finishedText];
                eventArray = [NSMutableArray arrayWithArray:[eventArray filteredArrayUsingPredicate:predicateText]];
            }
            if (finishedAcIdent != nil) {
                NSPredicate *predicateAcIdent =  [NSPredicate predicateWithFormat:@"NOT (accessibilityIdentifier CONTAINS[cd] %@)",finishedAcIdent];
                eventArray = [NSMutableArray arrayWithArray:[eventArray filteredArrayUsingPredicate:predicateAcIdent]];
            }
            if (finishedACLabel != nil) {
                NSPredicate *predicateACLabel =  [NSPredicate predicateWithFormat:@"NOT (accessibilityLabel CONTAINS[cd] %@)",finishedACLabel];
                eventArray = [NSMutableArray arrayWithArray:[eventArray filteredArrayUsingPredicate:predicateACLabel]];
            }
        }
        //打印eventArray数量，以及finishedEventArray数量
        NSLog(@"eventArray count =  %lu", (unsigned long)[eventArray count]);
        NSLog(@"finishedEventArray count =  %lu", (unsigned long)[finishedEventArray count]);
        if ([eventArray count] == 0) {
            //在FinishWindowArray中添加responderName
            NSLog(@"excute FinishWindowArray addObject in generateEventIn:");
            if (![FinishWindowArray containsObject:responderName]) {
                [FinishWindowArray addObject:responderName];
            }
            [finishedEventArray removeAllObjects];
            eventArray = eventArrayCopy;
            //将清空的finishedEventArray写入FINISHED_TASK文件中，即清空FINISHED_TASK中的finishedEventDict[responderName]
            finishedEventDict[responderName] = finishedEventArray;
            bool finishedEventFlag = [finishedEventDict writeToFile: FINISHED_TASK atomically: YES];
            if(!finishedEventFlag){
                NSLog(@"Failed to write File. finishedEvent write failed");
            }
        }
        

        NSLog(@" ");
        NSLog(@"polyu print final eventArray in generateEventIn:"); 
        NSLog(@"%@",eventInfo);
        NSLog(@"polyu print final eventArray in generateEventIn:"); 

        viewEvent[viewName] = eventArray;
        eventInfo[@"currentState"] = responderName;
        eventInfo[responderName] = viewEvent;
        bool generateEventactionFlag = [eventInfo writeToFile: ACTION_LIST atomically: YES];
        if(!generateEventactionFlag){
            NSLog(@"Failed to write File. generateEventaction write failed");
        }

        NSLog(@" ");
        NSLog(@"polyu print eventInfo write^^ in generateEventIn:"); 
        NSLog(@"%@",eventInfo);
        NSLog(@"polyu print eventInfo write^^ in generateEventIn End"); 

        
    }
}

%new
- (NSMutableArray *)generateEventInDict:(NSMutableDictionary *)layoutDict {
    NSMutableArray *result = [NSMutableArray array];
    if (layoutDict == nil) {
        return result;
    }
    // 需要点击的控件
    NSSet *tapSet = [[NSSet alloc] initWithObjects:@"UIButton", @"UITableViewCell", @"UICollectionViewCell", @"UIAlertControllerActionView",@"UISegment", @"UISegmentedControl",@"UIImageView", nil];
    // 需要滑动的控件
    NSSet *panSet = [[NSSet alloc] initWithObjects:@"UIScrollView", @"UITableView", @"UICollectionView",  @"UIWebView", nil]; 
    // 需要输入的控件
    //TODO:
    //NSSet *inPutSet = [[NSSet alloc] initWithObjects: nil]; 

    NSString *name = layoutDict[@"name"];
    NSString *className = layoutDict[@"className"];

    NSString *strPoint = layoutDict[@"center"];
    NSArray *subViewArr = layoutDict[@"subViews"];
    NSString *text = layoutDict[@"text"];
    NSString *accessibilityIdentifier = layoutDict[@"accessibilityIdentifier"];
    NSString *accessibilityLabel = layoutDict[@"accessibilityLabel"];


    NSMutableDictionary *actionInfo = [NSMutableDictionary dictionary];
    actionInfo[@"name"] = name;
    actionInfo[@"target"] = className;
    actionInfo[@"center"] = strPoint;
    if (text != nil) {
        actionInfo[@"text"] = text;
    }
    if (accessibilityIdentifier != nil) {
        actionInfo[@"accessibilityIdentifier"] = accessibilityIdentifier;
    }
    if (accessibilityLabel != nil) {
        actionInfo[@"accessibilityLabel"] = accessibilityLabel;
    }

    NSString *strWidth = layoutDict[@"width"];
    NSString *strHeight = layoutDict[@"height"];
    NSInteger width = [strWidth integerValue];
    NSInteger height = [strHeight integerValue];
    CGPoint point = CGPointFromString(strPoint);
    CGFloat xValue = point.x;
    CGFloat yValue = point.y;
    if (xValue >= 0 && xValue <= SCREEN_WIDTH && yValue >= 0 && yValue <= SCREEN_HEIGHT) {
        if ([tapSet containsObject: name]) {
            actionInfo[@"action"] = @"tap";
            [result addObject: actionInfo];
        } else if ([panSet containsObject: name]) {
            actionInfo[@"action"] = @"pan";
            if (width > height) {
                actionInfo[@"direction"] = @"horizontal";
            } else {
                actionInfo[@"direction"] = @"vertical";
            }
            [result addObject: actionInfo];
        } else if ([name containsString: @"adClass"]) {
            actionInfo[@"action"] = @"tap";
            [result addObject: actionInfo];
        }
    }
    if (strPoint == nil) {
        NSLog(@"center is nil!!actionInfo is %@", actionInfo); 
    }
    for (NSMutableDictionary *subLayoutDict in subViewArr) {
        NSMutableArray *subEventArr = [self generateEventInDict: subLayoutDict];
        [result addObjectsFromArray:subEventArr];
    }

    return result;
}

%end