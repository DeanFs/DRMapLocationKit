//
//  DRScheduleLocationModel.h
//  Records
//
//  Created by Zube on 2018/3/13.
//  Copyright © 2018年 DuoRong Technology Co., Ltd. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "DRLocationCoordinateModel.h"

@interface DRLocationPOIModel : NSObject

/// POI全局唯一id
@property (copy, nonatomic) NSString *poiId;
/// 类型编码
@property (nonatomic, copy) NSString *typecode;
/// POI名称
@property (nonatomic, copy) NSString *name;
/// 国家
@property (nonatomic, copy) NSString *country;
/// POI所在省份
@property (nonatomic, copy) NSString *province;
/// POI所在城市
@property (nonatomic, copy) NSString *city;
/// POI所在行政区域
@property (nonatomic, copy) NSString *area;
/// 街道
@property (nonatomic, copy) NSString *street;
/// POI地址信息
@property (nonatomic, copy) NSString *address;
/// 距离坐标点距离，注：此字段只对逆地理检索有效
@property (nonatomic, assign) NSInteger distance;
///区域编码
@property (nonatomic, copy) NSString *adcode;
/// 高德坐标
@property (strong, nonatomic) DRLocationCoordinateModel *coordinate;

+ (instancetype)modelWithAMapPOIModel:(id)aMapPOI
                              country:(NSString *)country;

@end
