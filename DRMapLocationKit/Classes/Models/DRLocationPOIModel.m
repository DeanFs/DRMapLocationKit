//
//  DRScheduleLocationModel.m
//  Records
//
//  Created by Zube on 2018/3/13.
//  Copyright © 2018年 DuoRong Technology Co., Ltd. All rights reserved.
//

#import "DRLocationPOIModel.h"
#import <AMapSearchKit/AMapCommonObj.h>
#import <MJExtension/MJExtension.h>

@implementation DRLocationPOIModel

+ (instancetype)modelWithAMapPOIModel:(AMapPOI *)aMapPOI
                              country:(NSString *)country {
    DRLocationPOIModel *poi = [DRLocationPOIModel mj_objectWithKeyValues:[aMapPOI mj_keyValues]];
    poi.area = aMapPOI.district;
    poi.coordinate = [DRLocationCoordinateModel modelWithLatitude:aMapPOI.location.latitude
                                                        longitude:aMapPOI.location.longitude];
    poi.country = country;
    poi.poiId = aMapPOI.uid;
    return poi;
}

- (NSString *)province {
    if (!_province) {
        _province = @"";
    }
    return _province;
}

- (NSString *)city {
    if (!_city) {
        _city = @"";
    }
    return _city;
}

- (NSString *)area {
    if (!_area) {
        _area = @"";
    }
    return _area;
}

- (NSString *)street {
    if (!_street) {
        _street = @"";
    }
    return _street;
}

@end
