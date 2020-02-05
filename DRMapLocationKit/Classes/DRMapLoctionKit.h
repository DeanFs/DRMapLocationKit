//
//  DRMapLoctionKit.h
//  DRMapLocationKit_Example
//
//  Created by 冯生伟 on 2020/2/4.
//  Copyright © 2020 Dean_F. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DRLocationModel.h"
#import "DRLocationPOIModel.h"
#import "DRLocationCoordinateModel.h"
#import "DRLocationManager.h"
#import "DRPlaceSearchManager.h"
#import "DRRoutePlanManager.h"

@interface DRMapLoctionKit : NSObject

/// 初始化地图，定位服务
/// @param appKey 第三方地图服务appKey
/// @param otherParams 备用字段
+ (void)setupMapLocationKitWithAppKey:(NSString *)appKey
                          otherParams:(NSDictionary *)otherParams;

@end
