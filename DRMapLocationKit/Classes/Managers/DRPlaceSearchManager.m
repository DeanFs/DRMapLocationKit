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
static DRPlaceSearchManager *static_manager;
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
@property (strong, nonatomic) CLLocation *reGeocodeLocation;
@property (copy, nonatomic) void(^onReGeocodeSearchDoneBlock)(DRLocationModel *locationModel, BOOL success, NSString *message);

@end

@implementation DRPlaceSearchManager

/// 实例化查询器
/// @param currentCity 当前城市，可以传空
/// @param completeBlock 查询结果回调
+ (instancetype)searchManagerWithCurrentCity:(NSString *)currentCity
                                    location:(CLLocation *)location
                               completeBlock:(void(^)(NSArray<DRLocationPOIModel *> *searchResult, BOOL haveMoreData, BOOL success, NSString *message))completeBlock {
    DRPlaceSearchManager *manager = [DRPlaceSearchManager new];
    manager.currentCity = currentCity;
    manager.location = location;
    manager.onSearchDoneBlock = completeBlock;
    return manager;
}

+ (void)searchReGeocodeWithLocation:(CLLocation *)location
                      completeBlock:(void(^)(DRLocationModel *locationModel, BOOL success, NSString *message))completeBlock {
    if (static_manager == nil) {
        static_manager = [DRPlaceSearchManager new];
    }
    static_manager.reGeocodeLocation = location;
    static_manager.onReGeocodeSearchDoneBlock = completeBlock;
    [static_manager sendReverseGeoCodeSearchRequest];
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
    keywordsSearchRequest.requireExtension = YES;
    
    [self.searcher AMapPOIKeywordsSearch:keywordsSearchRequest];
}

- (void)sendReverseGeoCodeSearchRequest {
    CLLocationCoordinate2D coordinate = self.reGeocodeLocation.coordinate;
    AMapReGeocodeSearchRequest *request = [[AMapReGeocodeSearchRequest alloc] init];
    request.location = [AMapGeoPoint locationWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    request.requireExtension = YES;
    request.poitype = @"010000|020000|030000|040000|050000|060000|070000|080000|090000|100000|110000|120000|130000|140000|150000|160000|170000|180000|190000|200000|220000|970000|990000";
    
    [self.searcher AMapReGoecodeSearch:request];
}

#pragma mark - AMapSearchDelegate
/**
 * @brief 当请求发生错误时，会调用代理的此方法.
 * @param request 发生错误的请求.
 * @param error   返回的错误.
 */
- (void)AMapSearchRequest:(id)request didFailWithError:(NSError *)error {
    kDR_SAFE_BLOCK(self.onSearchDoneBlock, nil, NO, NO, [DRPlaceSearchManager errorInfoMapping][@(error.code)]);
    kDR_SAFE_BLOCK(self.onReGeocodeSearchDoneBlock, nil, NO, [DRPlaceSearchManager errorInfoMapping][@(error.code)]);
    static_manager.onReGeocodeSearchDoneBlock = nil;
    static_manager = nil;
}

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

/**
 * @brief 逆地理编码查询回调函数
 * @param request  发起的请求，具体字段参考 AMapReGeocodeSearchRequest 。
 * @param response 响应结果，具体字段参考 AMapReGeocodeSearchResponse 。
 */
- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response {
    if (response != nil) {
        NSMutableArray *poiList = [NSMutableArray array];
        for (AMapPOI *poi in response.regeocode.pois) {
            [poiList addObject:[DRLocationPOIModel modelWithAMapPOIModel:poi
                                                                 country:response.regeocode.addressComponent.country]];
        }
        DRLocationModel *locationModel = [[DRLocationModel alloc] init];
        locationModel.location = self.reGeocodeLocation;
        locationModel.country = response.regeocode.addressComponent.country;
        locationModel.province = response.regeocode.addressComponent.province;
        locationModel.city = response.regeocode.addressComponent.city;
        locationModel.area = response.regeocode.addressComponent.district;
        locationModel.street = response.regeocode.addressComponent.township;
        locationModel.address = response.regeocode.formattedAddress;
        locationModel.poiList = poiList;
        kDR_SAFE_BLOCK(self.onReGeocodeSearchDoneBlock, locationModel, YES, nil);
    } else {
        kDR_SAFE_BLOCK(self.onReGeocodeSearchDoneBlock, nil, NO, @"未知错误");
    }
    static_manager.onReGeocodeSearchDoneBlock = nil;
    static_manager = nil;
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

+ (NSDictionary *)errorInfoMapping
{
    static NSDictionary *errorInfoMapping = nil;
    if (errorInfoMapping == nil)
    {
        errorInfoMapping = @{@(AMapSearchErrorOK):@"没有错误",
                             @(AMapSearchErrorInvalidSignature):@"无效签名",
                             @(AMapSearchErrorInvalidUserKey):@"key非法或过期",
                             @(AMapSearchErrorServiceNotAvailable):@"没有权限使用相应的接口",
                             @(AMapSearchErrorDailyQueryOverLimit):@"访问已超出日访问量",
                             @(AMapSearchErrorTooFrequently):@"用户访问过于频繁",
                             @(AMapSearchErrorInvalidUserIP):@"用户IP无效",
                             @(AMapSearchErrorInvalidUserDomain):@"用户域名无效",
                             @(AMapSearchErrorInvalidUserSCode):@"安全码验证错误，bundleID与key不对应",
                             @(AMapSearchErrorUserKeyNotMatch):@"请求key与绑定平台不符",
                             @(AMapSearchErrorIPQueryOverLimit):@"IP请求超限",
                             @(AMapSearchErrorNotSupportHttps):@"不支持HTTPS请求",
                             @(AMapSearchErrorInsufficientPrivileges):@"权限不足，服务请求被拒绝",
                             @(AMapSearchErrorUserKeyRecycled):@"开发者key被删除，无法正常使用",
                             
                             @(AMapSearchErrorInvalidResponse):@"请求服务响应错误",
                             @(AMapSearchErrorInvalidEngineData):@"引擎返回数据异常",
                             @(AMapSearchErrorConnectTimeout):@"服务端请求链接超时",
                             @(AMapSearchErrorReturnTimeout):@"读取服务结果超时",
                             @(AMapSearchErrorInvalidParams):@"请求参数非法",
                             @(AMapSearchErrorMissingRequiredParams):@"缺少必填参数",
                             @(AMapSearchErrorIllegalRequest):@"请求协议非法",
                             @(AMapSearchErrorServiceUnknown):@"其他服务端未知错误",
                             
                             @(AMapSearchErrorClientUnknown):@"客户端未知错误，服务返回结果为空或其他错误",
                             @(AMapSearchErrorInvalidProtocol):@"协议解析错误，通常是返回结果无法解析",
                             @(AMapSearchErrorTimeOut):@"连接超时",
                             @(AMapSearchErrorBadURL):@"URL异常",
                             @(AMapSearchErrorCannotFindHost):@"找不到主机",
                             @(AMapSearchErrorCannotConnectToHost):@"服务器连接失败",
                             @(AMapSearchErrorNotConnectedToInternet):@"连接异常，通常为没有网络的情况",
                             @(AMapSearchErrorCancelled):@"连接取消",
                             
                             @(AMapSearchErrorTableIDNotExist):@"table id 格式不正确",
                             @(AMapSearchErrorIDNotExist):@"id 不存在",
                             @(AMapSearchErrorServiceMaintenance):@"服务器维护中",
                             @(AMapSearchErrorEngineTableIDNotExist):@"key对应的table id 不存在",
                             @(AMapSearchErrorInvalidNearbyUserID):@"找不到对应userID的信息",
                             @(AMapSearchErrorNearbyKeyNotBind):@"key未开通“附近”功能",
                             @(AMapSearchErrorOutOfService):@"规划点（包括起点、终点、途经点）不在中国范围内",
                             @(AMapSearchErrorNoRoadsNearby):@"规划点（包括起点、终点、途经点）附近搜不到道路",
                             @(AMapSearchErrorRouteFailed):@"路线计算失败，通常是由于道路连通关系导致",
                             @(AMapSearchErrorOverDirectionRange):@"起点终点距离过长",
                             @(AMapSearchErrorShareLicenseExpired):@"短串分享认证失败",
                             @(AMapSearchErrorShareFailed):@"短串请求失败",};
    }
    return errorInfoMapping;
}

#pragma mark - lifecycle
- (void)dealloc {
    kDR_LOG(@"%@ dealloc", NSStringFromClass([self class]));
    _searcher.delegate = nil;
}

@end
