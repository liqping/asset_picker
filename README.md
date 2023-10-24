# asset_picker

Language: English | [中文](README-ZH.md)

A plug to select images also with videos and audios from photo albums,support ios and android platform.

## Features
- Image support
- Video support
- Audio support
- Support preview and edit image(mosaic, rotate，scale，scrawl，add text)
- Support screen rotate

## demo

| ![Screenrecorder-2023-10-19-16-18-06-866 00_00_00-00_00_30](https://github.com/liqping/asset_picker/assets/62126718/a944f594-6e59-479a-a8e4-22e3c6283982) | ![Screenrecorder-2023-10-19-16-16-24-275 00_00_00-00_00_30](https://github.com/liqping/asset_picker/assets/62126718/36e644ab-eb83-4cd0-bf85-1242f5dc4d82) | ![Screenrecorder-2023-10-19-16-04-41-859 00_00_00-00_00_30](https://github.com/liqping/asset_picker/assets/62126718/ea1dec20-acf0-4120-bcdc-2f995db6b953) |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| ![Screenrecorder-2023-10-19-16-03-20-199 00_00_00-00_00_30](https://github.com/liqping/asset_picker/assets/62126718/968f419f-c47b-4a15-9b1c-51d6ccc32d78) | ![Screenrecorder-2023-10-19-16-01-38-311 00_00_00-00_00_30](https://github.com/liqping/asset_picker/assets/62126718/5d7d5ff0-9f40-4ec6-bfc7-c3249f3889b4) |


## using
- class
  ```dart
    Asset: ///media class
      /// Attribute：
      /// identifier: The file path of media for android ; The identifier of media for ios
      /// mediaType: Asset type - 0 image 1 video 2 audio
      /// duration: video or audio duration seconds
      /// mediaUrl: The local path for video or audio 
      /// editInfo: editing info,
      /// ration: The aspect ratio of media
      /// originalWidth: The original width of media
      /// originalHeight: The original height of media

      ///Method：
        /// Get image byte data
        /// quality: Jpg quality
        /// maxWidth: The max width of image to need.(px)
        /// maxHeight: The max height of image to need.(px)
        /// if maxWidth == null && maxHeight == null , will get original image
        Future<Uint8List?> getImageByteData({int quality = 70,int? maxWidth,int? maxHeight,bool ignoreEditInfo = false});

        ///Get image byte data by width and height
        /// quality: Jpg quality
        /// needCached: Need cache the thumb image to disk
        /// width: Image width (px)
        /// height: Image height (px)
        /// if maxWidth == null && maxHeight == null , will get original image
        Future<Uint8List?> getImageThumbByteData(int width, int height, {int quality = 100,bool needCached = false});
  
  ```
- widgets
  ```dart
   /// A thumb asset widget
   /// asset: Asset object
   /// width: The max width of image to need.(px)
   const AssetThumbImage({
    Key? key,
    required this.asset,
    required this.width,
    this.needCache = false,
    this.index,
    this.quality = 70,
    this.boxFit = BoxFit.cover,
    this.spinner,
    this.backgroundColor,
  }) : super(key: key);
  
  ///A original asset widget
  /// picSizeWidth: The thumb image width when Loading big image(px)
   const AssetOriginalImage({
    Key? key,
    required this.asset,
    this.quality = 70,
    this.picSizeWidth = 600,
    this.fit = BoxFit.fill,
    int? maxWidth,
    int? maxHeight,
    this.spinner,
  }) : maxWidth= maxWidth ?? 2500,maxHeight = maxHeight ?? 2500, super(key: key);
  ```

- Choose assets
  ```dart
   ///maxNumber: The max count to choose
   ///isCupertinoType: true use CupertinoPageScaffold else Scaffold
   ///scrollReverse: show last asset on gridView bottom
   ///dropDownBannerMode: true select Asset Collection list with dropdown banner , else Asset Collection list show in another page
   ///type: media type to choose
   ///photoDidSelectCallBack: The callback for result.
    
   Future showAssetPickNavigationDialog<T>({
      required BuildContext context,
      int maxNumber = 8,
      bool isCupertinoType = false,
      ///show last asset on gridView bottom
      bool scrollReverse = true,

      ///select Asset Collection with dropdown banner else with another list
      bool dropDownBannerMode = true,
      AssetPickerType type = AssetPickerType.picture,
      AssetPickedCallback? photoDidSelectCallBack
  });
  ```
- Cache control
  ```dart
  ///Get asset disk cache size(byte)
  Future<double> getAssetPickCacheSize();

  ///Clean Caches(Not recommended,re-cached when next choose )
  Future cleanAssetPickCache() async;
  ```
