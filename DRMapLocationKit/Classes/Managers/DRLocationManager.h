//
//  DRLocationManager.h
//  Records
//
//  Created by 冯生伟 on 2020/2/3.
//  Copyright © 2020 DuoRong Technology Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DRLocationModel.h"

@class DRLocationManager;
@protocol DRLocationManagerDelegate <NSObject>

/**
 定位成功完成回调
 
 @param locationManager 定位管理器，从中获取定位结果
 @param locationModel 定位位置信息
 */
- (void)onUpdateLocationDone:(DRLocationManager *)locationManager
                    location:(DRLocationModel *)locationModel;

@optional
/**
 定位失败回调
 
 @param locationManager 定位管理器，从中获取定位结果
 @param error 失败信息
 */
- (void)onUpdateLocationFail:(DRLocationManager *)locationManager
                       error:(NSError *)error;

/**
 用户禁用定位功能
 */
- (void)onLocationAuthorityDenied;

/**
 从系统设置中心返回APP
 
 @param locationEnable YES:开启了定位权限(会定位一次并且会执行定位成功回调)  NO:未开启定位权限
 */
- (void)onEnterAppFromSystemSettingCenter:(BOOL)locationEnable;

@end

@interface DRLocationManager : NSObject

@property (nonatomic, weak) id<DRLocationManagerDelegate> delegate;

/// 仅做定位，不做百度地理反编码
@property (assign, nonatomic) BOOL locationOnly;

/// 设置定位精度，默认:kCLLocationAccuracyBest
@property(assign, nonatomic) CLLocationAccuracy desiredAccuracy;

/// 连续定位时，移动指定距离重新触发定位
@property (assign, nonatomic) CLLocationDistance distanceFilter;

/**
 创建定位管理器
 
 @param delegate 定位完成回调代理
 @return 定位管理器对象
 */
+ (instancetype)locationManagerWithDelegate:(id<DRLocationManagerDelegate>)delegate;

/**
 获取当前位置，读取的是缓存信息，如果从未正常定位过，则所有信息均为空
 
 @return 位置信息model
 */
+ (DRLocationModel *)currentLocation;

/**
 向用户询问过定位权限，用户选择过不允许或者允许（系统弹窗）
 
 @return YES:用户已经做出过选择 NO:未出现过系统弹窗或用户未做出选择
 */
+ (BOOL)hasRequestLocationAuthority;

/**
 定位不可用，用户不允许定位权限，或者全局定位开关关闭
 
 @return YES:定位不可用 NO:定位可用(用户开启的定位权限，或者安装APP后用户未使用过定位功能)
 */
+ (BOOL)locationDisable;

/**
 启动一次定位
 如果设置了delegate，在退出页面，或者确定不再使用定位时，调用removeDelegate，
 移除delegate以节省系统开销
 可参考日程编辑添加位置功能中的使用  DRScheduleLocationViewController
 */
- (void)updateLocation;

/**
 启动连续定位
 */
- (void)startUpdatingLocation;

/**
 结束连续定位
 */
- (void)stopUpdatingLocation;

@end
