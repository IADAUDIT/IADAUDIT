#import "utils.h"


/*
本模块功能在于获取应当提取视图树的UI元素
*/

%hook UIView
extern NSArray *adClassNameArray;

/**
-(NSMutableDictionary *)processViewContent
功能：
1. 在递归的过程中获取一个UI元素的子控件列表
2. 对UI元素的子控件列表进行优先由上到下，其次由左到右的排序
*/
%new
-(NSMutableDictionary *)processViewContent
{
    //1.在递归遍历UI树的过程中获取UI元素的控件类型以及文案信息
    NSString *name = NSStringFromClass([self class]);
    NSString *name_temp = NSStringFromClass([self class]);
    //NSLog(@"%@ processViewContent", name);
    NSString *text = nil;
    if ([self isKindOfClass: [UIButton class]] || [name hasSuffix: @"Button"]) {
        name = @"UIButton";
        UIButton *button = (UIButton *)self;
        if ([self respondsToSelector:@selector(titleLabel)]) {
            UILabel *label = button.titleLabel;
            if ([label respondsToSelector:@selector(text)]) {
                text = label.text;
            }
        }
    } else if ([self isKindOfClass: [UILabel class]]|| [name hasSuffix: @"Label"]) {
        name = @"UILabel";
        if ([self respondsToSelector:@selector(text)]) {
            UILabel *label = (UILabel *)self;
            text = label.text;
        }
    } else if ([self isKindOfClass: [UITableViewCell class]]|| [name containsString: @"TableCell"]) {
        name = @"UITableViewCell";
    } else if ([self isKindOfClass: [UICollectionViewCell class]] || [name containsString: @"Collectioncell"]) {
        name = @"UICollectionViewCell";
    } else if ([self isKindOfClass: [UITableView class]]|| [name hasSuffix: @"TableView"]||[name containsString: @"ListView"]) {
        name = @"UITableView";
    } else if ([self isKindOfClass: [UICollectionView class]]|| [name hasSuffix: @"CollectionView"]) {
        name = @"UICollectionView";
    } else if ([self isKindOfClass: [UIWebView class]]||[self isKindOfClass: [WKWebView class]]|| [name containsString: @"WebView"]) {
        name = @"UIWebView";
    } else if ([self isKindOfClass: [UIScrollView class]]|| [name containsString: @"ScrollView"] ||[name containsString: @"Selector"]) {
        name = @"UIScrollView";
    } else if ([self isKindOfClass: [UIImageView class]]|| [name containsString: @"ImageView"]) {
        name = @"UIImageView";
    } else if ([self isKindOfClass: [UINavigationBar class]]|| [name containsString: @"NavigationBar"]) {
        name = @"UINavigationBar";
    } else if ([self isKindOfClass: [UITabBar class]]|| [name containsString: @"UITabBar"]) {
        name = @"UITabBar";
    } else if ([name containsString: @"UIAlertControllerActionView"]) {
        name = @"UIAlertControllerActionView";
    } else if ([self isKindOfClass: [UISegmentedControl class]]|| [name containsString: @"SegmentedControl"]) {
        name = @"UISegmentedControl";
    } else if ([name hasSuffix: @"Segment"]) {
        name = @"UISegment";
    } else if ([adClassNameArray containsObject:name]) {
        name = @"adClass";
    }

    //2. 将UI元素的信息存储到字典中
    NSMutableDictionary* viewDict = [NSMutableDictionary dictionary];
    // 2.1 控件类型
    viewDict[@"name"] = name;
    viewDict[@"className"] = name_temp;
    // 2.2 控件尺寸
    viewDict[@"frame"] = NSStringFromCGRect([self.superview convertRect:self.frame toView:[UIApplication sharedApplication].keyWindow]);
    // 2.3 如果包含文本
    if (text != nil) {
        viewDict[@"text"] = text;
    } 
    if (self.accessibilityIdentifier != nil){
        viewDict[@"accessibilityIdentifier"] = self.accessibilityIdentifier;
    } 
    if (self.accessibilityLabel != nil){
        viewDict[@"accessibilityLabel"] = self.accessibilityLabel;
    } 
    // 2.4 响应链条下一环
    if (self.nextResponder != nil) {
        viewDict[@"nextResponder"] = NSStringFromClass([self.nextResponder class]);
    }
    // 2.5 最底部纵坐标（用于按照坐标对子控件排序）
    viewDict[@"y"] = [NSString stringWithFormat:@"%f", ([self.superview convertRect:self.frame toView:[UIApplication sharedApplication].keyWindow].origin.y + self.frame.size.height)];
    // 2.6 最右侧横坐标 （用于按照坐标对子控件排序）
    viewDict[@"x"] = [NSString stringWithFormat:@"%f", ([self.superview convertRect:self.frame toView:[UIApplication sharedApplication].keyWindow].origin.x + self.frame.size.width)];
    // 2.7 UI控件中心点，即接受不了UI交互的坐标
    CGPoint rootViewPoint  = [self.superview convertPoint: self.center toView: nil];
    NSString *strRootViewPoint = NSStringFromCGPoint(rootViewPoint);
    viewDict[@"center"] = strRootViewPoint;
    // 2.8 记录UI元素的宽和高
    viewDict[@"width"] = [NSString stringWithFormat:@"%f", self.frame.size.width];
    viewDict[@"height"] = [NSString stringWithFormat:@"%f", self.frame.size.height];
    if (strRootViewPoint == nil) {
        NSLog(@"center is nil!!viewDict is %@", viewDict); 
    }
    //3.通过getSubViews函数获取按照坐标排序后的子控件列表
    NSMutableArray *subViewsArr = [self getSubViews];
    if (subViewsArr != nil && subViewsArr.count != 0) {
        viewDict[@"subViews"] = subViewsArr;
    }
    return viewDict;
}


/**
-(NSMutableArray *)getSubViews
功能：
1. 在递归的过程中获取一个UI元素的子控件列表
2. 对UI元素的子控件列表进行优先由上到下，其次由左到右的排序
*/
%new
-(NSMutableArray *)getSubViews
{
    //1.遍历子控件列表并加入待排序队列
    NSArray *subViews = self.subviews;
    NSMutableArray *childViewArr = [NSMutableArray array];
    for(UIView *childView in subViews)
    {
        NSDictionary *childDict = [NSDictionary dictionary];
        CGRect abRect = [self convertRect:childView.frame toView:[UIApplication sharedApplication].keyWindow];
        CGFloat xBound = abRect.origin.x + childView.frame.size.width;
        CGFloat yBound = abRect.origin.y + childView.frame.size.height;
        if (childView.hidden == YES ||(xBound < 0)|| (yBound < 0)||( childView.frame.size.width == 0 || childView.frame.size.height == 0)) {
            continue;
        }
        //2. 依次递归获取各个子控件的UI属性
        childDict = [childView processViewContent];
        [childViewArr addObject:childDict];
    }
    //3. 对于收集到的子控件字典，按照优先从上到下，其次从左到右进行排序
    if ([childViewArr count] > 0) {
       [self processQuickSortWith:@"y" WithArr:childViewArr withLeft:0 andRight:([childViewArr count] - 1)]; 
       NSInteger numOfChildViewArr = [childViewArr count];
       if (numOfChildViewArr > 1) {
            NSInteger start = 0;
           NSInteger end = 1;
           NSMutableDictionary *startDict = childViewArr[start];
           NSMutableDictionary *endDict = childViewArr[end];
           while(start < numOfChildViewArr && end  < numOfChildViewArr) {
                if (startDict[@"y"] == endDict[@"y"]) {
                    while(startDict[@"y"] == endDict[@"y"] && (start < numOfChildViewArr && end  < numOfChildViewArr)) {
                        end = end + 1;
                        if (start >= numOfChildViewArr || end  >= numOfChildViewArr) {
                            break;
                        }
                        endDict = childViewArr[end];
                    }
                    [self processQuickSortWith:@"x" WithArr:childViewArr withLeft:start andRight:end - 1];
                    start = end - 1;
                    if (start >= numOfChildViewArr || end  >= numOfChildViewArr) {
                        break;
                    }
                    startDict = childViewArr[start];
                    endDict = childViewArr[end];
                } else {
                    start = start + 1;
                    end = end + 1;
                    if (start >= numOfChildViewArr || end  >= numOfChildViewArr) {
                        break;
                    }
                    startDict = childViewArr[start];
                    endDict = childViewArr[end];
                }
           } 
       } 
    }
    return childViewArr;
}
%end








