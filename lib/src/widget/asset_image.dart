
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';


import '../../asset_picker.dart';

class AssetThumbImage extends StatelessWidget{
  /// The asset we want to show thumb for.
  final Asset asset;

  /// The thumb width
  final int width;

  /// The thumb quality
  final int quality;

  final Color? backgroundColor;
  final BoxFit? boxFit;
  /// This is the widget that will be displayed while the
  /// thumb is loading.
  final Widget? spinner;
  final int? index;

  /// cache the image to disk
  final bool needCache;

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

  @override
  Widget build(BuildContext context) {
    if(asset.mediaType == 2){
      return Container(
        color: Colors.grey[350],
        child: const Icon(Icons.music_video_rounded,size: 40,color: Colors.white,),
      );
    }
    int picSizeHeight = (asset.originalWidth == 0 ? width : min(width, asset.originalWidth) * asset.ration).toInt();
    int picSizeWidth = asset.originalWidth == 0 ? width : width < asset.originalWidth ? width : asset.originalWidth;
    return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: backgroundColor ?? const CupertinoDynamicColor.withBrightness(color: Color(0xFFF0F2F5), darkColor: Color(0xFF0F0D0C)).resolveFrom(context),),
          Image(
            image: AssetThumbImageProvider(
              asset,
              needCache,
              width: picSizeWidth,
              height: picSizeHeight,
              quality: quality,
            ),
            gaplessPlayback:true,
            color: kIsWeb
                ? null
                : const CupertinoDynamicColor.withBrightness(
                color: Color(0xFFFFFFFF),
                darkColor: Color(0xFFB0B0B0))
                .resolveFrom(context),
            fit:boxFit,
            colorBlendMode: BlendMode.modulate,
          )
        ]
    );

  }
}

@immutable
class AssetThumbImageProvider extends ImageProvider<AssetThumbImageProvider>{

  /// The asset we want to show thumb for.
  final Asset asset;

  /// The thumb width
  final int width;

  /// The thumb height
  final int height;

  final Map? editInfo;

  /// The thumb quality
  final int quality;

  final bool needCache;

  AssetThumbImageProvider(this.asset, this.needCache,{ required this.width, required this.height,required this.quality, this.scale = 1.0 }):editInfo = asset.editInfo;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  @override
  Future<AssetThumbImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AssetThumbImageProvider>(this);
  }

  @override
  @protected
  ImageStreamCompleter loadImage(AssetThumbImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.asset.identifier,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<AssetThumbImageProvider>('Image key', key),
      ],
    );
  }

  // @override
  // ImageStreamCompleter loadBuffer(AssetThumbImageProvider key, DecoderBufferCallback decode) {
  //
  //   return MultiFrameImageStreamCompleter(
  //     codec: _loadAsync(key, decode),
  //     scale: key.scale,
  //     debugLabel: key.asset.identifier,
  //     informationCollector: () => <DiagnosticsNode>[
  //       DiagnosticsProperty<ImageProvider>('Image provider', this),
  //       DiagnosticsProperty<AssetThumbImageProvider>('Image key', key),
  //     ],
  //   );
  // }

  Future<ui.Codec> _loadAsync(
      AssetThumbImageProvider key,
      ImageDecoderCallback decode) async{
    assert(key == this);
    try{
      final thumbData = await asset.getImageThumbByteData(
          width,
          height,
          quality: quality,
          needCached: needCache
      );
      if(thumbData == null || thumbData.isEmpty) {
        throw Exception('AssetThumbImage is an empty file: ${asset.identifier}');
      }
      return decode(await ui.ImmutableBuffer.fromUint8List(thumbData));
    }
    catch (e){
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is AssetThumbImageProvider
        && other.asset == asset
        && other.width == width
        && other.height == height
        && other.quality == quality
        && other.needCache == needCache
        && other.asset.identifier == asset.identifier
        && mapEquals(other.editInfo, editInfo)
        && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(asset.identifier,width,height,quality,editInfo, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'AssetThumbImageProvider')}("${asset.identifier}", scale: $scale)';

}

@immutable
class AssetOriginalImageProvider extends ImageProvider<AssetOriginalImageProvider>{

  /// The asset we want to show thumb for.
  final Asset asset;

  /// The thumb width
  final int maxWidth;

  /// The thumb height
  final int maxHeight;

  final Map? editInfo;

  /// The thumb quality
  final int quality;


  AssetOriginalImageProvider(this.asset, { required this.maxWidth, required this.maxHeight,required this.quality, this.scale = 1.0 }):editInfo = asset.editInfo;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  @override
  Future<AssetOriginalImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AssetOriginalImageProvider>(this);
  }

  @override
  @protected
  ImageStreamCompleter loadImage(AssetOriginalImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.asset.identifier,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<AssetOriginalImageProvider>('Image key', key),
      ],
    );
  }



  // @override
  // ImageStreamCompleter loadBuffer(AssetOriginalImageProvider key, DecoderBufferCallback decode) {
  //   return MultiFrameImageStreamCompleter(
  //     codec: _loadAsync(key, decode),
  //     scale: key.scale,
  //     debugLabel: key.asset.identifier,
  //     informationCollector: () => <DiagnosticsNode>[
  //       DiagnosticsProperty<ImageProvider>('Image provider', this),
  //       DiagnosticsProperty<AssetOriginalImageProvider>('Image key', key),
  //     ],
  //   );
  // }

  Future<ui.Codec> _loadAsync(
      AssetOriginalImageProvider key,
      ImageDecoderCallback decode) async{
    assert(key == this);
    try{
      final byteData = await asset.getImageByteData(quality: quality,maxWidth: maxWidth,maxHeight: maxHeight);

      if(byteData == null || byteData.isEmpty) {
        throw Exception('AssetOriginalImage is an empty file: ${asset.identifier}');
      }
      return decode(await ui.ImmutableBuffer.fromUint8List(byteData));
    }
    catch (e){
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is AssetOriginalImageProvider
        && other.asset == asset
        && other.maxWidth == maxWidth
        && other.maxHeight == maxHeight
        && other.quality == quality
        && other.asset.identifier == asset.identifier
        && mapEquals(other.editInfo, editInfo)
        && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(asset.identifier,maxWidth,maxHeight,quality,editInfo, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'AssetOriginalImageProvider')}("${asset.identifier}", scale: $scale)';

}
class AssetOriginalImage extends StatefulWidget {
  /// The asset we want to show original for.
  final Asset asset;

  /// The original quality
  final int quality;
  final BoxFit fit;
  final int maxWidth;
  final int maxHeight;


  /// This is the widget that will be displayed while the
  /// original is loading.
  final Widget? spinner;
  final int picSizeWidth;

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


  @override
  State createState() => _AssetOriginalImageState();

}
class _AssetOriginalImageState extends State<AssetOriginalImage>{

  bool _loadFinish = false;

  bool _showSpin = true;

  @override
  Widget build(BuildContext context) {
    if(widget.asset.mediaType == 2){
      return Container(
        color: Colors.grey[350],
        child: const Icon(Icons.music_note_outlined,size: 250,color: Colors.white,),
      );
    }
    int picSizeHeight = (widget.picSizeWidth * widget.asset.ration).toInt();
    return Stack(
      fit: StackFit.expand,
      children: [
        if(!_loadFinish) Image(image: AssetThumbImageProvider(
            widget.asset,
            false,
            width: widget.picSizeWidth,
            height: picSizeHeight,
            quality: widget.quality,
        ),
          gaplessPlayback:true,
          frameBuilder: widget.spinner != null ? (_,Widget child,int? frame,__, ){
            if(mounted && frame != null){
              scheduleMicrotask(()=>setState(() {
                _showSpin = false;
              }));
            }
            return child;
          } :null,
          fit: widget.fit,
          color: kIsWeb ? null : const CupertinoDynamicColor.withBrightness(color: Color(0xFFFFFFFF), darkColor: Color(0xFFB0B0B0)).resolveFrom(context),
          colorBlendMode: BlendMode.modulate,
        ),
        Image(image: AssetOriginalImageProvider(
          widget.asset,
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
          quality: widget.quality,
        ),
          gaplessPlayback:true,
          fit: widget.fit,
          frameBuilder: (_,Widget child,int? frame,__,
          ){
            if(mounted && frame != null){
              scheduleMicrotask(()=>setState(() {
                _loadFinish = true;
                _showSpin = false;
              }));
            }
            return child;
          },
          color: kIsWeb ? null : const CupertinoDynamicColor.withBrightness(color: Color(0xFFFFFFFF), darkColor: Color(0xFFB0B0B0)).resolveFrom(context),
          colorBlendMode: BlendMode.modulate,
        ),
        if(widget.spinner != null && _showSpin) widget.spinner!
      ],
    );

  }

}


