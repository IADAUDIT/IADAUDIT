#import "utils.h"

/*
本模块的作用在于对界面元素根据先由上到下，由左到右的顺序进行排序
*/

%hook UIView

// 以下三个函数用于快速排序
%new
- (void)swapInArray:(NSMutableArray *)arr withObject:(NSInteger)index1 andObject:(NSInteger)index2 {
    NSInteger numOfArray = [arr count];
    if (index1 >= numOfArray || index2 >= numOfArray) {
        return;
    }
    id temp = arr[index1];
    arr[index1] = arr[index2];
    arr[index2] = temp;
}

// 借助荷兰国旗问题，对整个队列进行划分
%new
- (NSMutableArray *)partitionWith:(NSString *)key Of:(NSMutableArray *)arr withLeft:(NSInteger)L andRight:(NSInteger)R {
    NSInteger less = L - 1;
    NSInteger more = R;
    NSInteger index = L;
    NSMutableDictionary *rDict = (NSMutableDictionary *)arr[R];
    NSString *rYString = rDict[key];
    NSInteger rYValue = [rYString integerValue];

    while(index < more) {
        NSMutableDictionary *indexDict = (NSMutableDictionary *)arr[index];
        NSString *indexYString = indexDict[key];
        NSInteger indexYValue = [indexYString integerValue];
        if (indexYValue < rYValue) {
            [self swapInArray:arr withObject:++less andObject: index++];
        } else if (indexYValue > rYValue) {
            [self swapInArray:arr withObject:--more andObject: index];
        } else {
            index ++;
        }
    }
    less += 1;
    [self swapInArray:arr withObject:more andObject: R];
    NSMutableArray *partitionBorder = [NSMutableArray arrayWithArray:@[@(less), @(more)]];
    return partitionBorder;
}

%new
-(void)processQuickSortWith:(NSString *)key WithArr:(NSMutableArray *)arr withLeft:(NSInteger)L andRight:(NSInteger)R {
    if (L < R) {
        NSMutableArray *partitionBorder = [self partitionWith:key Of:arr withLeft:L andRight:R];
        NSNumber *leftBorder = partitionBorder[0];
        NSNumber *rightBorder = partitionBorder[1];
        NSInteger partitionLeft = [leftBorder integerValue] - 1;
        NSInteger partitionRight = [rightBorder integerValue] + 1;
        [self processQuickSortWith:key WithArr:arr withLeft: L andRight:partitionLeft];
        [self processQuickSortWith:key WithArr:arr withLeft: partitionRight andRight:R];
    }
}

%end