//
//  DRLocationCoordinateModel.m
//  DRMapLocationKit
//
//  Created by 冯生伟 on 2020/2/5.
//

#import "DRLocationCoordinateModel.h"

@implementation DRLocationCoordinateModel

- (instancetype)initWithLatitude:(CGFloat)latitude
                       longitude:(CGFloat)longitude {
    if (self = [super init]) {
        _latitude = latitude;
        _longitude = longitude;
        _coordinate = CLLocationCoordinate2DMake(latitude, longitude);
    }
    return self;
}

+ (instancetype)modelFromCoordinate:(CLLocationCoordinate2D)coordinate {
    return [[DRLocationCoordinateModel alloc] initWithLatitude:coordinate.latitude
                                                     longitude:coordinate.longitude];
}

+ (instancetype)modelWithLatitude:(CGFloat)latitude
                        longitude:(CGFloat)longitude {
    return [[DRLocationCoordinateModel alloc] initWithLatitude:latitude
                                                     longitude:longitude];
}

@end
