//
//  DRLocationCoordinateModel.h
//  DRMapLocationKit
//
//  Created by 冯生伟 on 2020/2/5.
//

#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DRLocationCoordinateModel : NSObject

///纬度（垂直方向）
@property (assign, nonatomic, readonly) CGFloat latitude;
///经度（水平方向）
@property (assign, nonatomic, readonly) CGFloat longitude;
@property (assign, nonatomic) CLLocationCoordinate2D coordinate;

+ (instancetype)modelFromCoordinate:(CLLocationCoordinate2D)coordinate;
+ (instancetype)modelWithLatitude:(CGFloat)latitude
                        longitude:(CGFloat)longitude;

@end

NS_ASSUME_NONNULL_END
