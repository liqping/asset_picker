import 'dart:async';
import 'dart:io';

import 'package:asset_picker/src/asset_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AssetPicker {
  static const MethodChannel _channel = MethodChannel('asset_picker');
  static String? _contentUri;

  static Future<List<AssetCollection>>  getAllAssetCatalog(bool desc,[int type = 0]) async {
    try {
      final List allAsset = await (_channel.invokeMethod('getAllAssetCatalog',<String, dynamic>{ 'type': type,'desc':desc}));
      var assetsCollections = <AssetCollection>[];
      for (final item in allAsset) {
        int count = Platform.isIOS ? item['count'] : item['children'].length;
        final assetsCollection = AssetCollection(item['identifier'], item['name'],count,);
        if(Platform.isAndroid){
          assetsCollection.children = [];
          for(final child in item['children']){
            assetsCollection.children!.add(Asset(child['identifier'],child['width'],child['height'],child['mediaType'],child['duration'],fileId: child['fileId']));
          }
          if(assetsCollection.children!.isNotEmpty){
            if(desc){
              assetsCollection.lastAsset = assetsCollection.children!.first;
            }else{
              assetsCollection.lastAsset = assetsCollection.children!.last;
            }
          }
        } if(item['last'] != null){
          final lastAsset =  item['last'] as Map;
          if(lastAsset.isNotEmpty)
          {
            assetsCollection.lastAsset = Asset(lastAsset['identifier'],lastAsset['width'], lastAsset['height'],lastAsset['mediaType'],lastAsset['duration'],fileId: lastAsset['fileId']);
          }
        }
        assetsCollections.add(assetsCollection);
      }
      return assetsCollections;
    }catch (e) {
      rethrow;
    }
  }

  static Future<String?>  getFileExternalContentUri() async {
    _contentUri ??= await _channel.invokeMethod('getFileExternalContentUri');
    return _contentUri;
  }

  static Future<List>  getAssetsFromCatalog(String? identifier,bool desc,[int type = 0]) async {
    try {
      final List allAsset = await (_channel.invokeMethod('getAssetsFromCatalog',<String, dynamic>{
        'type': type,
        'desc':desc,
        'identifier':identifier
      }));
      final assets = <Asset>[];
      for (final item in allAsset) {
        var asset = Asset(
          item['identifier'],
          item['width'],
          item['height'],
            item['mediaType'],
            item['duration'].toInt(),
          fileId: item['fileId']
        );
        assets.add(asset);
      }
      return assets;
    }catch (e) {
      rethrow;
    }
  }


  /// isVideo used android only

  static Future<Uint8List?> requestImageThumbnail(String identifier, bool needCache, int width, int height,[int quality = 100, bool isVideo = false,int? fileId]) async {


    if (width < 0) {
      throw ArgumentError.value(width, 'width cannot be negative');
    }

    if (height < 0) {
      throw ArgumentError.value(height, 'height cannot be negative');
    }

    if (quality < 0 || quality > 100) {
      throw ArgumentError.value(
          quality, 'quality should be in range 0-100');
    }
    try {
      return await _channel.invokeMethod(
          "requestImageThumbnail", <String, dynamic>{
        "identifier": identifier,
        "width": width,
        "height": height,
        "quality": quality,
        "isVideo":isVideo,
        "needCache":needCache,
        if(fileId != null) "fileId":fileId
      });
    }catch (e) {
      if (kDebugMode) {
        print("error:$e");
      }
      return null;
//      throw e;
    }
  }

  static Future<String?> requestVideoUrl(String identifier) async {
    try {
      return await _channel.invokeMethod(
          "requestVideoUrl", identifier);
    }catch (e) {
      if (kDebugMode) {
        print("error:$e");
      }
      return null;
//      throw e;
    }
  }

  /// Requests the original image data for a given
  /// [identifier].
  ///
  /// This method is used by the asset class, you
  /// should not invoke it manually. For more info
  /// refer to [Asset] class docs.
  ///
  /// The actual image data is sent via BinaryChannel.
  /// *** isVideo used android only ***
  static Future<Uint8List?> requestImageOriginal(
      String? identifier,{
    int? maxWidth,
    int? maxHeight,
    int quality = 70,
    bool isVideo = false,
    int? fileId}) async {
    try {
      return await _channel.invokeMethod(
          "requestImageOriginal", <String, dynamic>{
        "identifier": identifier,
        "quality": quality,
        "isVideo":isVideo,
        if(fileId != null) "fileId":fileId,
        if(maxWidth != null) 'width':maxWidth,
        if(maxHeight != null) 'height':maxHeight,
      });
    }catch (e) {
      return null;
    }
  }


  /// raw rgb to jpg
  /// rawData: rgba 数据
  /// fileName: md5文件名
  /// return map{'path' and 'thumb'} 原图 缩略图文件地址

  static Future<Map?> rawDataToJpgFile(String fileName,dynamic rawData,int width,int height,{int? thumbWidth,int? thumbHeight,int quality = 100}) async{
    try {
      return await _channel.invokeMethod(
          "rawDataToJpgFile", <String, dynamic>{
        "rawData": rawData,
        "fileName":fileName,
        "width":width,
        "height":height,
        "thumbWidth": thumbWidth ?? -1,
        "thumbHeight": thumbHeight ?? -1,
        "quality": quality
      });
    }catch (e) {
      if (kDebugMode) {
        print("error:$e");
      }
      return null;
    }
  }

  ///raw rbg to png
  /// rawData: rgba 数据
  /// fileName: md5文件名
  /// return map{'path' and 'thumb'} 原图 缩略图文件地址

  static Future<Map?> rawDataToPngFile(String fileName,dynamic rawData,int width,int height,{int? thumbWidth,int? thumbHeight}) async{
    try {
      return await _channel.invokeMethod(
          "rawDataToPngFile", <String, dynamic>{
        "rawData": rawData,
        "fileName":fileName,
        "width":width,
        "height":height,
        "thumbWidth": thumbWidth ?? -1,
        "thumbHeight": thumbHeight ?? -1,
      });
    }catch (e) {
      if (kDebugMode) {
        print("error:$e");
      }
      return null;
    }
  }
}
