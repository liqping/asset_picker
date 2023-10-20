import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../asset_picker.dart';


String? _cachedPath;

/// 判断是否有对应图片缓存文件存在
Future<Uint8List?> getFileBytes(String url) async {
  String cacheDirPath = await getCachePath();

  String urlMd5 = getUrlMd5(url);
//  return await compute(_getFileBytes,"$cacheDirPath/$urlMd5");
  File file = File("$cacheDirPath/$urlMd5");

  try{
    return await file.readAsBytes();
  }catch(e){
    //ignore
  }
  return null;
}

Future<String> getFileNameMd5(String url) async{
  final cachedPath = await getCachePath();
  return "$cachedPath/${getUrlMd5(url)}";
}

/// disk cache

/// 获取url字符串的MD5值
String getUrlMd5(String url) {
  var content = const Utf8Encoder().convert(url);
  var digest = md5.convert(content);
  return digest.toString();
}



/// 获取图片缓存路径
FutureOr<String> getCachePath() async {
  if(_cachedPath == null){
    Directory dir = await getApplicationDocumentsDirectory();
    Directory cachePath = Directory("${dir.path}/pickasset/imagecache/");
    if (!cachePath.existsSync()) {
      cachePath.createSync(recursive: true);
    }
    _cachedPath = cachePath.path;
  }
  return _cachedPath!;
}

class Asset {
  /// The resource identifier
  final String _identifier;

  /// Original image width
  final int? _originalWidth;

  /// Original image height
  final int? _originalHeight;


  int? mediaType;  //asset type 0 image 1 video 2 audio
  int? duration;  // video or audio duration seconds
  String? mediaUrl; //video or audio file path

  final int? fileId;

  ///编辑裁剪信息
  /// path:file local path
  /// thumb: thumb file local path
  /// txt: text info
  /// mosaics: List<_MosaicModel>
  /// mosaicsPoints: List<Offset>
  /// mosaicScale: mosaic's scale
  /// lines: List<_LineModel>
  /// quarterTurns: the quarterTurns of image
  /// cut: {'offset','size'} base px
  Map? editInfo;

  late double ration;

  Asset(
      this._identifier,
      this._originalWidth,
      this._originalHeight,
      this.mediaType,
      this.duration,{
        this.fileId,
        // this.isXFile,
      }){
    if(mediaType! > 0 && Platform.isAndroid){
      mediaUrl = _identifier;
    }
    if(_originalHeight == null || _originalHeight == null || _originalWidth == 0 || _originalHeight ==0){
      ration = 1;
    }
    else{
      ration = _originalHeight! / _originalWidth!;
    }

  }

  /// Returns the original image width
  int get originalWidth {
    return _originalWidth ?? 0;
  }

  /// Returns the original image height
  int get originalHeight {
    return _originalHeight ?? 0;
  }

  /// Returns true if the image is landscape
  bool get isLandscape {
    return originalWidth > originalHeight;
  }

  /// Returns true if the image is Portrait
  bool get isPortrait {
    return originalWidth < originalHeight;
  }

  /// Returns the image identifier
  String get identifier {
    return _identifier;
  }



  /// Requests a thumbnail for the [Asset] with give [width] and [hegiht].
  ///
  /// The method returns a Future with the [ByteData] for the thumb,
  /// as well as storing it in the _thumbData property which can be requested
  /// later again, without need to call this method again.
  ///
  /// You can also pass the optional parameter [quality] to reduce the quality
  /// and the size of the returned image if needed. The value should be between
  /// 0 and 100. By default it set to 100 (max quality).
  ///
  /// Once you don't need this thumb data it is a good practice to release it,
  /// by calling releaseThumb() method.
  Future<Uint8List?> getImageThumbByteData(int width, int height, {int quality = 100,bool needCached = false}) async {

    if(mediaType == 2) {
      return null;
    }

    if(editInfo != null){
      String? path = editInfo!['thumb'];
      path ??= editInfo!['path'];
      final file = File(path!);
      final bytes = await file.readAsBytes();

      return bytes;
    }


    assert(width >= 0 && height >= 0,'width or height cannot be negative');
    assert(quality >= 0 && quality <= 100,'quality should be in range 0-100');

    Uint8List? assetData = needCached ? await getFileBytes('${_identifier}_${width}_$height') : null;

    if (assetData == null) {

      assetData = await AssetPicker.requestImageThumbnail(
          _identifier, needCached, width, height, quality,mediaType == 1,fileId);
      if (assetData == null || assetData.lengthInBytes == 0) {
        return null;
      }
    }
    return assetData;
  }

  /// Requests the original image for that asset.
  ///
  /// You can also pass the optional parameter [quality] to reduce the quality
  /// and the size of the returned image if needed. The value should be between
  /// 0 and 100. By default it set to 100 (max quality).
  ///
  /// The method returns a Future with the [ByteData] for the image,
  /// as well as storing it in the _imageData property which can be requested
  /// later again, without need to call this method again.
  Future<Uint8List?> getImageByteData({int quality = 70,int? maxWidth,int? maxHeight,bool ignoreEditInfo = false})
  async {
    if (quality < 0 || quality > 100) {
      throw ArgumentError.value(
          quality, 'quality should be in range 0-100');
    }

    if(!ignoreEditInfo){
      if(editInfo != null){
        final file = File(editInfo!['path']);
        final bytes = await file.readAsBytes();
        return bytes;
      }
    }

    if(mediaType == 0 && maxWidth == null && maxHeight == null && Platform.isAndroid && quality == 100){
      return File(_identifier).readAsBytes();
    }

    final bytes = await AssetPicker.requestImageOriginal(_identifier,quality: quality, maxWidth: maxWidth, maxHeight: maxHeight,isVideo: mediaType == 1,fileId: fileId);
    return bytes;
  }

}

///A representation of a Photos asset grouping, such as a moment,
/// user-created album, or smart album.

class AssetCollection
{
  String? identifier;

  /// The resource file name
  String name;

  /// Original image width
  int count;

  Asset? lastAsset; //最后一张图

  List<Asset>? children; //android 专用

  AssetCollection(
      this.identifier,
      this.name,
      this.count,
      [this.lastAsset,this.children]
      );
}
