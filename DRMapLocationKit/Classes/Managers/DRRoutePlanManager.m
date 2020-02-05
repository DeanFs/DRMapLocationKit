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

@property (nonatomic, assign) BOOL forRoutePlan;
@property (nonatomic, assign) DRRoutePlanPointType pointType;

@end

@implementation DRPointAnnotation
@end


#pragma mark - DRPolyline
@interface DRPolyline : MAPolyline

@property (nonatomic, assign) BOOL forRoutePlan;
@property (nonatomic, assign) DRRoutePlanType lineType;
///路况状态描述：0 未知，1 畅通，2 缓行，3 拥堵，4 严重拥堵
@property (assign, nonatomic) NSInteger status;

@end

@implementation DRPolyline
@end


#pragma mark - DRRouteStrategyModel
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
@interface DRRouteCourseModel ()

///起点坐标
@property (nonatomic, copy) AMapGeoPoint *origin;
///终点坐标
@property (nonatomic, copy) AMapGeoPoint *destination;
///导航路段 AMapStep 数组，驾车，步行，骑行
@property (nonatomic, strong) NSArray<AMapStep *> *steps;
///换乘路段 AMapSegment 数组，公交
@property (nonatomic, strong) NSArray<AMapSegment *> *segments;
/// 路径规划类型
@property (assign, nonatomic) DRRoutePlanType routePlanType;

@end

@implementation DRRouteCourseModel

- (NSArray<DRPointAnnotation *> *)annotations {
    DRPointAnnotation *startAnnotation = [[DRPointAnnotation alloc] init];
    startAnnotation.coordinate = CLLocationCoordinate2DMake(self.origin.latitude, self.origin.longitude);
    startAnnotation.forRoutePlan = YES;
    startAnnotation.pointType = DRRoutePlanPointTypeStart;
    
    DRPointAnnotation *endAnnotation = [[DRPointAnnotation alloc] init];
    endAnnotation.coordinate = CLLocationCoordinate2DMake(self.destination.latitude, self.destination.longitude);
    endAnnotation.forRoutePlan = YES;
    endAnnotation.pointType = DRRoutePlanPointTypeEnd;
    return @[startAnnotation, endAnnotation];
}

- (NSArray<DRPolyline *> *)polyLines {
    return @[];
}

@end


#pragma mark - DRRoutePlanManager
@interface DRRoutePlanManager () <AMapSearchDelegate>

@property (nonatomic, weak) MAMapView *mapView;
@property (strong, nonatomic) AMapSearchAPI *routeSearch;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIColor *> *lineColorMap;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSDecimalNumber *> *lineWidthMap;
@property (nonatomic, assign) DRRouteStartEndInfo startInfo;
@property (nonatomic, assign) DRRouteStartEndInfo endInfo;
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
        int scale = [UIScreen mainScreen].scale;
        UIImage *startImage = [UIImage imageWithContentsOfFile:[KDR_CURRENT_BUNDLE pathForResource:[NSString stringWithFormat:@"route_plan_start@%dx", scale] ofType:@"png"]];
        UIImage *endImage = [UIImage imageWithContentsOfFile:[KDR_CURRENT_BUNDLE pathForResource:[NSString stringWithFormat:@"route_plan_end@%dx", scale] ofType:@"png"]];
        self.startInfo = (DRRouteStartEndInfo){@"起点", startImage};
        self.endInfo = (DRRouteStartEndInfo){@"终点", endImage};
        
        self.lineColorMap = [NSMutableDictionary dictionary];
        self.lineColorMap[@(DRRoutePlanTypeDrive)] = [UIColor hx_colorWithHexRGBAString:@"#5a8ffc"];
        self.lineColorMap[@(DRRoutePlanTypePublicTransit)] = [UIColor hx_colorWithHexRGBAString:@"#5a8ffc"];
        self.lineColorMap[@(DRRoutePlanTypeTruck)] = [UIColor hx_colorWithHexRGBAString:@"#5a8ffc"];
        self.lineColorMap[@(DRRoutePlanTypeBike)] = [UIColor hx_colorWithHexRGBAString:@"#5a8ffc"];
        self.lineColorMap[@(DRRoutePlanTypeWalk)] = [UIColor hx_colorWithHexRGBAString:@"#5a8ffc"];
        
        NSDecimalNumber *lineWidth = [NSDecimalNumber decimalNumberWithString:@"3"];
        self.lineWidthMap = [NSMutableDictionary dictionary];
        self.lineWidthMap[@(DRRoutePlanTypeDrive)] = lineWidth;
        self.lineWidthMap[@(DRRoutePlanTypePublicTransit)] = lineWidth;
        self.lineWidthMap[@(DRRoutePlanTypeTruck)] = lineWidth;
        self.lineWidthMap[@(DRRoutePlanTypeBike)] = lineWidth;
        self.lineWidthMap[@(DRRoutePlanTypeWalk)] = lineWidth;
        
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
        if (annot.forRoutePlan) {
            NSString *reuseIndentifier = NSStringFromClass([self class]);
            MAAnnotationView *annotationView = [[MAAnnotationView alloc] initWithAnnotation:annot reuseIdentifier:reuseIndentifier];
            if (annot.pointType == DRRoutePlanPointTypeStart) {
                annot.title = self.startInfo.title;
                annotationView.image = self.startInfo.image;
            } else if (annot.pointType == DRRoutePlanPointTypeEnd) {
                annot.title = self.endInfo.title;
                annotationView.image = self.endInfo.image;
            }
            return annotationView;
        }
    }
    return nil;
}

/// 创建路径规划线条视图
/// 在BMKMapView的mapView:viewForOverlay:代理方法中使用
/// @param overlay 代理中的参数
- (MAOverlayView*)routLineViewWithForOverlay:(id<MAOverlay>)overlay {
    if ([overlay isKindOfClass:[DRPolyline class]]) {
        DRPolyline *polyLine = (DRPolyline *)overlay;
        if (polyLine.forRoutePlan) {
            MAPolylineView *polylineView = [[MAPolylineView alloc] initWithOverlay:polyLine];
            polylineView.fillColor = self.lineColorMap[@(polyLine.lineType)];
            polylineView.strokeColor = self.lineColorMap[@(polyLine.lineType)];
            polylineView.lineWidth = self.lineWidthMap[@(polyLine.lineType)].floatValue;
            return polylineView;
        }
    }
    return nil;
}

#pragma mark - 外观定制
/// 设置路径规划线条颜色
/// @param lineColor 颜色
/// @param type 规划类型
- (void)setLineColor:(UIColor *)lineColor
             forType:(DRRoutePlanType)type {
    self.lineColorMap[@(type)] = lineColor;
}

- (void)setLineWidth:(CGFloat)lineWidth
             forType:(DRRoutePlanType)type {
    self.lineWidthMap[@(type)] = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%f", lineWidth]];
}

/// 设置地图上起点标注标题及图标
/// @param title 标题
/// @param image 图标
- (void)setStartCoordinateTitle:(NSString *)title
                          image:(UIImage *)image {
    self.startInfo = (DRRouteStartEndInfo){title, image};
}

/// 设置地图上终点标注标题及图标
/// @param title 标题
/// @param image 图标
- (void)setEndCoordinateTitle:(NSString *)title
                        image:(UIImage *)image {
    self.endInfo = (DRRouteStartEndInfo){title, image};
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

#pragma mark - AMapSearchDelegate
/**
 * @brief 路径规划查询回调
 * @param request  发起的请求，具体字段参考 AMapRouteSearchBaseRequest 及其子类。
 * @param response 响应结果，具体字段参考 AMapRouteSearchResponse
 */
- (void)onRouteSearchDone:(AMapRouteSearchBaseRequest *)request response:(AMapRouteSearchResponse *)response {
    self.courseList = nil;
    if (self.currentRouteType == DRRoutePlanTypePublicTransit) {
        
    } else {
        
    }
    
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
