//
//  DRSmoothPathTool.m
//  DRMapLocationKit
//
//  Created by 冯生伟 on 2020/2/16.
//

#import "DRSmoothPathTool.h"
#import <MAMapKit/MAMapKit.h>

@implementation DRSmoothPathTool {
    double lastLocation_x; //上次位置
    double currentLocation_x;//这次位置
    double lastLocation_y; //上次位置
    double currentLocation_y;//这次位置
    double estimate_x; //修正后数据
    double estimate_y; //修正后数据
    double pdelt_x; //自预估偏差
    double pdelt_y; //自预估偏差
    double mdelt_x; //上次模型偏差
    double mdelt_y; //上次模型偏差
    double gauss_x; //高斯噪音偏差
    double gauss_y; //高斯噪音偏差
    double kalmanGain_x; //卡尔曼增益
    double kalmanGain_y; //卡尔曼增益
    
    double m_R;
    double m_Q;
}

- (id)init {
    self = [super init];
    
    if(self) {
        self.intensity = 3;
        self.threshHold = 0.3f;
        self.noiseThreshhold = 10;
    }
    
    return self;
}
/**
 * 轨迹平滑优化
 * @param originlist 原始轨迹list,list.size大于2
 * @return 优化后轨迹list
 */
- (NSArray<DRLocationCoordinateModel*>*)pathOptimize:(NSArray<DRLocationCoordinateModel*>*)originlist {
    
    NSArray<DRLocationCoordinateModel*>* list = [self removeNoisePoint:originlist];//去噪
    NSArray<DRLocationCoordinateModel*>* afterList = [self kalmanFilterPath:list intensity:self.intensity];//滤波
    NSArray<DRLocationCoordinateModel*>* pathoptimizeList = [self reducerVerticalThreshold:afterList threshHold:self.threshHold];//抽稀
    return pathoptimizeList;
}

/**
 * 轨迹线路滤波
 * @param originlist 原始轨迹list,list.size大于2
 * @return 滤波处理后的轨迹list
 */
- (NSArray<DRLocationCoordinateModel*>*)kalmanFilterPath:(NSArray<DRLocationCoordinateModel*>*)originlist {
    return [self kalmanFilterPath:originlist intensity:self.intensity];
}


/**
 * 轨迹去噪，删除垂距大于20m的点
 * @param originlist 原始轨迹list,list.size大于2
 * @return 去燥后的list
 */
- (NSArray<DRLocationCoordinateModel*>*)removeNoisePoint:(NSArray<DRLocationCoordinateModel*>*)originlist{
    return [self reduceNoisePoint:originlist threshHold:self.noiseThreshhold];
}

/**
 * 单点滤波
 * @param lastLoc 上次定位点坐标
 * @param curLoc 本次定位点坐标
 * @return 滤波后本次定位点坐标值
 */
- (DRLocationCoordinateModel*)kalmanFilterPoint:(DRLocationCoordinateModel*)lastLoc curLoc:(DRLocationCoordinateModel*)curLoc {
    return [self kalmanFilterPoint:lastLoc curLoc:curLoc intensity:self.intensity];
}

/**
 * 轨迹抽稀
 * @param inPoints 待抽稀的轨迹list，至少包含两个点，删除垂距小于mThreshhold的点
 * @return 抽稀后的轨迹list
 */
- (NSArray<DRLocationCoordinateModel*>*)reducerVerticalThreshold:(NSArray<DRLocationCoordinateModel*>*)inPoints {
    return [self reducerVerticalThreshold:inPoints threshHold:self.threshHold];
}

/********************************************************************************************************/
/**
 * 轨迹线路滤波
 * @param originlist 原始轨迹list,list.size大于2
 * @param intensity 滤波强度（1—5）
 * @return 滤波后的list
 */
- (NSArray<DRLocationCoordinateModel*>*)kalmanFilterPath:(NSArray<DRLocationCoordinateModel*>*)originlist intensity:(int)intensity {
    if (!originlist || originlist.count <= 2) {
        return nil;
    }
    
    NSMutableArray<DRLocationCoordinateModel*>* kalmanFilterList = [NSMutableArray array];
    
    [self initial];//初始化滤波参数
    
    DRLocationCoordinateModel* point = nil;
    DRLocationCoordinateModel* lastLoc = [DRLocationCoordinateModel modelWithLatitude:[originlist objectAtIndex:0].latitude
                                                                            longitude:[originlist objectAtIndex:0].longitude];
    [kalmanFilterList addObject:lastLoc];
    
    for (int i = 1; i < originlist.count; i++) {
        DRLocationCoordinateModel* curLoc = [originlist objectAtIndex:i];
        point = [self kalmanFilterPoint:lastLoc curLoc:curLoc intensity:intensity];
        if (point) {
            [kalmanFilterList addObject:point];
            lastLoc = point;
        }
    }
    return kalmanFilterList;
}

/**
 * 单点滤波
 * @param lastLoc 上次定位点坐标
 * @param curLoc 本次定位点坐标
 * @param intensity 滤波强度（1—5）
 * @return 滤波后本次定位点坐标值
 */
- (DRLocationCoordinateModel*)kalmanFilterPoint:(DRLocationCoordinateModel*)lastLoc curLoc:(DRLocationCoordinateModel*)curLoc intensity:(int)intensity {
    if (!lastLoc || !curLoc){
        return nil;
    }
    
    if (pdelt_x == 0 || pdelt_y == 0 ){
        [self initial];
    }
    
    DRLocationCoordinateModel* point = nil;
    if (intensity < 1){
        intensity = 1;
    } else if (intensity > 5){
        intensity = 5;
    }
    for (int j = 0; j < intensity; j++){
        point = [self kalmanFilter:lastLoc.longitude value_x:curLoc.longitude oldValue_y:lastLoc.latitude value_y:curLoc.latitude];
        curLoc = point;
    }
    return point;
}


/***************************卡尔曼滤波开始********************************/

//初始模型
- (void)initial {
    pdelt_x =  0.001;
    pdelt_y =  0.001;
    //        mdelt_x = 0;
    //        mdelt_y = 0;
    mdelt_x =  5.698402909980532E-4;
    mdelt_y =  5.698402909980532E-4;
}

- (DRLocationCoordinateModel*)kalmanFilter:(double)oldValue_x value_x:(double)value_x oldValue_y:(double)oldValue_y value_y:(double)value_y{
    lastLocation_x = oldValue_x;
    currentLocation_x= value_x;
    
    gauss_x = sqrt(pdelt_x * pdelt_x + mdelt_x * mdelt_x)+m_Q;     //计算高斯噪音偏差
    kalmanGain_x = sqrt((gauss_x * gauss_x)/(gauss_x * gauss_x + pdelt_x * pdelt_x)) +m_R; //计算卡尔曼增益
    estimate_x = kalmanGain_x * (currentLocation_x - lastLocation_x) + lastLocation_x;    //修正定位点
    mdelt_x = sqrt((1-kalmanGain_x) * gauss_x *gauss_x);      //修正模型偏差
    
    lastLocation_y = oldValue_y;
    currentLocation_y = value_y;
    gauss_y = sqrt(pdelt_y * pdelt_y + mdelt_y * mdelt_y)+m_Q;     //计算高斯噪音偏差
    kalmanGain_y = sqrt((gauss_y * gauss_y)/(gauss_y * gauss_y + pdelt_y * pdelt_y)) +m_R; //计算卡尔曼增益
    estimate_y = kalmanGain_y * (currentLocation_y - lastLocation_y) + lastLocation_y;    //修正定位点
    mdelt_y = sqrt((1-kalmanGain_y) * gauss_y * gauss_y);      //修正模型偏差
    
    DRLocationCoordinateModel *point = [DRLocationCoordinateModel modelWithLatitude:estimate_y longitude:estimate_x];
    
    return point;
}
/***************************卡尔曼滤波结束**********************************/

/***************************抽稀算法*************************************/
- (NSArray<DRLocationCoordinateModel*>*)reducerVerticalThreshold:(NSArray<DRLocationCoordinateModel*>*)inPoints threshHold:(float)threshHold {
    if(inPoints.count < 2) {
        return inPoints;
    }
    
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:inPoints.count];
    
    for(int i = 0; i < inPoints.count; ++i) {
        DRLocationCoordinateModel *pre = ret.lastObject;
        DRLocationCoordinateModel *cur = [inPoints objectAtIndex:i];
        
        
        if (!pre || i == inPoints.count - 1) {
            [ret addObject:[inPoints objectAtIndex:i]];
            continue;
        }
        
        DRLocationCoordinateModel *next = [inPoints objectAtIndex:(i + 1)];
        
        MAMapPoint curP = MAMapPointForCoordinate(CLLocationCoordinate2DMake(cur.latitude, cur.longitude));
        MAMapPoint prevP = MAMapPointForCoordinate(CLLocationCoordinate2DMake(pre.latitude, pre.longitude));
        MAMapPoint nextP = MAMapPointForCoordinate(CLLocationCoordinate2DMake(next.latitude, next.longitude));
        double distance = [self calculateDistanceFromPoint:curP lineBegin:prevP lineEnd:nextP];
        if (distance >= threshHold) {
            [ret addObject:cur];
        }
    }
    
    return ret;
}

- (DRLocationCoordinateModel*)getLastLocation:(NSArray<DRLocationCoordinateModel*>*)oneGraspList {
    if (!oneGraspList || oneGraspList.count == 0) {
        return nil;
    }
    NSInteger locListSize = oneGraspList.count;
    DRLocationCoordinateModel* lastLocation = [oneGraspList objectAtIndex:(locListSize - 1)];
    return lastLocation;
}

/**
 * 计算当前点到线的垂线距离
 * @param pt 当前点
 * @param begin 线的起点
 * @param end 线的终点
 *
 */
- (double)calculateDistanceFromPoint:(MAMapPoint)pt
                           lineBegin:(MAMapPoint)begin
                             lineEnd:(MAMapPoint)end {
    
    MAMapPoint mappedPoint;
    double dx = begin.x - end.x;
    double dy = begin.y - end.y;
    if(fabs(dx) < 0.00000001 && fabs(dy) < 0.00000001 ) {
        mappedPoint = begin;
    } else {
        double u = (pt.x - begin.x)*(begin.x - end.x) +
        (pt.y - begin.y)*(begin.y - end.y);
        u = u/((dx*dx)+(dy*dy));
        
        mappedPoint.x = begin.x + u*dx;
        mappedPoint.y = begin.y + u*dy;
    }
    
    return MAMetersBetweenMapPoints(pt, mappedPoint);
}
/***************************抽稀算法结束*********************************/

- (NSArray<DRLocationCoordinateModel*>*)reduceNoisePoint:(NSArray<DRLocationCoordinateModel*>*)inPoints threshHold:(float)threshHold {
    if (!inPoints) {
        return nil;
    }
    if (inPoints.count <= 2) {
        return inPoints;
    }
    
    NSMutableArray<DRLocationCoordinateModel*>* ret = [NSMutableArray array];
    for (int i = 0; i < inPoints.count; i++) {
        DRLocationCoordinateModel* pre = [self getLastLocation:ret];
        DRLocationCoordinateModel* cur = [inPoints objectAtIndex:i];
        if (!pre || i == inPoints.count - 1) {
            [ret addObject:cur];
            continue;
        }
        DRLocationCoordinateModel* next = [inPoints objectAtIndex:(i + 1)];
        MAMapPoint curP = MAMapPointForCoordinate(CLLocationCoordinate2DMake(cur.latitude, cur.longitude));
        MAMapPoint prevP = MAMapPointForCoordinate(CLLocationCoordinate2DMake(pre.latitude, pre.longitude));
        MAMapPoint nextP = MAMapPointForCoordinate(CLLocationCoordinate2DMake(next.latitude, next.longitude));
        double distance = [self calculateDistanceFromPoint:curP lineBegin:prevP lineEnd:nextP];
        if (distance < threshHold){
            [ret addObject:cur];
        }
    }
    return ret;
}

@end
