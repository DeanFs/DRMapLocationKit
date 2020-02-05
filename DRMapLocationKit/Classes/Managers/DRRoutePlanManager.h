//
//  DRRoutePlanManager.h
//  Records
//
//  Created by 冯生伟 on 2019/10/24.
//  Copyright © 2019 DuoRong Technology Co., Ltd. All rights reserved.
//

#import <MAMapKit/MAMapKit.h>
#import "DRLocationCoordinateModel.h"

#pragma mark - type define
@class DRPointAnnotation;
@class DRPolyline;
@class DRRouteCourseModel;
typedef NS_ENUM(NSInteger, DRRoutePlanPointType) {
    DRRoutePlanPointTypeStart,
    DRRoutePlanPointTypeEnd
};

typedef NS_ENUM(NSInteger, DRRoutePlanType) {
    DRRoutePlanTypeNone,
    DRRoutePlanTypeDrive,           // 驾车
    DRRoutePlanTypePublicTransit,   // 公共交通
    DRRoutePlanTypeTruck,           // 货车
    DRRoutePlanTypeWalk,            // 步行
    DRRoutePlanTypeBike             // 骑行
};

typedef void (^DRRoutePlanSearchDoneBlock)(BOOL success,
                                           NSString *errorMessage,
                                           NSInteger distance,          // 距离：米
                                           NSInteger lightNum,          // 红绿灯数量，仅驾车类型规划有效
                                           NSDateComponents *duration,  // 时长
                                           NSString *durationDesc,      // 时长描述：xx天xx小时xx分...
                                           NSArray<DRPointAnnotation *> *startEndAnnotations, // 本次路劲规划在题图上添加的起终点标注
                                           NSArray<DRPolyline *> *routeLine, // 本次规划在题图上添加的路径线条
                                           NSArray<DRRouteCourseModel *> *courseList    // 本次规划结果的多条路径，默认已经把第一条绘制在了地图上
                                           );

typedef struct {
    NSString *title;
    UIImage *image;
} DRRouteStartEndInfo;


#pragma mark - DRRouteStrategyModel
@interface DRRouteStrategyModel : NSObject

@property (assign, nonatomic, readonly) int strategy;
@property (copy, nonatomic, readonly) NSString *title;
@property (assign, nonatomic, readonly) DRRoutePlanType routePlanType;

+ (NSArray<DRRouteStrategyModel *> *)strategyListWithString:(NSString *)string
                                              routePlanType:(DRRoutePlanType)routePlanType;

@end


@interface DRRouteCourseModel : NSObject

/// 当前方案的总距离
@property (nonatomic, assign) NSInteger distance;
/// 当前方案的预计总耗时
@property (nonatomic, assign) NSDateComponents *totalTime;
/// 时长描述：xx天xx小时xx分钟
@property (copy, nonatomic) NSString *durationDesc;
/// 出租车费用（单位：元）
@property (nonatomic, assign) CGFloat taxiCost;

#pragma mark - 公交方案字段
/// 此公交方案价格（单位：元）
@property (nonatomic, assign) CGFloat cost;
/// 是否是夜班车
@property (nonatomic, assign) BOOL nightflag;
/// 此方案总步行距离（单位：米）
@property (nonatomic, assign) NSInteger walkingDistance;

#pragma mark - 驾车，步行，骑行方案字段
/// 此方案费用（单位：元）
@property (nonatomic, assign) CGFloat tolls;
/// 此方案收费路段长度（单位：米）
@property (nonatomic, assign) NSInteger tollDistance;
/// 此方案交通信号灯个数
@property (nonatomic, assign) NSInteger totalTrafficLights;

#pragma mark - 驾车方案独有
/// 拥堵路段总长度
@property (assign, nonatomic) NSInteger jamTotalDistance;

@end


#pragma mark - DRRoutePlanManager
/// 路径规划器
@interface DRRoutePlanManager : NSObject

/// 绘制的路劲离mapView边距约束，默认(30, 15, 50, 15)
@property (assign, nonatomic) UIEdgeInsets routeLineEdgeInsets;
/// 当前路径规划策略
@property (strong, nonatomic) DRRouteStrategyModel *currentStrategy;
/// 拥堵路段颜色
@property (strong, nonatomic) UIColor *jamRouteColor;
/// 缓行路段颜色
@property (strong, nonatomic) UIColor *slowRouteColor;

#pragma mark - 必须调用的方法
/// 创建路径规划类
/// @param mapView 地图
+ (instancetype)managerWithMapView:(MAMapView *)mapView;

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
                           completeBlock:(DRRoutePlanSearchDoneBlock)completeBlock;

/// 创建终点起点标注视图
/// 在MapView的mapView:viewForAnnotation:代理方法中使用
/// @param annotation 代理中的参数
- (MAAnnotationView *)startEndAnnotationViewWithAnnotation:(id<MAAnnotation>)annotation;

/// 创建路径规划线条视图
/// 在MAMapView的mapView:viewForOverlay:代理方法中使用
/// @param overlay 代理中的参数
- (MAPolylineRenderer *)routLineViewWithForOverlay:(id<MAOverlay>)overlay;

#pragma mark - 外观定制
/// 设置路径规划线条颜色
/// @param lineColor 颜色
/// @param type 规划类型
- (void)setLineColor:(UIColor *)lineColor
             forType:(DRRoutePlanType)type;

/// 设置路径线条宽度
/// @param lineWidth 线条宽度，默认3pt
/// @param type 规划类型
- (void)setLineWidth:(CGFloat)lineWidth
             forType:(DRRoutePlanType)type;

/// 设置地图上起点标注标题及图标
/// @param title 标题
/// @param image 图标
- (void)setStartCoordinateTitle:(NSString *)title
                          image:(UIImage *)image;

/// 设置地图上终点标注标题及图标
/// @param title 标题
/// @param image 图标
- (void)setEndCoordinateTitle:(NSString *)title
                        image:(UIImage *)image;

#pragma mark - 方案选择
/// 获取指定规划类型所支持的路径规划策略列表
+ (NSArray<DRRouteStrategyModel *> *)supportedStrategyListForRoutePlanType:(DRRoutePlanType)routePlanType;

/// 地图上切换显示不同路径，会清除之前添加的路径
/// @param courseModel 想要切换显示的路径，必须来自一次路径规划之后返回的courseList列表
- (void)selectCourseToShow:(DRRouteCourseModel *)courseModel;

/// 增加显示一条可选路径，不会清除之前添加的路径
/// @param courseModel 要显示的路径，必须来自一次路径规划之后返回的courseList列表
- (void)addShowCourse:(DRRouteCourseModel *)courseModel;

@end
