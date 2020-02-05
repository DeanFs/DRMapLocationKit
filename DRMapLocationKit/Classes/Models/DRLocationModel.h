//
//  DRLocationModel.h
//  Records
//
//  Created by Zube on 2018/1/30.
//  Copyright © 2018年 DuoRong Technology Co., Ltd. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "DRLocationPOIModel.h"

@interface DRLocationModel : NSObject

// 以下信息均为百度坐标系
@property (nonatomic, copy) NSString *country;
@property (nonatomic, copy) NSString *province;
@property (nonatomic, copy) NSString *city;
@property (nonatomic, copy) NSString *area;
@property (nonatomic, copy) NSString *street;
@property (nonatomic, copy) NSString *address;
@property (copy, nonatomic) NSString *lng;
@property (copy, nonatomic) NSString *lat;
@property (strong, nonatomic) CLLocation *location;
@property (nonatomic, strong) NSArray<DRLocationPOIModel *> *poiList;

- (void)setupCoordinate;

@end
