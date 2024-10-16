#import "utils.h"

/*
本模块的功能：
1. 采集UI界面的文案
2. 采集UI视图树的路径
*/

%hook UIView

/**
-(BOOL)shouldRefreshFor:(NSString *)VCKey With:(NSMutableDictionary *)viewDict
(1)VCKey表示当前UI元素的responder
(2)viewDict表示当前界面提取出来的视图树

我们依据VCKey查询当前responder对应的页面是否发生变化
我们依托页面文案来表征页面内容
如果发生变化，就更新视图树和交互列表

*/
%new
-(BOOL)shouldRefreshFor:(NSString *)VCKey With:(NSMutableDictionary *)viewDict {

    // viewDict代表此次checkState时候提取的视图树
    // textDict存储了各个界面的文本
    NSMutableDictionary *textVCDict = [NSMutableDictionary dictionaryWithContentsOfFile: TEXT_INFO];
    if (textVCDict == nil) {
        textVCDict = [NSMutableDictionary dictionary];
    }
    if (viewDict != nil) {
        // 2. 读取当前页面的文本序列
        NSMutableArray *currentTextArray = [self collectTextInDict:viewDict];
        NSMutableSet *currentTextSet = [NSMutableSet setWithArray:currentTextArray];
        // 3. 读取上一次检查该页面中的文本
        NSMutableArray *oldTextArr = textVCDict[VCKey];
        NSMutableSet *oldTextSet = [NSMutableSet setWithArray: oldTextArr];
        if (oldTextSet == nil) {
            // 代表当前页面是第一次check到，return YES存储该视图树
            oldTextSet = [NSMutableSet set];
        }
        if ([currentTextSet count] == 0 && [oldTextSet count] == 0) {
            // targetView没有text的情况
            //NSLog(@"currentTextSet empty and oldTextSet empty");
            return NO;
        }
        if ([currentTextSet count] != 0) {
            [oldTextSet intersectSet:currentTextSet];
            // 4. 计算历史文本集合与当前文本集合的相似度
            float simliarity = (float)([oldTextSet count])/([currentTextSet count]);
            currentTextArray = [NSMutableArray arrayWithArray:[currentTextSet allObjects]];
            textVCDict[VCKey] = currentTextArray;
           // NSLog(@"in %@ text  simliarity is %f",VCKey, simliarity);
            [textVCDict writeToFile: TEXT_INFO atomically: YES];
            if (simliarity < 0.8) {
               // NSLog(@"layout tree need refresh!!!");
                return YES;
            }
        }
    } 
    return NO;
}

%new
-(NSMutableArray *)collectTextInDict:(NSMutableDictionary *)viewDict {
    
    NSMutableArray *result = [NSMutableArray array];
    if (viewDict == nil) {
        return result;
    }
    NSString *text = viewDict[@"text"];
    NSString *accessibilityIdentifier = viewDict[@"accessibilityIdentifier"];
    NSString *accessibilityLabel = viewDict[@"accessibilityLabel"];
    NSArray *subViewArr = viewDict[@"subViews"];
    if (text != nil) {
        [result addObject: text];
    } 
    if (accessibilityIdentifier != nil) {
        [result addObject: accessibilityIdentifier];
    }
    if (accessibilityLabel != nil) {
        [result addObject: accessibilityLabel];
    }
    for (NSMutableDictionary *subDict in subViewArr) {
        NSMutableArray *subTextArr = [self collectTextInDict: subDict];
        [result addObjectsFromArray:subTextArr];
    }
    return result;
}

%new
-(void)collectPathFor:(NSString *)VCKey With:(NSMutableDictionary *)viewDict {
    if (viewDict == nil) {
    	return;
    }
    NSMutableDictionary *pathDict = [NSMutableDictionary dictionaryWithContentsOfFile: UIPATH_SET];
    if (pathDict == nil) {
        pathDict = [NSMutableDictionary dictionary];
    } 
    NSMutableArray *currentPathArray = [self collectPathInDict:viewDict];
    if (currentPathArray == nil) {
    	return;
    }
    // 因为同一个VCKey里面对应了多个view，所以每次新货渠道的currentPathArray应当追加
    NSMutableArray* collectedPathArray = pathDict[VCKey];
    if (collectedPathArray == nil) {
        collectedPathArray = [NSMutableArray array];
    }
    NSMutableSet *collectedPathSet = [NSMutableSet setWithArray: collectedPathArray];
    NSMutableSet *currentPathSet = [NSMutableSet setWithArray: currentPathArray];
    [collectedPathSet unionSet:currentPathSet];
    collectedPathArray = [NSMutableArray arrayWithArray:[collectedPathSet allObjects]];
    pathDict[VCKey] = collectedPathArray;
  	[pathDict writeToFile: UIPATH_SET atomically:YES];  
}

%new 
-(NSMutableArray *)collectPathInDict:(NSMutableDictionary *)viewDict {
    // 1.viewDict为空的特殊情况
    if (viewDict == nil) {
        return nil;
    }
    NSMutableArray *result = [NSMutableArray array];
    NSString *name = viewDict[@"name"];
    NSArray *subViewArr = viewDict[@"subViews"];
    for (NSMutableDictionary *subDict in subViewArr) {
        // subPathArray里每一项都是一个NSString的array
        NSMutableArray *subPathArray = [self collectPathInDict:subDict];
        if (subPathArray != nil) {
            for (NSMutableArray *subPath in subPathArray) {
                // 每一个子path的头部加入自己的name
                [subPath insertObject: name atIndex:0];
                //NSLog(@"subPath is %@", subPath);
                // 将各个分支的Path汇总到总数组中
                [result addObject: subPath];
            }
        }
    }
    if (subViewArr == nil) {
        NSMutableArray *lastLayerSubverArr= [NSMutableArray array];
        [lastLayerSubverArr addObject: name];
        [result addObject: lastLayerSubverArr];
    }
    return result;
}

%end