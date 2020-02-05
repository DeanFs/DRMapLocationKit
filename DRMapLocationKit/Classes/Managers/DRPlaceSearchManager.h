//
//  DRPlaceSearchManager.h
//  Records
//
//  Created by 冯生伟 on 2019/10/24.
//  Copyright © 2019 DuoRong Technology Co., Ltd. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "DRLocationPOIModel.h"

NS_ASSUME_NONNULL_BEGIN

/// 地名位置查询器，查询结果为地名附近的POI列表
@interface DRPlaceSearchManager : NSObject

/// 实例化查询器
/// @param currentCity 当前城市，可以传空
/// @param location 当前定位坐标，可以传空
/// @param completeBlock 查询结果回调，每页20条，分页加载更多时，返回多页数据总和
+ (instancetype)searchManagerWithCurrentCity:(nullable NSString *)currentCity
                                    location:(CLLocation *)location
                               completeBlock:(void(^)(NSArray<DRLocationPOIModel *> *searchResult, BOOL haveMoreData, BOOL success, NSString *message))completeBlock;

/// 开始查询
- (void)searchWithPlace:(NSString *)place;

/// 加载更多
- (void)loadMore;

@end

NS_ASSUME_NONNULL_END
