//
//  DRSmoothPathTool.h
//  DRMapLocationKit
//
//  Created by 冯生伟 on 2020/2/16.
//

#import <Foundation/Foundation.h>
#import "DRLocationCoordinateModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DRSmoothPathTool : NSObject

@property (nonatomic, assign) int intensity;
@property (nonatomic, assign) float threshHold;
@property (nonatomic, assign) int noiseThreshhold;

/**
 * 轨迹平滑优化
 * @param originlist 原始轨迹list,list.size大于2
 * @return 优化后轨迹list
 */
- (NSArray<DRLocationCoordinateModel*>*)pathOptimize:(NSArray<DRLocationCoordinateModel*>*)originlist;

/**
 * 轨迹线路滤波
 * @param originlist 原始轨迹list,list.size大于2
 * @return 滤波处理后的轨迹list
 */
- (NSArray<DRLocationCoordinateModel*>*)kalmanFilterPath:(NSArray<DRLocationCoordinateModel*>*)originlist;


/**
 * 轨迹去噪，删除垂距大于20m的点
 * @param originlist 原始轨迹list,list.size大于2
 * @return 去燥后的list
 */
- (NSArray<DRLocationCoordinateModel*>*)removeNoisePoint:(NSArray<DRLocationCoordinateModel*>*)originlist;

/**
 * 单点滤波
 * @param lastLoc 上次定位点坐标
 * @param curLoc 本次定位点坐标
 * @return 滤波后本次定位点坐标值
 */
- (DRLocationCoordinateModel*)kalmanFilterPoint:(DRLocationCoordinateModel*)lastLoc curLoc:(DRLocationCoordinateModel*)curLoc;

/**
 * 轨迹抽稀
 * @param inPoints 待抽稀的轨迹list，至少包含两个点，删除垂距小于mThreshhold的点
 * @return 抽稀后的轨迹list
 */
- (NSArray<DRLocationCoordinateModel*>*)reducerVerticalThreshold:(NSArray<DRLocationCoordinateModel*>*)inPoints;

@end

NS_ASSUME_NONNULL_END
