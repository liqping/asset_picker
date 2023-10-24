# asset_picker

Language: [English](README.md) | 中文

用于选择系统图库照片、音频、视频的插件，支持ios和android.

## 特性
- 支持照片、音频、视频的选择
- 支持图片预览、编辑(马赛克, 旋转，缩放，涂鸦，文本)
- 支持横竖屏切换

## 功能演示

| ![Screenrecorder-2023-10-19-16-18-06-866 00_00_00-00_00_30](https://github.com/liqping/asset_picker/assets/62126718/a944f594-6e59-479a-a8e4-22e3c6283982) | ![Screenrecorder-2023-10-19-16-16-24-275 00_00_00-00_00_30](https://github.com/liqping/asset_picker/assets/62126718/36e644ab-eb83-4cd0-bf85-1242f5dc4d82) | ![Screenrecorder-2023-10-19-16-04-41-859 00_00_00-00_00_30](https://github.com/liqping/asset_picker/assets/62126718/ea1dec20-acf0-4120-bcdc-2f995db6b953) |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| ![Screenrecorder-2023-10-19-16-03-20-199 00_00_00-00_00_30](https://github.com/liqping/asset_picker/assets/62126718/968f419f-c47b-4a15-9b1c-51d6ccc32d78) | ![Screenrecorder-2023-10-19-16-01-38-311 00_00_00-00_00_30](https://github.com/liqping/asset_picker/assets/62126718/5d7d5ff0-9f40-4ec6-bfc7-c3249f3889b4) |


## 使用方法
- class
  ```dart
    Asset: ///媒体类
      /// 属性：
      /// identifier: android表示地址, 对于ios 表示图片标识符
      /// mediaType: 媒体类型 0 image 1 video 2 audio
      /// duration: video or audio duration seconds
      /// mediaUrl: video or audio 本地路径
      /// editInfo: 编辑信息,
      /// ration: 媒体宽高比
      /// originalWidth: 媒体原始宽度
      /// originalHeight: 媒体原始高度

      ///方法：
        ///根据宽高获取原始图片数据
        /// quality: jpg 图片压缩率
        /// maxWidth: 图片最大宽度(px)
        /// maxHeight: 图片最大高度(px)
        /// if maxWidth == null && maxHeight == null , will get original image
        Future<Uint8List?> getImageByteData({int quality = 70,int? maxWidth,int? maxHeight,bool ignoreEditInfo = false});

        ///根据宽高获取缩略图数据
        /// quality: jpg 图片压缩率
        /// needCached: 是否磁盘缓存此缩略图
        /// width: 图片宽度(px)
        /// height: 图片高度(px)
        /// if maxWidth == null && maxHeight == null , will get original image
        Future<Uint8List?> getImageThumbByteData(int width, int height, {int quality = 100,bool needCached = false});
  
  ```
- widgets
  ```dart
   ///缩略图控件
   /// asset: Asset对象
   /// width: 图片宽度（px）
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
  
  ///原始图控件
  /// picSizeWidth: 加载过程中展示缩略图的宽度(px)
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

- 选取图片
  ```dart
   ///maxNumber: 本次选取媒体的最大数量
   ///isCupertinoType: ios风格
   ///scrollReverse: 滚动到底部
   ///dropDownBannerMode: true 通过顶部的banner选择相册类型  false 单独页面显示所有相册列表
   ///type: 可选择媒体类型
   ///photoDidSelectCallBack:选取后的回调
    
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
- 管理缓存
  ```dart
  ///获取缓存大小(byte)
  Future<double> getAssetPickCacheSize();

  ///清空缓存(不建议,清理后选择图片将会重新生成)
  Future cleanAssetPickCache() async;
  ```

