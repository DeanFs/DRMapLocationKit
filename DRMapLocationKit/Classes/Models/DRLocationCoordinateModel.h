//
//  DRLocationCoordinateModel.h
//  DRMapLocationKit
//
//  Created by 冯生伟 on 2020/2/5.
//

#import <CoreLocation/CoreLocation.h>

@interface DRLocationCoordinateModel : NSObject

///纬度（垂直方向）
@property (assign, nonatomic, readonly) double latitude;
///经度（水平方向）
@property (assign, nonatomic, readonly) double longitude;
@property (assign, nonatomic) CLLocationCoordinate2D coordinate;

+ (instancetype)modelFromCoordinate:(CLLocationCoordinate2D)coordinate;
+ (instancetype)modelWithLatitude:(double)latitude
                        longitude:(double)longitude;

@end
