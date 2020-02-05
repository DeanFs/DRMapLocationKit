//
//  DRLocationModel.m
//  Records
//
//  Created by Zube on 2018/1/30.
//  Copyright © 2018年 DuoRong Technology Co., Ltd. All rights reserved.
//

#import "DRLocationModel.h"

@implementation DRLocationModel

- (void)setLocation:(CLLocation *)location {
    _location = location;
    
    _lng = [NSString stringWithFormat:@"%lf", location.coordinate.longitude];
    _lat = [NSString stringWithFormat:@"%lf", location.coordinate.latitude];
}

- (void)setupCoordinate {
    _location = [[CLLocation alloc] initWithLatitude:self.lat.doubleValue
                                           longitude:self.lng.doubleValue];
}

@end
