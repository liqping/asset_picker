#import "AssetPickerPlugin.h"
#import <CommonCrypto/CommonDigest.h>

@interface AssetPickerPlugin()

@property(nonatomic,weak)FlutterViewController* controller;
@property(nonatomic,weak)NSObject<FlutterBinaryMessenger>* messenger;

@property(nonatomic,strong)NSString* documentsDirectoryPath;

@end

@implementation AssetPickerPlugin

+ (NSString *)encryptToMd5:(NSString *)str {
   
  const char *cStr = [str UTF8String];
  unsigned char digest[CC_MD5_DIGEST_LENGTH];
  CC_MD5( cStr, (CC_LONG)strlen(cStr),digest );
  NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
  for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
    [result appendFormat:@"%02x", digest[i]];
  return result;
}

-(instancetype)initWithController:(FlutterViewController*)controller messenger:(NSObject<FlutterBinaryMessenger>*)messenger
{
    self = [super init];
    if (self) {
        _controller = controller;
        _messenger = messenger;
    }
    return self;
}

-(instancetype)init
{
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _documentsDirectoryPath = [NSString stringWithFormat:@"%@/pickasset/imagecache",[paths objectAtIndex:0]];
    }
    return self;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"asset_picker"
                                     binaryMessenger:[registrar messenger]];


    AssetPickerPlugin* instance = [[AssetPickerPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];


}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getAllAssetCatalog" isEqualToString:call.method]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                    if(status == PHAuthorizationStatusAuthorized)
                    {
                        NSDictionary* arguments = call.arguments;
                        NSInteger type = [[arguments valueForKeyPath:@"type"] integerValue];

                        PHFetchOptions *options = [[PHFetchOptions alloc] init];
                        if (type != -1) {
                            options.predicate =
                            type == 3 ? [NSPredicate predicateWithFormat:@"mediaType == %d OR mediaType == %d", PHAssetMediaTypeImage, PHAssetMediaTypeVideo] :
                            [NSPredicate predicateWithFormat:@"mediaType == %d", type == 0 ? PHAssetMediaTypeImage : type == 1 ? PHAssetMediaTypeVideo : PHAssetMediaTypeAudio];
                        }
                        
                        options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
                        NSMutableArray* results = @[].mutableCopy;
                        PHFetchResult *fetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
                        
                        NSDictionary* firstDic = nil;
                        
                        // 这时 smartAlbums 中保存的应该是各个智能相册对应的 PHAssetCollection
                        for (NSInteger i = 0; i < fetchResult.count; i++) {
                            // 获取一个相册（PHAssetCollection）
                            PHCollection *collection = fetchResult[i];
                            if ([collection isKindOfClass:[PHAssetCollection class]]) {

                                PHAssetCollection *assetCollection = (PHAssetCollection *)collection;
                                PHAssetCollectionSubtype subType = assetCollection.assetCollectionSubtype;
                                if  (subType < 300 && subType != PHAssetCollectionSubtypeSmartAlbumAllHidden
                                     && subType != PHAssetCollectionSubtypeSmartAlbumRecentlyAdded
                                     && subType != PHAssetCollectionSubtypeSmartAlbumPanoramas
                                     && subType != PHAssetCollectionSubtypeSmartAlbumTimelapses
                                     && subType != PHAssetCollectionSubtypeSmartAlbumSlomoVideos
                                     ) {
                                    if (@available(iOS 13, *)) {
                                        if(subType == PHAssetCollectionSubtypeSmartAlbumUnableToUpload){
                                            continue;
                                        }
                                    }
                                    if (@available(iOS 15, *)) {
                                        if(subType == PHAssetCollectionSubtypeSmartAlbumRAW){
                                            continue;
                                        }
                                    }
                                    if(type == -1 || type == 2 || type == 3 || (type == 0 && subType != PHAssetCollectionSubtypeSmartAlbumVideos ) || (type == 1 && (subType == PHAssetCollectionSubtypeSmartAlbumVideos )))
                                    {
                                        PHFetchResult<PHAsset*> *fetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
                                        if(fetchResult.count < 1){
                                            continue;
                                        }
                                        if(subType == PHAssetCollectionSubtypeSmartAlbumUserLibrary){
                                            firstDic = @{@"name":assetCollection.localizedTitle,@"identifier":assetCollection.localIdentifier,@"count":@(fetchResult.count),@"subType":@(subType),@"last":fetchResult.count ? @{@"identifier": fetchResult.lastObject.localIdentifier,
                                                                                                                                                                                                                                @"width": @(fetchResult.lastObject.pixelWidth),
                                                                                                                                                                                                                                @"height":@(fetchResult.lastObject.pixelHeight),@"mediaType":@(fetchResult.lastObject.mediaType == PHAssetMediaTypeImage ? 0 : fetchResult.lastObject.mediaType == PHAssetMediaTypeVideo ? 1: 2),@"duration":@((NSInteger)fetchResult.lastObject.duration)
                                                                                                                                                                                                                                } : @{}};
                                        }else{
                                            [results addObject:@{@"name":assetCollection.localizedTitle,@"identifier":assetCollection.localIdentifier,@"count":@(fetchResult.count),@"subType":@(subType),@"last":fetchResult.count ? @{@"identifier": fetchResult.lastObject.localIdentifier,
                                            @"width": @(fetchResult.lastObject.pixelWidth),
                                            @"height":@(fetchResult.lastObject.pixelHeight),@"mediaType":@(fetchResult.lastObject.mediaType == PHAssetMediaTypeImage ? 0 : fetchResult.lastObject.mediaType == PHAssetMediaTypeVideo ? 1: 2),@"duration":@((NSInteger)fetchResult.lastObject.duration)
                                            } : @{}}];
                                        }
                                        
                                    }
                                }
                            }
                            
                        }
                       
                        fetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
                        // 这时 smartAlbums 中保存的应该是各个智能相册对应的 PHAssetCollection
                        for (NSInteger i = 0; i < fetchResult.count; i++) {
                            // 获取一个相册（PHAssetCollection）
                            PHCollection *collection = fetchResult[i];
                            if ([collection isKindOfClass:[PHAssetCollection class]]) {

                                PHAssetCollection *assetCollection = (PHAssetCollection *)collection;
                                PHAssetCollectionSubtype subType = assetCollection.assetCollectionSubtype;
                                if  (subType < 300 && subType != PHAssetCollectionSubtypeSmartAlbumAllHidden
                                     && subType != PHAssetCollectionSubtypeSmartAlbumRecentlyAdded
                                     && subType != PHAssetCollectionSubtypeSmartAlbumPanoramas
                                     && subType != PHAssetCollectionSubtypeSmartAlbumTimelapses
                                     && subType != PHAssetCollectionSubtypeSmartAlbumSlomoVideos
                                     ) {
                                    if (@available(iOS 13, *)) {
                                        if(subType == PHAssetCollectionSubtypeSmartAlbumUnableToUpload){
                                            continue;
                                        }
                                    }
                                    if (@available(iOS 15, *)) {
                                        if(subType == PHAssetCollectionSubtypeSmartAlbumRAW){
                                            continue;
                                        }
                                    }
                                    if(type == -1 || type == 2 || type == 3 || (type == 0 && subType != PHAssetCollectionSubtypeSmartAlbumVideos ) || (type == 1 && (subType == PHAssetCollectionSubtypeSmartAlbumVideos )))
                                    {
                                        PHFetchResult<PHAsset*> *fetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
                                        if(fetchResult.count < 1){
                                            continue;
                                        }
                                        [results addObject:@{@"name":assetCollection.localizedTitle,@"identifier":assetCollection.localIdentifier,@"count":@(fetchResult.count),@"last":fetchResult.count ? @{@"identifier": fetchResult.lastObject.localIdentifier,
                                        @"width": @(fetchResult.lastObject.pixelWidth),
                                        @"height":@(fetchResult.lastObject.pixelHeight),@"mediaType":@(fetchResult.lastObject.mediaType == PHAssetMediaTypeImage ? 0 : fetchResult.lastObject.mediaType == PHAssetMediaTypeVideo ? 1: 2),@"duration":@((NSInteger)fetchResult.lastObject.duration)
                                        } : @{}}];
                                    }
                                }
                            }
                            
                        }
                       
                        if(firstDic != nil){
                            [results insertObject:firstDic atIndex:0];
                        }
                        
                        result(results);
                    }
                    else if(status == PHAuthorizationStatusDenied)
                    {
                        result([FlutterError errorWithCode:@"-1" message:@"用户拒绝访问相册!" details:nil]);
                        return;
                    }
                    else if(status == PHAuthorizationStatusRestricted)
                    {
                        result([FlutterError errorWithCode:@"-2" message:@"因系统原因，无法访问相册！" details:nil]);
                        return;
                    }
                    result([FlutterError errorWithCode:@"-3" message:@"用户未选择权限" details:nil]);
                    return;
            }];
        });
    }
    else if ([@"getAssetsFromCatalog" isEqualToString:call.method]) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if(status == PHAuthorizationStatusAuthorized)
                {
                    NSDictionary* arguments = call.arguments;
                            NSInteger type = [[arguments valueForKeyPath:@"type"] integerValue];
                            NSString* identifier = [arguments valueForKeyPath:@"identifier"];
                            BOOL ascend = ![[arguments valueForKeyPath:@"desc"] boolValue];

                            if (identifier.length) {

                                if ([identifier isEqualToString:@"all_identifier"]) {
                                    PHFetchOptions *options = [[PHFetchOptions alloc] init];
                                    if (type != -1) {
                                        options.predicate = type == 3 ? [NSPredicate predicateWithFormat:@"mediaType == %d OR mediaType == %d", PHAssetMediaTypeImage, PHAssetMediaTypeVideo] : [NSPredicate predicateWithFormat:@"mediaType == %d", type == 0 ? PHAssetMediaTypeImage : type == 1 ? PHAssetMediaTypeVideo : PHAssetMediaTypeAudio];
                                    }
    //                                options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", type == 0 ? PHAssetMediaTypeImage : PHAssetMediaTypeVideo];

                                    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:ascend]];

                                    PHFetchResult<PHAsset *>* assetsFetchResults = [PHAsset fetchAssetsWithOptions:options];
                                    NSMutableArray* results = [NSMutableArray arrayWithCapacity:assetsFetchResults.count];
                                    for (PHAsset * obj in assetsFetchResults) {
                                        if(obj.mediaType != PHAssetMediaTypeUnknown)
                                        {
                                            NSInteger mdType = obj.mediaType == PHAssetMediaTypeImage ? 0 : obj.mediaType == PHAssetMediaTypeVideo ? 1: 2;
                                            
                                            [results addObject:@{@"identifier": obj.localIdentifier,
                                                                 @"width": @(obj.pixelWidth),
                                                                 @"height":@(obj.pixelHeight),
                                                                 @"mediaType":@(mdType),
                                                                 @"duration":@((NSInteger)obj.duration)
                                            }];
                                        }
                                    }
                                    result(results);
                                }
                                else
                                {
                                    PHFetchResult<PHAssetCollection *> * collections = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[identifier] options:nil];

                                    if (collections.count) {

                                        PHFetchOptions *options = [[PHFetchOptions alloc] init];
                                        if (type != -1) {
                                            options.predicate = type == 3 ? [NSPredicate predicateWithFormat:@"mediaType == %d OR mediaType == %d", PHAssetMediaTypeImage, PHAssetMediaTypeVideo] : [NSPredicate predicateWithFormat:@"mediaType == %d", type == 0 ? PHAssetMediaTypeImage : type == 1 ? PHAssetMediaTypeVideo : PHAssetMediaTypeAudio];
                                        }

                                        options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:ascend]];
                                        PHFetchResult<PHAsset *>* assetsFetchResults = [PHAsset fetchAssetsInAssetCollection:collections.firstObject options:options];

                                        NSMutableArray* results = [NSMutableArray arrayWithCapacity:assetsFetchResults.count];
                                        for (PHAsset * obj in assetsFetchResults) {
                                            if(obj.mediaType != PHAssetMediaTypeUnknown)
                                            {
                                                NSInteger mdType = obj.mediaType == PHAssetMediaTypeImage ? 0 : obj.mediaType == PHAssetMediaTypeVideo ? 1: 2;
                                                
                                                [results addObject:@{@"identifier": obj.localIdentifier,
                                                                     @"width": @(obj.pixelWidth),
                                                                     @"height":@(obj.pixelHeight),
                                                                     @"mediaType":@(mdType),
                                                                     @"duration":@((NSInteger)obj.duration)
                                                }];
                                            }
                                        }
                                        result(results);

                                    }
                                    else
                                    {
                                        result([FlutterError errorWithCode:@"-2" message:@"The PHFetchOptions does not exist" details:nil]);
                                    }

                                }


                            }
                            else
                            {
                                result([FlutterError errorWithCode:@"-1" message:@"identifier == null" details:nil]);
                            }
                }
            }];
        });
        

    }
    else if ([@"requestImageThumbnail" isEqualToString:call.method]) {
        NSDictionary* arguments = call.arguments;
        NSString* identifier = arguments[@"identifier"];
        NSInteger width = [arguments[@"width"] integerValue];
        NSInteger height = [arguments[@"height"] integerValue];
        NSInteger quality = [arguments[@"quality"] integerValue];
        BOOL needCache = [arguments[@"needCache"] boolValue];
        if (identifier.length) {
            
            NSString* thumbPath = [NSString stringWithFormat:@"%@/%@",_documentsDirectoryPath,[AssetPickerPlugin encryptToMd5:[NSString stringWithFormat:@"%@_%li_%li",identifier,width,height]]];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                PHImageRequestOptions* options = [PHImageRequestOptions new];
                options.resizeMode = PHImageRequestOptionsResizeModeFast;
                options.networkAccessAllowed = YES;
                options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
                options.synchronous = YES;
                PHFetchResult<PHAsset *>* assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[identifier] options:nil];
                if (assets.count) {
                    PHImageRequestID ID = [[PHImageManager defaultManager] requestImageForAsset:assets.firstObject targetSize:CGSizeMake(width, height) contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable image, NSDictionary * _Nullable info) {
                        if (image) {
                            NSData* thumbData = UIImageJPEGRepresentation(image, ((CGFloat)quality)/100.f);
                            result(thumbData);
                            if(needCache){
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{[thumbData writeToFile:thumbPath atomically:NO];});
                            }

                        }
                        else
                        {
                            result([FlutterError errorWithCode:@"-4" message:@"The requested image does not exist." details:nil]);
                        }
                    }];
                    if (ID == PHInvalidImageRequestID) {
                        result([FlutterError errorWithCode:@"-3" message:@"The requested image does not exist." details:nil]);
                    }
                }
                else
                {
                    result([FlutterError errorWithCode:@"-2" message:@"The requested image does not exist." details:nil]);
                }
            });
        
        }
        else
        {
            result([FlutterError errorWithCode:@"-1" message:@"identifier == null" details:nil]);
        }
    }
    else if ([@"requestImageOriginal" isEqualToString:call.method]) {

        NSDictionary* arguments = call.arguments;
        NSString* identifier = arguments[@"identifier"];
        NSInteger quality = [arguments[@"quality"] integerValue];

        if (identifier.length) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                PHImageRequestOptions* options = [PHImageRequestOptions new];
                options.networkAccessAllowed = YES;
                options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
                options.synchronous = false;
                options.version = PHImageRequestOptionsVersionCurrent;

                PHFetchResult<PHAsset *>* assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[identifier] options:nil];
                if (assets.count) {
                    CGSize targetSize = PHImageManagerMaximumSize;
                    if([arguments objectForKey:@"width"])
                    {
                        targetSize = CGSizeMake([[arguments objectForKey:@"width"] floatValue], [[arguments objectForKey:@"height"] floatValue]);
                    }
                    PHImageRequestID ID = [[PHImageManager defaultManager] requestImageForAsset:assets.firstObject targetSize:targetSize contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable image, NSDictionary * _Nullable info) {
                        if (image) {
                            result(UIImageJPEGRepresentation(image, ((CGFloat)quality)/100.f));
                        }
                        else
                        {
                            result([FlutterError errorWithCode:@"-4" message:@"The requested image does not exist." details:nil]);
                        }
                    }];
                    if (ID == PHInvalidImageRequestID) {
                        result([FlutterError errorWithCode:@"-3" message:@"The requested image does not exist." details:nil]);
                    }
                }
                else
                {
                    result([FlutterError errorWithCode:@"-2" message:@"The requested image does not exist." details:nil]);
                }
            });
        }
        else
        {
            result([FlutterError errorWithCode:@"-1" message:@"identifier == null" details:nil]);
        }
    }
    else if ([@"requestVideoUrl" isEqualToString:call.method]) {

        NSString* identifier = call.arguments;

        if (identifier.length) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                PHImageRequestOptions* options = [PHImageRequestOptions new];
                options.networkAccessAllowed = YES;
                options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
                options.synchronous = false;
                options.version = PHImageRequestOptionsVersionCurrent;

                PHFetchResult<PHAsset *>* assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[identifier] options:nil];
                if (assets.count) {
                    
                    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
                    options.version = PHVideoRequestOptionsVersionCurrent;
                    options.networkAccessAllowed = YES;
                    options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
                    
                    
                    PHImageRequestID ID = [[PHImageManager defaultManager]  requestAVAssetForVideo:assets.firstObject options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                        if(asset != nil){
                            AVURLAsset* avAsset = (AVURLAsset*)asset;
                            result(avAsset.URL.path);
                        }
                        else{
                            result([FlutterError errorWithCode:@"-4" message:@"The requested video does not exist." details:nil]);
                        }
                        
                    }];
                    
                    if (ID == PHInvalidImageRequestID) {
                        result([FlutterError errorWithCode:@"-3" message:@"The requested video does not exist." details:nil]);
                    }
                }
                else
                {
                    result([FlutterError errorWithCode:@"-2" message:@"The requested video does not exist." details:nil]);
                }
            });
            
        }
        else
        {
            result([FlutterError errorWithCode:@"-1" message:@"identifier == null" details:nil]);
        }
    }
    else if ([@"rawDataToJpgFile" isEqualToString:call.method]) {
        NSDictionary* arguments = call.arguments;
        FlutterStandardTypedData * rawData = arguments[@"rawData"];
        NSInteger width = [arguments[@"width"] integerValue];
        NSInteger height = [arguments[@"height"] integerValue];
        NSInteger thumbWidth = [arguments[@"thumbWidth"] integerValue];
        NSInteger thumbHeight = [arguments[@"thumbHeight"] integerValue];
        NSInteger quality = [arguments[@"quality"] integerValue];
        NSString* fileName = arguments[@"fileName"];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage* image = [self convertBitsDataIntoUIImage:rawData.data width:width height:height];
            NSData* jpgData = UIImageJPEGRepresentation(image, ((CGFloat)quality)/100.f);
            if(!jpgData){
                result([FlutterError errorWithCode:@"-1" message:@"convert failure" details:nil]);
                return;
            }
            NSArray *paths1 = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *cachesDir = [paths1 objectAtIndex:0];
            NSString* filePath = [NSString stringWithFormat:@"%@/%@.jpg",cachesDir,fileName];
            if(![jpgData writeToFile:filePath atomically:YES]){
                result([FlutterError errorWithCode:@"-2" message:@"save failure" details:nil]);
                return;
            }
            
            if(thumbWidth <= 0 || thumbHeight <= 0){
                result(@{@"path":filePath});
                return;
            }
            
            
            
        
            CGFloat scaleWidth = thumbWidth / [UIScreen mainScreen].scale;
            CGFloat scaleHeight = thumbHeight / [UIScreen mainScreen].scale;
            CGFloat ratio = (CGFloat)width/(CGFloat)height;
            
            if(scaleWidth/scaleHeight > ratio){
                scaleWidth = scaleHeight * ratio;
            }
            else{
                scaleHeight = scaleWidth / ratio;
            }
            
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(scaleWidth, scaleHeight), true, 0.0);
            [image drawInRect:CGRectMake(0, 0, scaleWidth, scaleHeight)];
            UIImage* thumbImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            NSString* thumbFilePath = [NSString stringWithFormat:@"%@/%@_.jpg",cachesDir,fileName];
            BOOL thumbSave = NO;
            if(thumbImage){
                jpgData = UIImageJPEGRepresentation(thumbImage, 1.0);
                thumbSave = [jpgData writeToFile:thumbFilePath atomically:YES];
            }
            
            
            if(thumbSave){
                result(@{@"path":filePath,@"thumb":thumbFilePath});
            }
            else{
                result(@{@"path":filePath});
            }
        });
        
        
    }
    else if ([@"rawDataToPngFile" isEqualToString:call.method]) {
        NSDictionary* arguments = call.arguments;
        FlutterStandardTypedData * rawData = arguments[@"rawData"];
        NSInteger width = [arguments[@"width"] integerValue];
        NSInteger height = [arguments[@"height"] integerValue];
        NSInteger thumbWidth = [arguments[@"thumbWidth"] integerValue];
        NSInteger thumbHeight = [arguments[@"thumbHeight"] integerValue];
        NSString* fileName = arguments[@"fileName"];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage* image = [self convertBitsDataIntoUIImage:rawData.data width:width height:height];
            NSData* pngData = UIImagePNGRepresentation(image);
            if(!pngData){
                result([FlutterError errorWithCode:@"-1" message:@"convert failure" details:nil]);
                return;
            }
            NSArray *paths1 = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *cachesDir = [paths1 objectAtIndex:0];
            NSString* filePath = [NSString stringWithFormat:@"%@/%@.png",cachesDir,fileName];
            if(![pngData writeToFile:filePath atomically:YES]){
                result([FlutterError errorWithCode:@"-2" message:@"save failure" details:nil]);
                return;
            }
            
            if(thumbWidth <= 0 || thumbHeight <= 0){
                result(@{@"path":filePath});
                return;
            }
            
            CGFloat scaleWidth = thumbWidth / [UIScreen mainScreen].scale;
            CGFloat scaleHeight = thumbHeight / [UIScreen mainScreen].scale;
            CGFloat ratio = (CGFloat)width/(CGFloat)height;
            
            if(scaleWidth/scaleHeight > ratio){
                scaleWidth = scaleHeight * ratio;
            }
            else{
                scaleHeight = scaleWidth / ratio;
            }
            
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(scaleWidth, scaleHeight), true, 0.0);
            [image drawInRect:CGRectMake(0, 0, scaleWidth, scaleHeight)];
            UIImage* thumbImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            NSString* thumbFilePath = [NSString stringWithFormat:@"%@/%@_.png",cachesDir,fileName];
            BOOL thumbSave = NO;
            if(thumbImage){
                pngData = UIImagePNGRepresentation(thumbImage);
                thumbSave = [pngData writeToFile:thumbFilePath atomically:YES];
            }
            if(thumbSave){
                result(@{@"path":filePath,@"thumb":thumbFilePath});
            }
            else{
                result(@{@"path":filePath});
            }
        });
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}


- (UIImage*) convertBitsDataIntoUIImage:(NSData*)data width:(NSInteger)width height:(NSInteger)height
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();//

    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data.bytes, width*height*4, NULL);
    CGImageRef cgImage = CGImageCreate(width,
                                        height,
                                        8,
                                        32,
                                        width*4,
                                        colorSpace,
                                        kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault,
                                        provider,
                                        NULL,
                                        NO,
                                        kCGRenderingIntentDefault);
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];

    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cgImage);
    return image;
}

@end
