//
//  DRMapLoctionKit.m
//  DRMapLocationKit_Example
//
//  Created by 冯生伟 on 2020/2/4.
//  Copyright © 2020 Dean_F. All rights reserved.
//

#import "DRMapLoctionKit.h"
#import <AMapFoundationKit/AMapFoundationKit.h>

@implementation DRMapLoctionKit

/// 初始化地图，定位服务
/// @param appKey 第三方地图服务appKey
/// @param otherParams 备用字段
+ (void)setupMapLocationKitWithAppKey:(NSString *)appKey
                          otherParams:(NSDictionary *)otherParams {
    [[AMapServices sharedServices] setEnableHTTPS:YES];
    [[AMapServices sharedServices] setApiKey:appKey];
}

@end
