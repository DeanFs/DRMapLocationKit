//
//  DRPlaceSearchManager.m
//  Records
//
//  Created by 冯生伟 on 2019/10/24.
//  Copyright © 2019 DuoRong Technology Co., Ltd. All rights reserved.
//

#import "DRPlaceSearchManager.h"
#import <AMapSearchKit/AMapSearchKit.h>
#import <DRMacroDefines/DRMacroDefines.h>

#define kPageSize 20

@interface DRPlaceSearchManager () <AMapSearchDelegate>

@property (nonatomic, copy) NSString *currentCity;
@property (assign, nonatomic) CLLocation *location;
@property (nonatomic, copy) NSString *currentSearchText;
@property (nonatomic, copy) void(^onSearchDoneBlock)(NSArray<DRLocationPOIModel *> *searchResult, BOOL haveMoreData, BOOL success, NSString *message);
@property (nonatomic, strong) AMapSearchAPI *searcher;
@property (nonatomic, assign) BOOL searchWholeCountry; // 正在全国搜索
@property (nonatomic, assign) NSInteger pageIndex;
@property (nonatomic, copy) NSString *searchingCity;
@property (nonatomic, strong) NSMutableArray<DRLocationPOIModel *> *poiList;

@end

@implementation DRPlaceSearchManager

/// 实例化查询器
/// @param currentCity 当前城市，可以传空
/// @param completeBlock 查询结果回调
+ (instancetype)searchManagerWithCurrentCity:(nullable NSString *)currentCity
                                    location:(CLLocation *)location
                               completeBlock:(void(^)(NSArray<DRLocationPOIModel *> *searchResult, BOOL haveMoreData, BOOL success, NSString *message))completeBlock {
    DRPlaceSearchManager *manager = [DRPlaceSearchManager new];
    manager.currentCity = currentCity;
    manager.location = location;
    manager.onSearchDoneBlock = completeBlock;
    return manager;
}

- (void)searchWithPlace:(NSString *)place {
    [self.poiList removeAllObjects];
    self.pageIndex = 1;
    self.searchWholeCountry = NO;
    self.currentSearchText = place;
    [self startSearchInCity:self.currentCity];
}

/// 加载更多
- (void)loadMore {
    self.pageIndex ++;
    [self startSearchInCity:self.searchingCity];
}

- (void)startSearchInCity:(NSString *)city {
    self.searchingCity = city;
    AMapPOIKeywordsSearchRequest *keywordsSearchRequest = [[AMapPOIKeywordsSearchRequest alloc] init];
    keywordsSearchRequest.page = self.pageIndex;
    keywordsSearchRequest.offset = kPageSize;
    if (city.length > 0) {
        keywordsSearchRequest.city = city;
    }
    if (self.location != nil) {
        keywordsSearchRequest.location = [AMapGeoPoint locationWithLatitude:self.location.coordinate.latitude
                                                                  longitude:self.location.coordinate.longitude];
    }
    keywordsSearchRequest.keywords = self.currentSearchText;
    
    [self.searcher AMapPOIKeywordsSearch:keywordsSearchRequest];
}

#pragma mark - AMapSearchDelegate
/**
 * @brief POI查询回调函数
 * @param request  发起的请求，具体字段参考 AMapPOISearchBaseRequest 及其子类。
 * @param response 响应结果，具体字段参考 AMapPOISearchResponse 。
 */
- (void)onPOISearchDone:(AMapPOISearchBaseRequest *)request response:(AMapPOISearchResponse *)response {
    if (response != nil) {
        for (AMapPOI *poiInfo in response.pois) {
            if (poiInfo.address.length == 0) {
                continue;
            }
            DRLocationPOIModel *model = [DRLocationPOIModel modelWithAMapPOIModel:poiInfo country:@"中国"];
            [self.poiList addObject:model];
        }
        if (self.poiList.count == 0 && response.pois.count > 0 && !self.searchWholeCountry) {
            self.searchWholeCountry = YES;
            AMapPOI *poi = [response.pois firstObject];
            [self startSearchInCity:poi.name];
            return;
        }
        if (self.poiList.count == 0) {
            kDR_SAFE_BLOCK(self.onSearchDoneBlock, nil, NO, NO, @"无法找到位置点");
        } else {
            BOOL haveMore = YES;
            if (response.count < kPageSize) {
                haveMore = NO;
            }
            kDR_SAFE_BLOCK(self.onSearchDoneBlock, self.poiList, haveMore, YES, nil);
        }
    } else {
        kDR_SAFE_BLOCK(self.onSearchDoneBlock, nil, NO, NO, @"没有找到检索结果");
    }
}

#pragma mark - lazy load
- (AMapSearchAPI *)searcher{
    if (!_searcher) {
        _searcher =[[AMapSearchAPI alloc] init];
        _searcher.delegate = self;
    }
    return _searcher;
}

- (NSMutableArray<DRLocationPOIModel *> *)poiList {
    if (!_poiList) {
        _poiList = [NSMutableArray array];
    }
    return _poiList;
}

- (void)dealloc {
    kDR_LOG(@"%@ dealloc", NSStringFromClass([self class]));
    self.searcher.delegate = nil;
}

@end
