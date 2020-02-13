//
//  DRRoutePlanManager.m
//  Records
//
//  Created by 冯生伟 on 2019/10/24.
//  Copyright © 2019 DuoRong Technology Co., Ltd. All rights reserved.
//

#import "DRRoutePlanManager.h"
#import <AMapSearchKit/AMapSearchKit.h>
#import <DRMacroDefines/DRMacroDefines.h>
#import <HexColors/HexColors.h>
#import "DRPlaceSearchManager.h"

#pragma mark - DRPointAnnotation
@interface DRPointAnnotation : MAPointAnnotation

@property (nonatomic, assign) DRPointAnnotationType pointType;
@property (assign, nonatomic) BOOL isStart;
@property (assign, nonatomic) BOOL isEnd;

@end

@implementation DRPointAnnotation
@end


#pragma mark - DRPolyline
@interface DRPolyline : MAPolyline

/// 路径规划类型
@property (nonatomic, assign) DRRoutePlanType routePlanType;
/// 该路段的交通方式
@property (assign, nonatomic) DRPointAnnotationType lineType;
/// 是否用虚线绘制
@property (assign, nonatomic) BOOL isDashLine;
///路况状态描述：0 未知，1 畅通，2 缓行，3 拥堵，4 严重拥堵
@property (assign, nonatomic) NSInteger status;

@end

@implementation DRPolyline
@end

@interface DRMultiPolyline : MAMultiPolyline

@end

@implementation DRMultiPolyline
@end


#pragma mark - DRRouteStrategyModel
// 路径规划策略
@implementation DRRouteStrategyModel

- (instancetype)initWithRoutePlanType:(DRRoutePlanType)routePlanType
                                 code:(NSString *)code
                                title:(NSString *)title {
    if (self = [super init]) {
        _strategy = code.intValue;
        _title = title;
        _routePlanType = routePlanType;
    }
    return self;
}

+ (NSArray<DRRouteStrategyModel *> *)strategyListWithString:(NSString *)string
                                              routePlanType:(DRRoutePlanType)routePlanType {
    if (string.length > 0) {
        NSMutableArray *list = [NSMutableArray array];
        NSArray *arr = [string componentsSeparatedByString:@"；"];
        if (arr.count > 0) {
            for (NSString *item in arr) {
                NSArray *info = [item componentsSeparatedByString:@"-"];
                if (info.count == 2) {
                    [list addObject:[[DRRouteStrategyModel alloc] initWithRoutePlanType:routePlanType
                                                                                   code:info[0]
                                                                                  title:info[1]]];
                }
            }
            return list;
        }
    }
    return @[];
}

@end


#pragma mark - DRRouteCourseModel
#define kMANaviRouteReplenishPolylineFilter     5
@interface DRRouteCourseModel ()

///起点坐标
@property (nonatomic, copy) AMapGeoPoint *origin;
///终点坐标
@property (nonatomic, copy) AMapGeoPoint *destination;
///此换乘方案预期时间（单位：秒）
@property (nonatomic, assign) NSInteger duration;
///导航路段 AMapStep 数组，驾车，步行，骑行
@property (nonatomic, strong) NSArray<AMapStep *> *steps;
///换乘路段 AMapSegment 数组，公交
@property (nonatomic, strong) NSArray<AMapSegment *> *segments;
/// 显示交通状态
@property (assign, nonatomic) BOOL showTrafficState;
/// 起终点标注
@property (strong, nonatomic) NSArray<DRPointAnnotation *> *annotations;
/// 路径折线集合
@property (strong, nonatomic) NSArray<DRPolyline *> *polyLines;
/// 多彩线颜色
@property (nonatomic, strong) NSArray<UIColor *> *multiPolylineColors;
/// 普通路段颜色，设置showTrafficState为YES才有效
@property (strong, nonatomic) UIColor *normalrouteColor;
/// 拥堵路段颜色，设置showTrafficState为YES才有效
@property (strong, nonatomic) UIColor *jamRouteColor;
/// 缓行路段颜色，设置showTrafficState为YES才有效
@property (strong, nonatomic) UIColor *slowRouteColor;
@property (strong, nonatomic) NSDictionary<NSString *, UIColor *> *colorMapping;
/// 已经解析了路径
@property (assign, nonatomic) BOOL haveSetup;

@end

@implementation DRRouteCourseModel

/// 解析路径
- (void)getRouteLinesPointsWithCoplete:(void(^)(NSArray<DRPointAnnotation *> *annotations, NSArray<DRPolyline *> *polyLines))complete {
    if (self.segments.count == 0) {
        kDR_SAFE_BLOCK(complete, @[], @[]);
        return;
    }
    if (self.haveSetup) {
        kDR_SAFE_BLOCK(complete, self.annotations, self.polyLines);
    }
    NSMutableArray *polylines = [NSMutableArray array];
    NSMutableArray *annotations = [NSMutableArray array];
    
    DRPointAnnotation *startAnnotation = [[DRPointAnnotation alloc] init];
    startAnnotation.coordinate = CLLocationCoordinate2DMake(self.origin.latitude, self.origin.longitude);
    startAnnotation.isStart = YES;
    [annotations addObject:startAnnotation];
    
    DRPointAnnotation *endAnnotation = [[DRPointAnnotation alloc] init];
    endAnnotation.coordinate = CLLocationCoordinate2DMake(self.destination.latitude, self.destination.longitude);
    endAnnotation.isEnd = YES;
    [annotations addObject:endAnnotation];
    
    if (self.routePlanType == DRRoutePlanTypePublicTransit) {
        [self makePublicTransitRouteNaviWithAnnotations:annotations
                                              polyLines:polylines];
    } else {
        [self makePathStepsRouteNaviWithAnnotations:annotations
                                          polyLines:polylines];
    }
    
    self.annotations = annotations;
    self.polyLines = polylines;
    self.haveSetup = YES;
    kDR_SAFE_BLOCK(complete, self.annotations, self.polyLines);
}

- (void)setDuration:(NSInteger)duration {
    _duration = duration;
    
    _totalTime = [[NSDateComponents alloc] init];
    NSMutableString *durationDesc = [NSMutableString string];
    _totalTime.second = duration % 60;
    duration /= 60;
    if (duration > 0) { // 分
        _totalTime.minute = duration % 60;
        [durationDesc insertString:[NSString stringWithFormat:@"%d分钟", (int)_totalTime.minute]
                           atIndex:0];
        duration /= 60;
    }
    if (duration > 0) { // 小时
        _totalTime.hour = duration % 24;
        [durationDesc insertString:[NSString stringWithFormat:@"%d小时", (int)_totalTime.hour]
                           atIndex:0];
        duration /= 24;
    }
    if (duration > 0) {
        _totalTime.day = duration;
        [durationDesc insertString:[NSString stringWithFormat:@"%d天", (int)_totalTime.day]
                           atIndex:0];
    }
    _durationDesc = durationDesc;
}

#pragma mark - 公交车路线导航解析
- (void)makePublicTransitRouteNaviWithAnnotations:(NSMutableArray *)annotations
                                        polyLines:(NSMutableArray *)polylines {
    [self.segments enumerateObjectsUsingBlock:^(AMapSegment *segment, NSUInteger idx, BOOL *stop) {
        [self naviRouteForSegment:segment annotations:annotations polyLines:polylines];
        if (idx > 0) {
            [self replenishPolylinesForTransit:[self.segments objectAtIndex:idx-1] currentSegment:segment polylines:polylines];
        }
    }];
    [self replenishPolylinesForStartPoint:self.origin endPoint:self.destination polylines:polylines];
}

- (void)naviRouteForSegment:(AMapSegment *)segment
                annotations:(NSMutableArray *)annotations
                  polyLines:(NSMutableArray *)polylines {
    if (segment == nil) {
        return;
    }
    // walk
    NSMutableArray *walkingPolyLinse = [NSMutableArray array];
    [self naviRouteForWalking:segment.walking annotations:annotations polyLines:walkingPolyLinse];
    [polylines addObjectsFromArray:walkingPolyLinse];
    // taxi
    [self naviRouteForTaxi:segment.taxi polyLines:polylines];
    // railway
    [self naviRouteForRailway:segment.railway annotations:annotations polyLines:polylines];
    // bus
    AMapBusLine *firstLine = [segment.buslines firstObject];
    DRPolyline *busLinePolyline = [self polylineForBusLine:firstLine];
    if (busLinePolyline) {
        busLinePolyline.lineType = DRPointAnnotationTypeBus;
        [polylines addObject:busLinePolyline];
        
        DRPointAnnotation *bus = [[DRPointAnnotation alloc] init];
        bus.coordinate = MACoordinateForMapPoint(busLinePolyline.points[0]);
        bus.pointType = DRPointAnnotationTypeBus;
        bus.title = firstLine.name;
        [annotations addObject:bus];
    }
    [self replenishPolylinesForSegment:walkingPolyLinse busLinePolyline:busLinePolyline segment:segment polylines:polylines];
}

- (void)replenishPolylinesForTransit:(AMapSegment *)lastSegment
                      currentSegment:(AMapSegment *)segment
                           polylines:(NSMutableArray *)polylines {
    if (lastSegment) {
        CLLocationCoordinate2D startCoor = kCLLocationCoordinate2DInvalid;
        CLLocationCoordinate2D endCoor = kCLLocationCoordinate2DInvalid;
        
        DRPolyline *busLinePolyline = [self polylineForBusLine:[(lastSegment).buslines firstObject]];
        if (busLinePolyline != nil) {
            [busLinePolyline getCoordinates:&startCoor range:NSMakeRange(busLinePolyline.pointCount-1, 1)];
        } else if (lastSegment.railway.arrivalStation) {
            startCoor = CLLocationCoordinate2DMake(lastSegment.railway.arrivalStation.location.latitude, lastSegment.railway.arrivalStation.location.longitude);
        } else {
            if ((lastSegment).walking && [(lastSegment).walking.steps count] != 0) {
                startCoor.latitude  = (lastSegment).walking.destination.latitude;
                startCoor.longitude = (lastSegment).walking.destination.longitude;
            } else {
                return;
            }
        }
        
        if ((segment).walking && [(segment).walking.steps count] != 0) {
            AMapStep *step = [(segment).walking.steps objectAtIndex:0];
            MAPolyline *stepPolyline = [self polylineForStep:step];
            
            [stepPolyline getCoordinates:&endCoor range:NSMakeRange(0 , 1)];
        } else {
            AMapBusLine *firstLine = [segment.buslines firstObject];
            MAPolyline *busLinePolyline = [self polylineForBusLine:firstLine];
            if (busLinePolyline != nil) {
                [busLinePolyline getCoordinates:&endCoor range:NSMakeRange(0 , 1)];
            } else if (segment.railway.departureStation) {
                endCoor = CLLocationCoordinate2DMake(segment.railway.departureStation.location.latitude, segment.railway.departureStation.location.longitude);
            }
        }
        DRPolyline *dashPolyline = [self replenishPolylineWithStart:startCoor end:endCoor];
        if (dashPolyline) {
            [polylines addObject:dashPolyline];
        }
    }
}

- (void)replenishPolylinesForStartPoint:(AMapGeoPoint *)start
                               endPoint:(AMapGeoPoint *)end
                              polylines:(NSMutableArray *)polylines {
    if (polylines.count < 1) {
        return;
    }
    
    DRPolyline *startDashPolyline = nil;
    DRPolyline *endDashPolyline = nil;
    if (start) {
        CLLocationCoordinate2D startCoor1 = CLLocationCoordinate2DMake(start.latitude, start.longitude);
        CLLocationCoordinate2D endCoor1 = startCoor1;
        
        DRPolyline *naviPolyline = [polylines firstObject];
        MAPolyline *polyline = nil;
        if ([naviPolyline isKindOfClass:[DRPolyline class]]) {
            polyline = naviPolyline;
        } else if ([naviPolyline isKindOfClass:[MAPolyline class]]) {
            polyline = (MAPolyline *)naviPolyline;
        }
        
        if (polyline) {
            [polyline getCoordinates:&endCoor1 range:NSMakeRange(0, 1)];
            startDashPolyline = [self replenishPolylineWithStart:startCoor1 end:endCoor1];
        }
    } // end start
    
    if (end) {
        CLLocationCoordinate2D startCoor2;
        CLLocationCoordinate2D endCoor2;
        
        DRPolyline *naviPolyline = [polylines lastObject];
        MAPolyline *polyline = nil;
        if ([naviPolyline isKindOfClass:[DRPolyline class]]) {
            polyline = naviPolyline;
        } else if ([naviPolyline isKindOfClass:[MAPolyline class]]) {
            polyline = (MAPolyline *)naviPolyline;
        }
        
        if (polyline) {
            [polyline getCoordinates:&startCoor2 range:NSMakeRange(polyline.pointCount - 1, 1)];
            endCoor2 = CLLocationCoordinate2DMake(end.latitude, end.longitude);
            endDashPolyline = [self replenishPolylineWithStart:startCoor2 end:endCoor2];
        }
    } //end end
    
    if (startDashPolyline) {
        [polylines addObject:startDashPolyline];
    }
    if (endDashPolyline) {
        [polylines addObject:endDashPolyline];
    }
}

- (void)naviRouteForWalking:(AMapWalking *)walking
                annotations:(NSMutableArray *)annotations
                  polyLines:(NSMutableArray *)polylines {
    if (walking == nil || walking.steps.count == 0) {
        return;
    }
    [walking.steps enumerateObjectsUsingBlock:^(AMapStep *step, NSUInteger idx, BOOL *stop) {
        DRPolyline *stepPolyline = [self polylineForStep:step];
        if (stepPolyline != nil) {
            stepPolyline.lineType = DRPointAnnotationTypeWalking;
            [polylines addObject:stepPolyline];
            
            DRPointAnnotation * annotation = [[DRPointAnnotation alloc] init];
            annotation.coordinate = MACoordinateForMapPoint(stepPolyline.points[0]);
            annotation.pointType = DRPointAnnotationTypeWalking;
            annotation.title = step.instruction;
            [annotations addObject:annotation];
            
            if (idx > 0) {
                [self replenishPolylinesForWalkingWith:stepPolyline
                                          lastPolyline:[self polylineForStep:[walking.steps objectAtIndex:idx - 1]]
                                             polylines:polylines
                                               walking:walking];
            }
        }
    }];
}

- (void)naviRouteForTaxi:(AMapTaxi *)taxi
               polyLines:(NSMutableArray *)polylines {
    if (taxi == nil){
        return;
    }
    
    CLLocationCoordinate2D coordinates[2];
    coordinates[0] = CLLocationCoordinate2DMake(taxi.origin.latitude, taxi.origin.longitude);
    coordinates[1] = CLLocationCoordinate2DMake(taxi.destination.latitude, taxi.destination.longitude);
    
    DRPolyline *polyline = [DRPolyline polylineWithCoordinates:coordinates count:2];
    polyline.lineType = DRPointAnnotationTypeBus;
    [polylines addObject:polyline];
}

- (void)naviRouteForRailway:(AMapRailway *)railway
                annotations:(NSMutableArray *)annotations
                  polyLines:(NSMutableArray *)polylines {
    if (railway == nil || railway.uid.length == 0) {
        return;
    }
    
    NSMutableArray *stations = [NSMutableArray array];
    [stations addObject:railway.departureStation];
    [stations addObjectsFromArray:railway.viaStops];
    [stations addObject:railway.arrivalStation];
    
    for (int i = 0; i < stations.count - 1; i++) {
        AMapRailwayStation *currentStation = stations[i];
        AMapRailwayStation *nextStation = stations[i+1];
        CLLocationCoordinate2D coordinates[2];
        coordinates[0] = CLLocationCoordinate2DMake(currentStation.location.latitude, currentStation.location.longitude);
        coordinates[1] = CLLocationCoordinate2DMake(nextStation.location.latitude, nextStation.location.longitude);
        
        DRPolyline *polyline = [DRPolyline polylineWithCoordinates:coordinates count:2];
        polyline.lineType = DRPointAnnotationTypeRailway;
        [polylines addObject:polyline];
        
        DRPointAnnotation * annotation = [[DRPointAnnotation alloc] init];
        annotation.coordinate = CLLocationCoordinate2DMake(currentStation.location.latitude, currentStation.location.longitude);
        annotation.pointType = DRPointAnnotationTypeRailway;
        annotation.title = currentStation.name;
        [annotations addObject:annotation];
        
        if (i == stations.count - 2) { // add last station
            DRPointAnnotation *lannotation = [[DRPointAnnotation alloc] init];
            lannotation.coordinate = CLLocationCoordinate2DMake(nextStation.location.latitude, nextStation.location.longitude);
            annotation.pointType = DRPointAnnotationTypeRailway;
            lannotation.title = nextStation.name;
            [annotations addObject:lannotation];
        }
    }
}

- (DRPolyline *)polylineForBusLine:(AMapBusLine *)busLine {
    if (busLine == nil) {
        return nil;
    }
    return [self polylineForCoordinateString:busLine.polyline];
}

- (void)replenishPolylinesForWalkingWith:(MAPolyline *)stepPolyline
                            lastPolyline:(MAPolyline *)lastPolyline
                               polylines:(NSMutableArray *)polylines
                                 walking:(AMapWalking *)walking {
    CLLocationCoordinate2D startCoor ;
    CLLocationCoordinate2D endCoor;
    
    [stepPolyline getCoordinates:&endCoor   range:NSMakeRange(0, 1)];
    [lastPolyline getCoordinates:&startCoor range:NSMakeRange(lastPolyline.pointCount -1, 1)];
    
    if (endCoor.latitude != startCoor.latitude || endCoor.longitude != startCoor.longitude) {
        DRPolyline *dashPolyline = [self replenishPolylineWithStart:startCoor end:endCoor];
        if (dashPolyline) {
            [polylines addObject:dashPolyline];
        }
    }
}

- (void)replenishPolylinesForSegment:(NSArray *)walkingPolylines
                     busLinePolyline:(MAPolyline *)busLinePolyline
                             segment:(AMapSegment *)segment
                           polylines:(NSMutableArray *)polylines {
    if (walkingPolylines.count != 0) {
        AMapGeoPoint *walkingEndPoint = segment.walking.destination;
        if (busLinePolyline)  {
            CLLocationCoordinate2D startCoor = CLLocationCoordinate2DMake(walkingEndPoint.latitude, walkingEndPoint.longitude);
            CLLocationCoordinate2D endCoor ;
            [busLinePolyline getCoordinates:&endCoor range:NSMakeRange(0, 1)];
            DRPolyline *dashPolyline = [self replenishPolylineWithStart:startCoor end:endCoor];
            if (dashPolyline) {
                [polylines addObject:dashPolyline];
            }
        }
    }
}

- (DRPolyline *)replenishPolylineWithStart:(CLLocationCoordinate2D)startCoor end:(CLLocationCoordinate2D)endCoor {
    if (!CLLocationCoordinate2DIsValid(startCoor) || !CLLocationCoordinate2DIsValid(endCoor)) {
        return nil;
    }
    double distance = MAMetersBetweenMapPoints(MAMapPointForCoordinate(startCoor), MAMapPointForCoordinate(endCoor));
    DRPolyline *dashPolyline = nil;
    // 过滤一下，距离比较近就不加虚线了
    if (distance > kMANaviRouteReplenishPolylineFilter) {
        CLLocationCoordinate2D points[2];
        points[0] = startCoor;
        points[1] = endCoor;
        dashPolyline = [DRPolyline polylineWithCoordinates:points count:2];
    }
    dashPolyline.isDashLine = YES;
    return dashPolyline;
}

- (DRPolyline *)polylineForStep:(AMapStep *)step {
    if (step == nil) {
        return nil;
    }
    return [self polylineForCoordinateString:step.polyline];
}



#pragma mark - 除公交以外的路径解析
- (void)makePathStepsRouteNaviWithAnnotations:(NSMutableArray *)annotations
                                    polyLines:(NSMutableArray *)polylines {
    // 为drive类型且需要显示路况
    if (self.showTrafficState && self.routePlanType == DRRoutePlanTypeDrive) {
        NSArray *polylineColors = nil;
        DRMultiPolyline *polyline = [self multiColoredPolylineWithPolylineColors:&polylineColors];
        if (polyline) {
            [polylines addObject:polyline];
            self.multiPolylineColors = polylineColors;
        }
    } else {
        [self.steps enumerateObjectsUsingBlock:^(AMapStep *step, NSUInteger idx, BOOL *stop) {
            DRPolyline *stepPolyline = [self polylineForStep:step];
            if (stepPolyline != nil) {
                if (self.routePlanType == DRRoutePlanTypeWalk) {
                    stepPolyline.lineType = DRPointAnnotationTypeWalking;
                } else if (self.routePlanType == DRRoutePlanTypeBike) {
                    stepPolyline.lineType = DRPointAnnotationTypeRiding;
                } else {
                    stepPolyline.lineType = DRPointAnnotationTypeDrive;
                }
                [polylines addObject:stepPolyline];
                
                if (idx > 0) {
                    DRPointAnnotation * annotation = [[DRPointAnnotation alloc] init];
                    annotation.coordinate = MACoordinateForMapPoint(stepPolyline.points[0]);
                    annotation.pointType = stepPolyline.lineType;
                    annotation.title = step.instruction;
                    [annotations addObject:annotation];
                    
                    // 填充step和step之间的空隙
                    [self replenishPolylinesForPathWith:stepPolyline
                                           lastPolyline:[self polylineForStep:[self.steps objectAtIndex:idx-1]]
                                              polylines:polylines];
                }
            }
        }];
    }
    [self replenishPolylinesForStartPoint:self.origin endPoint:self.destination polylines:polylines];
}

- (DRMultiPolyline *)multiColoredPolylineWithPolylineColors:(NSArray **)polylineColors {
    NSMutableArray *mutablePolylineColors = [NSMutableArray array];
    NSMutableArray *coordinates = [NSMutableArray array];
    NSMutableArray *indexes = [NSMutableArray array];
    NSMutableArray<AMapTMC *> *tmcs = [NSMutableArray array];
    NSMutableArray *coorArray = [NSMutableArray array];
    [self.steps enumerateObjectsUsingBlock:^(AMapStep * _Nonnull step, NSUInteger idx, BOOL * _Nonnull stop) {
        [coorArray addObjectsFromArray:[step.polyline componentsSeparatedByString:@";"]];
        [tmcs addObjectsFromArray:step.tmcs];
    }];
    
    int i = 1;
    NSInteger sumLength = 0;
    NSInteger statusesIndex = 0;
    NSInteger curTrafficLength = tmcs.firstObject.distance;
    [mutablePolylineColors addObject:[self colorWithTrafficStatus:tmcs.firstObject.status]];
    [indexes addObject:@(0)];
    [coordinates addObject:[coorArray objectAtIndex:0]];
    for ( ;i < coorArray.count; ++i) {
        double oneDis = [self calcDistanceBetweenCoor:[self coordinateWithString:coorArray[i-1]] andCoor:[self coordinateWithString:coorArray[i]]];
        if (sumLength + oneDis >= curTrafficLength) {
            if (sumLength + oneDis == curTrafficLength) {
                [coordinates addObject:[coorArray objectAtIndex:i]];
                [indexes addObject:[NSNumber numberWithInteger:([coordinates count]-1)]];
            } else { // 需要插入一个点
                double rate = (oneDis == 0 ? 0 : ((curTrafficLength - sumLength) / oneDis));
                NSString *extrnPoint = [self calcPointWithStartPoint:[coorArray objectAtIndex:i-1] endPoint:[coorArray objectAtIndex:i] rate:MAX(MIN(rate, 1.0), 0)];
                if (extrnPoint) {
                    [coordinates addObject:extrnPoint];
                    [indexes addObject:[NSNumber numberWithInteger:([coordinates count]-1)]];
                    [coordinates addObject:[coorArray objectAtIndex:i]];
                } else {
                    [coordinates addObject:[coorArray objectAtIndex:i]];
                    [indexes addObject:[NSNumber numberWithInteger:([coordinates count]-1)]];
                }
            }
            sumLength = sumLength + oneDis - curTrafficLength;
            
            if (++statusesIndex >= [tmcs count]) {
                break;
            }
            curTrafficLength = tmcs[statusesIndex].distance;
            [mutablePolylineColors addObject:[self colorWithTrafficStatus:tmcs[statusesIndex].status]];
        } else {
            [coordinates addObject:[coorArray objectAtIndex:i]];
            sumLength += oneDis;
        }
    } // end for
    
    //将最后一个点对齐到路径终点
    if (i < [coorArray count]) {
        while (i < [coorArray count]) {
            [coordinates addObject:[coorArray objectAtIndex:i]];
            i++;
        }
        
        [indexes removeLastObject];
        [indexes addObject:[NSNumber numberWithInteger:([coordinates count]-1)]];
    }
    
    // 添加overlay
    NSInteger count = coordinates.count;
    CLLocationCoordinate2D *runningCoords = (CLLocationCoordinate2D *)malloc(count * sizeof(CLLocationCoordinate2D));
    
    for (int j = 0; j < count; ++j) {
        NSString *oneCoor = coordinates[j];
        CLLocationCoordinate2D coor = [self coordinateWithString:oneCoor];
        runningCoords[j] = coor;
    }
    
    DRMultiPolyline *polyline = [DRMultiPolyline polylineWithCoordinates:runningCoords count:count drawStyleIndexes:indexes];
    
    free(runningCoords);
    
    if (polylineColors) {
        *polylineColors = [mutablePolylineColors copy];
    }
    return polyline;
}

- (UIColor *)colorWithTrafficStatus:(NSString *)status {
    if (status == nil) {
        status = @"未知";
    }
    return self.colorMapping[status] ?: self.normalrouteColor;
}

- (CLLocationCoordinate2D)coordinateWithString:(NSString *)string {
    NSArray *coorArray = [string componentsSeparatedByString:@","];
    if (coorArray.count != 2) {
        return kCLLocationCoordinate2DInvalid;
    }
    return CLLocationCoordinate2DMake([coorArray[1] doubleValue], [coorArray[0] doubleValue]);
}

- (double)calcDistanceBetweenCoor:(CLLocationCoordinate2D)coor1 andCoor:(CLLocationCoordinate2D)coor2 {
    MAMapPoint mapPointA = MAMapPointForCoordinate(coor1);
    MAMapPoint mapPointB = MAMapPointForCoordinate(coor2);
    return MAMetersBetweenMapPoints(mapPointA, mapPointB);
}

- (NSString *)calcPointWithStartPoint:(NSString *)start endPoint:(NSString *)end rate:(double)rate {
    if (rate > 1.0 || rate < 0) {
        return nil;
    }
    
    MAMapPoint from = MAMapPointForCoordinate([self coordinateWithString:start]);
    MAMapPoint to = MAMapPointForCoordinate([self coordinateWithString:end]);
    
    double latitudeDelta = (to.y - from.y) * rate;
    double longitudeDelta = (to.x - from.x) * rate;
    
    MAMapPoint newPoint = MAMapPointMake(from.x + longitudeDelta, from.y + latitudeDelta);
    
    CLLocationCoordinate2D coordinate = MACoordinateForMapPoint(newPoint);
    return [NSString stringWithFormat:@"%.6f,%.6f", coordinate.longitude, coordinate.latitude];
}

- (void)replenishPolylinesForPathWith:(MAPolyline *)stepPolyline
                         lastPolyline:(MAPolyline *)lastPolyline
                            polylines:(NSMutableArray *)polylines {
    CLLocationCoordinate2D startCoor;
    CLLocationCoordinate2D endCoor;
    
    [stepPolyline getCoordinates:&endCoor range:NSMakeRange(0, 1)];
    [lastPolyline getCoordinates:&startCoor range:NSMakeRange(lastPolyline.pointCount -1, 1)];
    
    if ((endCoor.latitude != startCoor.latitude || endCoor.longitude != startCoor.longitude )) {
        DRPolyline *dashPolyline = [self replenishPolylineWithStart:startCoor end:endCoor];
        if (dashPolyline) {
            [polylines addObject:dashPolyline];
        }
    }
}

#pragma mark - utils
- (DRPolyline *)polylineForCoordinateString:(NSString *)coordinateString {
    if (coordinateString.length == 0) {
        return nil;
    }
    NSUInteger count = 0;
    CLLocationCoordinate2D *coordinates = [self coordinatesForString:coordinateString
                                                     coordinateCount:&count
                                                          parseToken:@";"];
    DRPolyline *polyline = [DRPolyline polylineWithCoordinates:coordinates count:count];
    polyline.routePlanType = self.routePlanType;
    (void)(free(coordinates)), coordinates = NULL;
    return polyline;
}

- (CLLocationCoordinate2D *)coordinatesForString:(NSString *)string
                                 coordinateCount:(NSUInteger *)coordinateCount
                                      parseToken:(NSString *)token {
    if (string == nil) {
        return NULL;
    }
    if (token == nil) {
        token = @",";
    }
    NSString *str = @"";
    if (![token isEqualToString:@","]) {
        str = [string stringByReplacingOccurrencesOfString:token withString:@","];
    } else {
        str = [NSString stringWithString:string];
    }
    NSArray *components = [str componentsSeparatedByString:@","];
    NSUInteger count = [components count] / 2;
    if (coordinateCount != NULL) {
        *coordinateCount = count;
    }
    CLLocationCoordinate2D *coordinates = (CLLocationCoordinate2D*)malloc(count * sizeof(CLLocationCoordinate2D));
    
    for (int i = 0; i < count; i++) {
        coordinates[i].longitude = [[components objectAtIndex:2 * i]     doubleValue];
        coordinates[i].latitude  = [[components objectAtIndex:2 * i + 1] doubleValue];
    }
    return coordinates;
}

#pragma mark - lazy load
- (NSDictionary<NSString *, UIColor *> *)colorMapping {
    if (!_colorMapping) {
        _colorMapping = @{
            @"未知": self.normalrouteColor,
            @"畅通": self.normalrouteColor,
            @"缓行": self.slowRouteColor,
            @"拥堵": self.jamRouteColor
        };
    }
    return _colorMapping;
}

@end


#pragma mark - DRRoutePlanManager
@interface DRRoutePlanManager () <AMapSearchDelegate>

@property (nonatomic, weak) MAMapView *mapView;
@property (strong, nonatomic) AMapSearchAPI *routeSearch;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIColor *> *lineColorMap;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSDecimalNumber *> *lineWidthMap;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, UIImage *> *pointImpageMap;
@property (assign, nonatomic) DRRoutePlanType currentRouteType;
@property (nonatomic, copy) DRRoutePlanSearchDoneBlock onSearchDoneBlock;
@property (strong, nonatomic) NSMutableArray<DRPointAnnotation *> *annotations;
@property (strong, nonatomic) NSMutableArray<DRPolyline *> *routeLines;
@property (strong, nonatomic) NSArray<DRRouteCourseModel *> *courseList;

@end

@implementation DRRoutePlanManager

/// 创建路径规划类
/// @param mapView 地图
+ (instancetype)managerWithMapView:(MAMapView *)mapView {
    DRRoutePlanManager *manager = [DRRoutePlanManager new];
    manager.mapView = mapView;
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.startPointImage = [self imageWithName:@"icon_route_plan_start"];
        self.endPointImage = [self imageWithName:@"icon_route_plan_end"];
        self.pointImpageMap = [NSMutableDictionary dictionary];
        self.pointImpageMap[@(DRPointAnnotationTypeDrive)] = [self imageWithName:@"icon_point_car"];
        self.pointImpageMap[@(DRPointAnnotationTypeWalking)] = [self imageWithName:@"icon_point_walk"];
        self.pointImpageMap[@(DRPointAnnotationTypeBus)] = [self imageWithName:@"icon_point_bus"];
        self.pointImpageMap[@(DRPointAnnotationTypeRailway)] = [self imageWithName:@"icon_point_railway_station"];
        self.pointImpageMap[@(DRPointAnnotationTypeRiding)] = [self imageWithName:@"icon_point_ride"];
        
        self.lineColorMap = [NSMutableDictionary dictionary];
        self.lineColorMap[@(DRPointAnnotationTypeDrive)] = [UIColor hx_colorWithHexRGBAString:@"#0CB92D"];
        self.lineColorMap[@(DRPointAnnotationTypeWalking)] = [UIColor hx_colorWithHexRGBAString:@"#2998FB"];
        self.lineColorMap[@(DRPointAnnotationTypeBus)] = [UIColor hx_colorWithHexRGBAString:@"#F39758"];
        self.lineColorMap[@(DRPointAnnotationTypeRailway)] = [UIColor hx_colorWithHexRGBAString:@"#FF5475"];
        self.lineColorMap[@(DRPointAnnotationTypeRiding)] = [UIColor hx_colorWithHexRGBAString:@"#2998FB"];
        
        NSDecimalNumber *lineWidth = [NSDecimalNumber decimalNumberWithString:@"3"];
        self.lineWidthMap = [NSMutableDictionary dictionary];
        self.lineWidthMap[@(DRPointAnnotationTypeDrive)] = lineWidth;
        self.lineWidthMap[@(DRPointAnnotationTypeWalking)] = lineWidth;
        self.lineWidthMap[@(DRPointAnnotationTypeBus)] = lineWidth;
        self.lineWidthMap[@(DRPointAnnotationTypeRailway)] = lineWidth;
        self.lineWidthMap[@(DRPointAnnotationTypeRiding)] = lineWidth;
        
        self.showTrafficState = YES;
        self.jamRouteColor = [UIColor redColor];
        self.slowRouteColor = [UIColor yellowColor];
        self.currentRouteType = DRRoutePlanTypeNone;
        self.routeLineEdgeInsets = UIEdgeInsetsMake(30, 15, 50, 15);
    }
    return self;
}

#pragma mark - 核心API
/// 开始一次路径规划，坐标必须是百度火星坐标
/// @param fromCoordinate 起点坐标，必填
/// @param toCoordinate 终点坐标，必填
/// @param waypoints 途经点，最多16个，非必填
/// @param type 规划类型，必填
/// @param city 城市， 使用DRRoutePlanTypePublicTransit（公交）类型时必填
/// @param destinationCity 目的地城市， 使用DRRoutePlanTypePublicTransit（公交）类型且目的地跨城市时必填
/// @param enableNightTransit 是否显示夜班车， 使用DRRoutePlanTypePublicTransit（公交）类型时有效，非必填
/// @param completeBlock 规划检索完成回调，非必填
- (void)startRoutePlanWithFromCoordinate:(DRLocationCoordinateModel *)fromCoordinate
                            toCoordinate:(DRLocationCoordinateModel *)toCoordinate
                               waypoints:(NSArray<DRLocationCoordinateModel *> *)waypoints
                                    type:(DRRoutePlanType)type
                                    city:(NSString *)city
                         destinationCity:(NSString *)destinationCity
                      enableNightTransit:(BOOL)enableNightTransit
                           completeBlock:(DRRoutePlanSearchDoneBlock)completeBlock {
    if (fromCoordinate == nil || toCoordinate == nil) {
        kDR_SAFE_BLOCK(completeBlock, NO, @"起(startCoordinate)终(endCoordinate)点不能为空", 0, 0, nil, nil, nil, nil, nil);
        return;
    }
    if (type == DRRoutePlanTypePublicTransit && city.length == 0) {
        kDR_SAFE_BLOCK(completeBlock, NO, @"公交搜索城市(city)不能为空", 0, 0, nil, nil, nil, nil, nil);
        return;
    }
    
    self.currentRouteType = type;
    if (self.currentStrategy.routePlanType != type) {
        self.currentStrategy = [DRRoutePlanManager supportedStrategyListForRoutePlanType:type].firstObject;
    }
    
    AMapGeoPoint *origin = [AMapGeoPoint locationWithLatitude:fromCoordinate.latitude
                                                    longitude:fromCoordinate.longitude];
    AMapGeoPoint *destination = [AMapGeoPoint locationWithLatitude:toCoordinate.latitude
                                                         longitude:toCoordinate.longitude];
    NSMutableArray *sdkWaypoints = [NSMutableArray array];
    if (waypoints.count > 0) {
        for (DRLocationCoordinateModel *coordinate in waypoints) {
            [sdkWaypoints addObject:[AMapGeoPoint locationWithLatitude:coordinate.latitude
                                                             longitude:coordinate.longitude]];
            if (sdkWaypoints.count == 16) {
                break;
            }
        }
    }
    switch (type) {
        case DRRoutePlanTypeDrive: {
            AMapDrivingRouteSearchRequest *drivingRouteSearchRequest = [[AMapDrivingRouteSearchRequest alloc] init];
            drivingRouteSearchRequest.strategy = self.currentStrategy.strategy;
            drivingRouteSearchRequest.origin = origin;
            drivingRouteSearchRequest.destination = destination;
            drivingRouteSearchRequest.waypoints = sdkWaypoints;
            drivingRouteSearchRequest.requireExtension = YES;
            [self.routeSearch AMapDrivingRouteSearch:drivingRouteSearchRequest];
        } break;
            
        case DRRoutePlanTypePublicTransit: {
            AMapTransitRouteSearchRequest *transitRouteSearchRequest = [[AMapTransitRouteSearchRequest alloc] init];
            if (destinationCity.length > 0) {
                transitRouteSearchRequest.destinationCity = destinationCity;
            }
            transitRouteSearchRequest.origin = origin;
            transitRouteSearchRequest.destination = destination;
            transitRouteSearchRequest.city = city;
            transitRouteSearchRequest.nightflag = enableNightTransit;
            transitRouteSearchRequest.strategy = self.currentStrategy.strategy;
            transitRouteSearchRequest.requireExtension = YES;
            [self.routeSearch AMapTransitRouteSearch:transitRouteSearchRequest];
        } break;
            
        case DRRoutePlanTypeTruck: {
            AMapTruckRouteSearchRequest *truckRouteSearchRequest = [[AMapTruckRouteSearchRequest alloc] init];
            truckRouteSearchRequest.strategy = self.currentStrategy.strategy;
            truckRouteSearchRequest.origin = origin;
            truckRouteSearchRequest.destination = destination;
            truckRouteSearchRequest.waypoints = sdkWaypoints;
            [self.routeSearch AMapTruckRouteSearch:truckRouteSearchRequest];
        } break;
            
        case DRRoutePlanTypeBike: {
            AMapRidingRouteSearchRequest *ridingRouteSearchRequest = [[AMapRidingRouteSearchRequest alloc] init];
            ridingRouteSearchRequest.origin = origin;
            ridingRouteSearchRequest.destination = destination;
            [self.routeSearch AMapRidingRouteSearch:ridingRouteSearchRequest];
        } break;
            
        case DRRoutePlanTypeWalk: {
            AMapWalkingRouteSearchRequest *walkingRouteSearchRequest = [[AMapWalkingRouteSearchRequest alloc] init];
            walkingRouteSearchRequest.origin = origin;
            walkingRouteSearchRequest.destination = destination;
            [self.routeSearch AMapWalkingRouteSearch:walkingRouteSearchRequest];
        } break;
            
        default:
            return;
    }
    self.onSearchDoneBlock = completeBlock;
}

/// 创建终点起点标注视图
/// 在BMKMapView的mapView:viewForAnnotation:代理方法中使用
/// @param annotation 代理中的参数
- (MAAnnotationView *)startEndAnnotationViewWithAnnotation:(id<MAAnnotation>)annotation {
    if ([annotation isKindOfClass:[DRPointAnnotation class]]) {
        DRPointAnnotation *annot = (DRPointAnnotation *)annotation;
        NSString *reuseIndentifier = NSStringFromClass([self class]);
        MAAnnotationView *annotationView = [[MAAnnotationView alloc] initWithAnnotation:annot
                                                                        reuseIdentifier:reuseIndentifier];
        if (annot.pointType == DRPointAnnotationTypeNone) {
            if (annot.isStart) {
                annotationView.image = self.startPointImage;
            }
            if (annot.isEnd) {
                annotationView.image = self.endPointImage;
            }
        } else {
            annotationView.image = self.pointImpageMap[@(annot.pointType)];
        }
        return annotationView;
    }
    return nil;
}

/// 创建路径规划线条视图
/// 在BMKMapView的mapView:viewForOverlay:代理方法中使用
/// @param overlay 代理中的参数
- (MAPolylineRenderer *)routLineViewWithForOverlay:(id<MAOverlay>)overlay {
    if ([overlay isKindOfClass:[DRPolyline class]]) {
        DRPolyline *polyLine = (DRPolyline *)overlay;
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithOverlay:polyLine];
        polylineRenderer.lineWidth = self.lineWidthMap[@(polyLine.lineType)].floatValue;
        if (self.showTrafficState) { // 显示路况
            if (polyLine.status == 2) { // 缓行
                polylineRenderer.fillColor = self.slowRouteColor;
                polylineRenderer.strokeColor = self.slowRouteColor;
            } else if (polyLine.status > 2) { // 拥堵
                polylineRenderer.fillColor = self.jamRouteColor;
                polylineRenderer.strokeColor = self.jamRouteColor;
            }
            return polylineRenderer;
        }
        polylineRenderer.fillColor = self.lineColorMap[@(polyLine.lineType)];
        polylineRenderer.strokeColor = self.lineColorMap[@(polyLine.lineType)];
        if (polyLine.isDashLine) {
            polylineRenderer.lineDashType = kMALineDashTypeDot;
        }
        return polylineRenderer;
    }
    return nil;
}

#pragma mark - 外观定制
/// 设置路径规划线条颜色
/// @param lineColor 颜色
/// @param annotationType 规划类型
- (void)setLineColor:(UIColor *)lineColor
             forType:(DRPointAnnotationType)annotationType {
    self.lineColorMap[@(annotationType)] = lineColor;
    [self reloadOverlays];
}

/// 设置路径线条宽度
/// @param lineWidth 线条宽度，默认3pt
/// @param annotationType 规划类型
- (void)setLineWidth:(CGFloat)lineWidth
             forType:(DRPointAnnotationType)annotationType {
    self.lineWidthMap[@(annotationType)] = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%f", lineWidth]];
    [self reloadOverlays];
}

/// 设置标注点图片
/// @param image 图片
/// @param annotationType 标注点类型
- (void)setAnnotationPointImage:(UIImage *)image
              forAnnotationType:(DRPointAnnotationType)annotationType {
    self.pointImpageMap[@(annotationType)] = image;
    [self reloadAnnotations];
}

- (void)setJamRouteColor:(UIColor *)jamRouteColor {
    _jamRouteColor = jamRouteColor;
    
    [self reloadOverlays];
}

- (void)setSlowRouteColor:(UIColor *)slowRouteColor {
    _slowRouteColor = slowRouteColor;
    
    [self reloadOverlays];
}

- (void)reloadAnnotations {
    if (self.annotations.count > 0) {
        [self.mapView removeAnnotations:self.annotations];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mapView addAnnotations:self.annotations];
        });
    }
}

- (void)reloadOverlays {
    if (self.routeLines.count > 0) {
        [self.mapView removeOverlays:self.routeLines];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mapView addOverlays:self.routeLines];
        });
    }
}

#pragma mark - 方案选择
/// 获取指定规划类型所支持的路径规划策略列表
+ (NSArray<DRRouteStrategyModel *> *)supportedStrategyListForRoutePlanType:(DRRoutePlanType)routePlanType {
    NSString *strategyString = @"";
    if (routePlanType == DRRoutePlanTypeDrive) {
        strategyString = @"0-速度优先（时间)；1-费用优先（不走收费路段的最快道路）；2-距离优先；3-不走快速路；4-躲避拥堵；5-多策略（同时使用速度优先、费用优先、距离优先三个策略计算路径），其中必须说明，就算使用三个策略算路，会根据路况不固定的返回一至三条路径规划信息；6-不走高速；7-不走高速且避免收费；8-躲避收费和拥堵；9-不走高速且躲避收费和拥堵；10-多备选，时间最短，距离最短，躲避拥堵（考虑路况）；11-多备选，时间最短，距离最短；12-多备选，躲避拥堵（考虑路况）；13-多备选，不走高速；14-多备选，费用优先；15-多备选，躲避拥堵，不走高速（考虑路况）；16-多备选，费用有限，不走高速；17-多备选，躲避拥堵，费用优先（考虑路况）；18-多备选，躲避拥堵，不走高速，费用优先（考虑路况）；19-多备选，高速优先；20-多备选，高速优先，躲避拥堵（考虑路况）";
    }
    if (routePlanType == DRRoutePlanTypePublicTransit) {
        strategyString = @"0-最快捷模式； 1-最经济模式；2-最少换乘模式；3-最少步行模式；4-最舒适模式；5-不乘地铁模式";
    }
    if (routePlanType == DRRoutePlanTypeTruck) {
        strategyString = @"1-躲避拥堵；2-不走高速；3-避免收费；4-躲避拥堵&不走高速；5-避免收费&不走高速；6-躲避拥堵&避免收费；7-避免拥堵&避免收费&不走高速；8-高速优先；9-躲避拥堵&高速优先";
    }
    return [DRRouteStrategyModel strategyListWithString:strategyString
                                          routePlanType:routePlanType];
}

/// 地图上切换显示不同路径，会清除之前添加的路径
/// @param courseModel 想要切换显示的路径，必须来自一次路径规划之后返回的courseList列表
- (void)selectCourseToShow:(DRRouteCourseModel *)courseModel {
    if (![self.courseList containsObject:courseModel]) {
        return;
    }
    [self.mapView removeOverlays:self.routeLines];
    [self.routeLines removeAllObjects];
    
    [self.mapView removeAnnotations:self.annotations];
    [self.annotations removeAllObjects];
    
    [self.annotations addObjectsFromArray:[courseModel annotations]];
    [self.mapView addAnnotations:self.annotations];
    
    [self.routeLines addObjectsFromArray:[courseModel polyLines]];
    [self.mapView addOverlays:self.routeLines];
    
    [self.mapView showOverlays:self.routeLines
                   edgePadding:self.routeLineEdgeInsets
                      animated:YES];
}

/// 增加显示一条可选路径，不会清除之前添加的路径
/// @param courseModel 要显示的路径，必须来自一次路径规划之后返回的courseList列表
- (void)addShowCourse:(DRRouteCourseModel *)courseModel {
    if (![self.courseList containsObject:courseModel]) {
        return;
    }
    [self.routeLines addObjectsFromArray:[courseModel polyLines]];
    [self.mapView addOverlays:self.routeLines];
    
    [self.mapView showOverlays:self.routeLines
                   edgePadding:self.routeLineEdgeInsets
                      animated:YES];
}

#pragma mark - private
- (UIImage *)imageWithName:(NSString *)name {
    int scale = [UIScreen mainScreen].scale;
    return [UIImage imageWithContentsOfFile:[KDR_CURRENT_BUNDLE pathForResource:[NSString stringWithFormat:@"%@@%dx", name, scale] ofType:@"png"]];
}

#pragma mark - AMapSearchDelegate
/**
 * @brief 路径规划查询回调
 * @param request  发起的请求，具体字段参考 AMapRouteSearchBaseRequest 及其子类。
 * @param response 响应结果，具体字段参考 AMapRouteSearchResponse
 */
- (void)onRouteSearchDone:(AMapRouteSearchBaseRequest *)request response:(AMapRouteSearchResponse *)response {
    NSMutableArray<DRRouteCourseModel *> *courseList = [NSMutableArray array];
    if (self.currentRouteType == DRRoutePlanTypePublicTransit) {
        for (AMapTransit *transit in response.route.transits) {
            if (transit == nil) {
                continue;
            }
            DRRouteCourseModel *course = [DRRouteCourseModel new];
            course.routePlanType = DRRoutePlanTypePublicTransit;
            course.normalrouteColor = self.lineColorMap[@(DRPointAnnotationTypeDrive)];
            course.jamRouteColor = self.jamRouteColor;
            course.slowRouteColor = self.slowRouteColor;
            course.showTrafficState = self.showTrafficState;
            course.origin = response.route.origin;
            course.destination = response.route.destination;
            course.taxiCost = response.route.taxiCost;
            course.duration = transit.duration;
            course.distance = transit.distance;
            course.cost = transit.cost;
            course.nightflag = transit.nightflag;
            course.walkingDistance = transit.walkingDistance;
            course.segments = transit.segments;
            [courseList addObject:course];
        }
    } else {
        for (AMapPath *path in response.route.paths) {
            if (path == nil) {
                continue;
            }
            DRRouteCourseModel *course = [DRRouteCourseModel new];
            course.routePlanType = self.currentRouteType;
            course.normalrouteColor = self.lineColorMap[@(DRPointAnnotationTypeDrive)];
            course.jamRouteColor = self.jamRouteColor;
            course.slowRouteColor = self.slowRouteColor;
            course.showTrafficState = self.showTrafficState;
            course.origin = response.route.origin;
            course.destination = response.route.destination;
            course.taxiCost = response.route.taxiCost;
            course.duration = path.duration;
            course.distance = path.distance;
            course.strategy = path.strategy;
            course.tolls = path.tolls;
            course.tollDistance = path.tollDistance;
            course.totalTrafficLights = path.totalTrafficLights;
            course.steps = path.steps;
            if (self.currentRouteType == DRRoutePlanTypeDrive && self.showTrafficState) {
                NSInteger jamTotalDistance = 0;
                for (AMapStep *step in path.steps) {
                    for (AMapTMC *tmc in step.tmcs) {
                        if (tmc.status.intValue > 2) {
                            jamTotalDistance += tmc.distance;
                        }
                    }
                }
                course.jamTotalDistance = jamTotalDistance;
            }
            [courseList addObject:course];
        }
    }
    
    self.courseList = courseList;
    if (self.courseList.count > 0) {
        DRRouteCourseModel *courseModel = self.courseList.firstObject;
        [self selectCourseToShow:courseModel];
        kDR_SAFE_BLOCK(self.onSearchDoneBlock, YES, nil, courseModel.distance, courseModel.totalTrafficLights, courseModel.totalTime, courseModel.durationDesc, self.annotations, [courseModel polyLines], self.courseList);
    } else {
        [self.mapView removeOverlays:self.routeLines];
        [self.mapView removeAnnotations:self.annotations];
        kDR_SAFE_BLOCK(self.onSearchDoneBlock, NO, @"无可用路径", 0, 0, nil, nil, nil, nil, nil);
    }
}

/**
 * @brief 当请求发生错误时，会调用代理的此方法.
 * @param request 发生错误的请求.
 * @param error   返回的错误.
 */
- (void)AMapSearchRequest:(id)request didFailWithError:(NSError *)error {
    kDR_SAFE_BLOCK(self.onSearchDoneBlock, NO, [DRPlaceSearchManager errorInfoMapping][@(error.code)], 0, 0, nil, nil, nil, nil, nil);
}

#pragma mark - lazy load
- (AMapSearchAPI *)routeSearch {
    if (!_routeSearch) {
        _routeSearch = [[AMapSearchAPI alloc] init];
        _routeSearch.delegate = self;
    }
    return _routeSearch;
}

- (NSMutableArray<DRPointAnnotation *> *)annotations {
    if (!_annotations) {
        _annotations = [NSMutableArray array];
    }
    return _annotations;
}

- (NSMutableArray<DRPolyline *> *)routeLines {
    if (!_routeLines) {
        _routeLines = [NSMutableArray array];
    }
    return _routeLines;
}

#pragma mark - lifecycle
- (void)dealloc {
    kDR_LOG(@"%@ dealloc", NSStringFromClass([self class]));
    _routeSearch.delegate = nil;
}

@end
