//
//  DRLocationManager.m
//  Records
//
//  Created by 冯生伟 on 2020/2/3.
//  Copyright © 2020 DuoRong Technology Co., Ltd. All rights reserved.
//

#import "DRLocationManager.h"
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import <MJExtension/MJExtension.h>
#import <DRMacroDefines/DRMacroDefines.h>
#import "DRPlaceSearchManager.h"

#define kLocationMessageCacheKey @"LocationMessageCacheKey"

@interface DRLocationManager ()<AMapLocationManagerDelegate>

@property (nonatomic, strong) AMapLocationManager *locationManager;
@property (nonatomic, strong) CLHeading *heading;
@property (nonatomic, strong) DRLocationModel *locationModel;
@property (assign, nonatomic) CLAuthorizationStatus lastState;

@end

@implementation DRLocationManager

/**
 创建定位管理器
 
 @param delegate 定位完成回调代理
 @return 定位管理器对象
 */
+ (instancetype)locationManagerWithDelegate:(id<DRLocationManagerDelegate>)delegate {
    DRLocationManager *manager = [DRLocationManager new];
    manager.delegate = delegate;
    manager.locationManager.delegate = manager;
    return manager;
}

/**
 获取当前位置，读取的是缓存信息，如果从未正常定位过，则所有信息均为空
 
 @return 位置信息model
 */
+ (DRLocationModel *)currentLocation {
    NSMutableDictionary *dic = [[NSUserDefaults standardUserDefaults] objectForKey:kLocationMessageCacheKey];
    if (dic) {
        DRLocationModel *model = [DRLocationModel mj_objectWithKeyValues:dic];
        [model setupCoordinate];
        return model;
    }
    return nil;
}

/**
 向用户询问过定位权限，用户选择过不允许或者允许（系统弹窗）
 
 @return YES:用户已经做出过选择 NO:未出现过系统弹窗或用户未做出选择
 */
+ (BOOL)hasRequestLocationAuthority {
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse ||
        status == kCLAuthorizationStatusAuthorizedAlways ||
        status == kCLAuthorizationStatusDenied) {
        return YES;
    }
    return NO;
}

/**
 定位不可用，用户不允许定位权限，或者全局定位开关关闭
 
 @return YES:定位不可用 NO:定位可用(用户开启的定位权限，或者安装APP后用户未使用过定位功能)
 */
+ (BOOL)locationDisable {
    if (![CLLocationManager locationServicesEnabled]) {
        return YES;
    }
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
        return YES;
    }
    return NO;
}

/**
 启动一次定位
 */
- (void)updateLocation {
    [self.locationManager startUpdatingLocation];
}

/**
 启动连续定位
 */
- (void)startUpdatingLocation {
    self.locationManager.allowsBackgroundLocationUpdates = YES;
    [self updateLocation];
}

/**
 结束连续定位
 */
- (void)stopUpdatingLocation {
    self.locationManager.allowsBackgroundLocationUpdates = NO;
    [self.locationManager stopUpdatingLocation];
}

/**
 设置定位识别精度，默认 10m
 
 @param distanceFilter 定位精度
 */
- (void)setDistanceFilter:(CLLocationDistance)distanceFilter {
    self.locationManager.distanceFilter = distanceFilter;
}

- (void)setDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy {
    self.locationManager.desiredAccuracy = desiredAccuracy;
}

#pragma mark - AMapLocationManagerDelegate
/**
 *  @brief 当plist配置NSLocationAlwaysUsageDescription或者NSLocationAlwaysAndWhenInUseUsageDescription，并且[CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined，会调用代理的此方法。
 此方法实现调用申请后台权限API即可：[locationManager requestAlwaysAuthorization](必须调用,不然无法正常获取定位权限)
 *  @param manager 定位 AMapLocationManager 类。
 *  @param locationManager  需要申请后台定位权限的locationManager。
 *  @since 2.6.2
 */
- (void)amapLocationManager:(AMapLocationManager *)manager doRequireLocationAuth:(CLLocationManager*)locationManager {
    [locationManager requestAlwaysAuthorization];
}

/**
 *  @brief 连续定位回调函数.注意：本方法已被废弃，如果实现了amapLocationManager:didUpdateLocation:reGeocode:方法，则本方法将不会回调。
 *  @param manager 定位 AMapLocationManager 类。
 *  @param location 定位结果。
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location {
    if (!self.locationManager.allowsBackgroundLocationUpdates) {
        if (location.horizontalAccuracy > 0 && location.horizontalAccuracy < 100) {
            [self.locationManager stopUpdatingLocation];
        }
    }
    
    if (self.locationOnly) {
        if ([self.delegate respondsToSelector:@selector(onUpdateLocationDone:location:)]) {
            DRLocationModel *locationModel = [DRLocationModel new];
            locationModel.location = location;
            [self.delegate onUpdateLocationDone:self
                                       location:locationModel];
        }
    } else {
        kDRWeakSelf
        [DRPlaceSearchManager searchReGeocodeWithLocation:location completeBlock:^(DRLocationModel *locationModel, BOOL success, NSString *message) {
            if (success) {
                weakSelf.locationModel = locationModel;
                [weakSelf cacheLocationModel];
            } else {
                kDR_LOG(@"逆地址编码失败，未获取到定位点位置和POI信息：%@", message);
            }
        }];
    }
}

/**
 *  @brief 当定位发生错误时，会调用代理的此方法。
 *  @param manager 定位 AMapLocationManager 类。
 *  @param error 返回的错误，参考 CLError 。
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didFailWithError:(NSError *)error {
    if (error.code == 1) { // 定位权限未开启
        if ([self.delegate respondsToSelector:@selector(onLocationAuthorityDenied)]) {
            [self.delegate onLocationAuthorityDenied];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(onUpdateLocationFail:error:)]) {
            [self.delegate onUpdateLocationFail:self
                                          error:error];
        }
    }
}

/**
 *  @brief 定位权限状态改变时回调函数
 *  @param manager 定位 AMapLocationManager 类。
 *  @param status 定位权限状态。
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (self.lastState == status) {
        return;
    }
    if (self.lastState != kCLAuthorizationStatusNotDetermined) { // 判断用户已经作出过选择，用户未作出选择时，选择后高德SDK会触发一次定位
        BOOL locationEnable = status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways;
        if ([self.delegate respondsToSelector:@selector(onEnterAppFromSystemSettingCenter:)]) {
            [self.delegate onEnterAppFromSystemSettingCenter:locationEnable];
        }
        if (locationEnable) {
            if (!self.locationManager.allowsBackgroundLocationUpdates) { // 不允许后台定位，即不允许连续定位
                [self updateLocation];
            }
        }
    }
    self.lastState = status;
}

#pragma mark - private
// save location message
- (void)cacheLocationModel {
    NSMutableDictionary *dic = [self.locationModel mj_keyValuesWithKeys:@[@"country", @"province", @"city",
                                                                          @"area", @"street", @"address",
                                                                          @"lng", @"lat"]];
    [[NSUserDefaults standardUserDefaults] setObject:dic forKey:kLocationMessageCacheKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - lazy load
- (AMapLocationManager *)locationManager {
    if (!_locationManager) {
        _lastState = [CLLocationManager authorizationStatus];
        _locationManager = [[AMapLocationManager alloc] init];
    }
    return _locationManager;
}

#pragma mark - lifecycle
- (void)dealloc {
    [_locationManager stopUpdatingHeading];
    [_locationManager stopUpdatingLocation];
    _locationManager.delegate = nil;
    _locationManager = nil;
    kDR_LOG(@"%@ dealloc", NSStringFromClass([self class]));
}

@end

