import 'dart:async';
import 'dart:io';
import 'dart:math';


import 'package:flutter/services.dart';
import 'package:asset_picker/asset_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'asset_collection_cell.dart';
import 'asset_cupertino_page_route.dart';

typedef AssetPickedCallback = void Function(List<Asset>);


enum AssetPickerType {
  picture,
  video,
  audio,
  pictureAndVideo,
  all
}

Future cleanAssetPickCache() async {
  Directory dir = await getApplicationDocumentsDirectory();
  Directory cachePath = Directory("${dir.path}/pickasset/imagecache/");
  if (cachePath.existsSync()) {
    await File(cachePath.path).delete(recursive: true);
  }
}

Future<double> _getTotalSizeOfFilesInDir(final FileSystemEntity file) async {
  if (file is File) {
    int length = await file.length();
    return double.parse(length.toString());
  }
  if (file is Directory) {
    try {
      final List<FileSystemEntity> children = file.listSync();
      double total = 0;
      for (final FileSystemEntity child in children){
        total += await _getTotalSizeOfFilesInDir(child);
      }
      return total;
    } catch (e) {
      // ignored, really.
    }
  }
  return 0;
}

Future<double> getAssetPickCacheSize() async
{
  double size = 0;
  Directory dir = await getApplicationDocumentsDirectory();
  Directory cachePath = Directory("${dir.path}/pickasset/imagecache/");
  if (cachePath.existsSync()) {
    size = await _getTotalSizeOfFilesInDir(cachePath);
  }
  return size;
}


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
}) {
  final navigator = Navigator.of(context,rootNavigator: true);
  if(dropDownBannerMode){
   return navigator.push(CupertinoPageRoute(
       fullscreenDialog: true,
       builder: (ctx) {
         final page = DropDownBannerPage(
           isCupertinoType: isCupertinoType,
           scrollReverse: scrollReverse,
           maxNumber: maxNumber,
           type: type,
           photoDidSelectCallBack: photoDidSelectCallBack,
         );
         final queryData = MediaQuery.of(ctx);
         return  MediaQuery(
           data: MediaQuery.of(context).copyWith(padding: queryData.padding,viewInsets: queryData.viewInsets,viewPadding: queryData.viewPadding),
           child: Material(
             child: page,
           ),
         );
       }));
  }else{
    final notifier = ValueNotifier<List<AssetCollection>?>(null);
    PageRoute pageRoute = CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (ctx) {
          final page = NavigationMainPage(
            isCupertinoType: isCupertinoType,
            scrollReverse: scrollReverse,
            notifier: notifier,
            maxNumber: maxNumber,
            type: type,
            photoDidSelectCallBack: photoDidSelectCallBack,
          );
          final queryData = MediaQuery.of(ctx);
          return  MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: queryData.padding,viewInsets: queryData.viewInsets,viewPadding: queryData.viewPadding),
            child: Material(
              child: page,
            ),
          );
        });
    final popFuture = navigator.push(pageRoute);
    navigator.push(AssetCupertinoPageRoute(
      context: context,
      widgetBuilder: (_,route){
        return  PickerMainPage(
          isCupertinoType:isCupertinoType,
          assetsCatalogChanged: notifier,
          myRoute: route,
          scrollReverse: scrollReverse,
          maxNumber: maxNumber,
          type: type,
          photoDidSelectCallBack: photoDidSelectCallBack,
        );
      },
      beginSlider: false,
    )
    );
    popFuture.then((_){
      //dart < 3.0
      if( Platform.version.substring(0,2).replaceAll('.', '').compareTo('3') < 0 &&  isCupertinoType  && Platform.isAndroid ){
        Future.delayed(const Duration(milliseconds: 350),()=>SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle
          (statusBarColor: Colors.transparent,systemNavigationBarColor:Colors.transparent,systemNavigationBarDividerColor: Colors.transparent)));
      }

      //清理图片缓存
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.clear();
      });
    });
    return popFuture;
  }

}

class NavigationMainPage extends StatefulWidget {
  final AssetPickedCallback? photoDidSelectCallBack;
  final int maxNumber;
  final bool isCupertinoType;

  ///show last asset on gridView bottom
  final bool scrollReverse;

  final ValueNotifier<List<AssetCollection>?> notifier;
  final AssetPickerType? type; //0 图片 1 视频 2 音频 -1 所有的
  const NavigationMainPage({super.key,
    required this.notifier,
    required this.scrollReverse,
    this.maxNumber = 9,
    this.type = AssetPickerType.picture,
    this.photoDidSelectCallBack,
    required this.isCupertinoType
  });

  @override
  State<StatefulWidget> createState() {
    return _NavigationMainPage();
  }
}

class _NavigationMainPage extends State<NavigationMainPage> {
  List<AssetCollection> _collectionList = [];

  bool _request = true;

  void requestAssetCollection() async {
    try {
      int assetType = widget.type!.index;
      if(widget.type == AssetPickerType.all)
      {
        assetType = -1;
      }
      var list = await AssetPicker.getAllAssetCatalog(!widget.scrollReverse,assetType);
      if(!mounted){
        return;
      }
      setState(() {
        _request = false;
        _collectionList = list;
      });
      widget.notifier.value = _collectionList;
    } on PlatformException catch (e) {
      if(mounted) {
        setState(() {
          _request = false;
        });
        AssetToast.show(e.message, context, gravity: AssetToast.CENTER, backgroundRadius: 8);
      }
    }
    catch (e)
    {
      if(mounted) {
        setState(() {
          _request = false;
        });
        AssetToast.show(e.toString(), context, gravity: AssetToast.CENTER);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    requestAssetCollection();
  }

  @override
  Widget build(BuildContext context) {
    if(_request){
      return const Center(child: CupertinoActivityIndicator(),);
    }
    final query = MediaQuery.of(context);
    final double dWidth = query.size.width * query.devicePixelRatio;
    final picSizeWidth1 = (query.devicePixelRatio * 66).toInt();
    final int picSizeWidth = dWidth ~/ (query.orientation == Orientation.landscape ? 5 :3.2);
    final child = ListView.separated(
      itemBuilder: (BuildContext context, int index) {
        final collection = _collectionList[index];
        final Widget iconWidget = collection.lastAsset != null ? AssetThumbImage(
          width:  collection.lastAsset != null ? picSizeWidth : picSizeWidth1,
          needCache: true,
          asset: collection.lastAsset!,
        ) : Icon(
          Icons.insert_photo,
          size: 66,
          color: CupertinoColors.systemGrey4.resolveFrom(context),
        );
        return AssetCollectionCell(
          title: collection.name,
          icon: iconWidget,
          count: collection.count,
          callback: () {
            Navigator.of(this.context).push(
                AssetCupertinoPageRoute(
                    context: this.context,
                    widgetBuilder: (_,route){
                      return PickerMainPage(
                        assetCollection: collection,
                        isCupertinoType: widget.isCupertinoType,
                        scrollReverse: widget.scrollReverse,
                        maxNumber: widget.maxNumber,
                        myRoute: route,
                        type: widget.type,
                        photoDidSelectCallBack: widget.photoDidSelectCallBack,
                      );
                    }
                )
            );
          },
        );
      },
      itemCount: _collectionList.length,
      separatorBuilder: (BuildContext context, int index) {
        return Divider(
          color: const CupertinoDynamicColor.withBrightness(color: Color(0xFFE5E5E5), darkColor: Color(0xFFA0A0A0)).resolveFrom(context),
          height: 0,
          thickness: 0,
        );
      },
    );
    return widget.isCupertinoType ? CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(widget.type == AssetPickerType.all || widget.type == AssetPickerType.pictureAndVideo ?
          '媒体':widget.type == AssetPickerType.video ? '视频' :widget.type == AssetPickerType.audio ? '音频':'照片'),
          automaticallyImplyLeading: false,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            // minSize: 30,
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
        ),
        child: Platform.version.substring(0,2).replaceAll('.', '').compareTo('3') < 0 ?
        AnnotatedRegion(
            value: const SystemUiOverlayStyle(
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
            ),child: child) : child
    ) : Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.type == AssetPickerType.all || widget.type == AssetPickerType.pictureAndVideo ? '媒体':widget.type == AssetPickerType.video ? '视频' :widget.type == AssetPickerType.audio ? '音频':'照片'),
        actions: [
          Builder(
              builder: (context) {
                return TextButton(
                  child: Text('取消',style: DefaultTextStyle.of(context).style.copyWith(fontSize: 17),),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                );
              }
          )
        ],
      ),
      body: child,
    );
  }
}


class _InnerNotifier extends ChangeNotifier{
  @override
  void notifyListeners() {
    super.notifyListeners();
  }
}

class DropDownBannerPage extends StatefulWidget{
  final AssetPickedCallback? photoDidSelectCallBack;
  final int maxNumber;
  final bool isCupertinoType;

  ///show last asset on gridView bottom
  final bool scrollReverse;
  final AssetPickerType? type; //0 图片 1 视频 2 音频 -1 所有的


  const DropDownBannerPage({
    super.key,
    required this.scrollReverse,
    this.maxNumber = 9,
    this.type = AssetPickerType.picture,
    this.photoDidSelectCallBack,
    required this.isCupertinoType
  });

  @override
  State<StatefulWidget> createState() {
   return _DropDownBannerPage();
  }
}

class _DropDownBannerPage extends State<DropDownBannerPage>{

  List<AssetCollection>? _collectionList;

  bool _request = true;
  bool _expand = false;
  final _closeNotifier = _InnerNotifier();
  bool _showCollectionList = false;

  int _collectionIndex = -1;


  void requestAssetCollection() async {
    try {
      int assetType = widget.type!.index;
      if(widget.type == AssetPickerType.all)
      {
        assetType = -1;
      }
      final list = await AssetPicker.getAllAssetCatalog(!widget.scrollReverse,assetType);
      if(!mounted){
        return;
      }
      setState(() {
        _request = false;
        _collectionList = list;
        if(list.isNotEmpty){
          _collectionIndex = 0;
        }
      });
    } on PlatformException catch (e) {
      if(mounted) {
        setState(()=>_request = false);
        AssetToast.show(e.message, context, gravity: AssetToast.CENTER, backgroundRadius: 8);
      }
    }
    catch (e)
    {
      if(mounted) {
        setState(() {
          _request = false;
        });
        AssetToast.show(e.toString(), context, gravity: AssetToast.CENTER);
      }
    }
  }

  void expandChanged(){

    if(!_expand){
      setState(() {
        _showCollectionList = true;
      });
    }else{
      _closeNotifier.notifyListeners();
    }
    setState(() {
      _expand = !_expand;
    });

  }


  Widget placeHoldBanner() => Container(
    width: 100,
    padding: const EdgeInsets.only(left:10,right: 6), height: 32,
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.6),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Expanded(child: Text( '  ',style: TextStyle(fontSize: 15,color: Colors.white))),
        AnimatedContainer(width: 20,height: 20,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10)
          ),
          duration: const Duration(milliseconds: 250),
          transformAlignment: Alignment.center,
          transform: Transform.rotate(angle: _expand ? pi : 0).transform,
          child: Icon(Icons.keyboard_arrow_down,size: 20,color: Colors.grey[800],),
        )
      ],
    ),
  );

  @override
  void initState() {
    super.initState();
    requestAssetCollection();
  }

  @override
  Widget build(BuildContext context) {

    final queryData = MediaQuery.of(context);

    final screenWidth = queryData.size.width;
    final child = _request ? const Center(child: CupertinoActivityIndicator(),) : _collectionIndex < 0 ? const SizedBox() : Stack(
      fit: StackFit.expand,
      children: [
        PickerMainPage(
          assetCollection: _collectionList![_collectionIndex],
          isCupertinoType: widget.isCupertinoType,
          scrollReverse: widget.scrollReverse,
          maxNumber: widget.maxNumber,
          fromDropMode: true,
          type: widget.type,
          photoDidSelectCallBack: widget.photoDidSelectCallBack,
        ),
        const Positioned(top: 0,left: 0,right: 0,height: 80,child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x83000000),Color(0x00000000),]
                )
            ),
          ),
        )),
        if(_showCollectionList) GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: (){
              setState(() {
                _expand = !_expand;
              });
              _closeNotifier.notifyListeners();
            },
            child: Container(
              color: _expand ? const CupertinoDynamicColor.withBrightness(color: Color(0xBA000000), darkColor: Color(0xBA222222)).resolveFrom(context) : Colors.transparent,
              child: LayoutBuilder(
                builder: (context,sizeConstraint) {
                  double totalHeight = _collectionList!.length * 67.0;
                  return _CollectionListWidget(notifier: _closeNotifier,index: _collectionIndex,collection: _collectionList!,
                    height: totalHeight > sizeConstraint.maxHeight - 80 ? sizeConstraint.maxHeight - 80 : totalHeight,
                    indexChangeCallback: (index){
                      setState(() {
                        _expand = false;
                        _collectionIndex = index;
                      });
                    },
                    dismissCallback:()=>setState(() {
                      if(mounted) {
                        _showCollectionList = false;
                      }
                    }),);
                }
              ),
            )
        ),
      ],
    );

   final width = TextPainter.computeWidth(text: TextSpan(text: _collectionIndex < 0 ? '  ' : _collectionList![_collectionIndex].name,style: const TextStyle(fontSize: 15,),),textScaleFactor: queryData.textScaleFactor, textDirection: TextDirection.ltr);

   final banner = _collectionList == null ? placeHoldBanner() :  GestureDetector(
     behavior: HitTestBehavior.opaque,
     onTap: _collectionList!.isEmpty ? null : ()=> expandChanged(),
     child: AnimatedContainer(
       width: min(screenWidth - 130,width.ceilToDouble() + 43),
       padding: const EdgeInsets.only(left:10,right: 6),
       height: 32,
       decoration: BoxDecoration(
         color: Colors.black.withOpacity(0.6),
         borderRadius: BorderRadius.circular(16),
       ),
       duration: const Duration(milliseconds: 250),
       child: Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           Expanded(child: Text( _collectionIndex < 0 ? '  ' : _collectionList![_collectionIndex].name,style: const TextStyle(fontSize: 15,color: Colors.white),textScaleFactor: queryData.textScaleFactor,maxLines: 1,overflow: TextOverflow.clip,)),
           AnimatedContainer(width: 20,height: 20,
             decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(10)
             ),
             duration: const Duration(milliseconds: 250),
             transformAlignment: Alignment.center,
             transform: Transform.rotate(angle: _expand ? pi : 0).transform,
             child: Icon(Icons.keyboard_arrow_down,size: 20,color: Colors.grey[800],),
           )
         ],
       ),
     ),
   );

    return widget.isCupertinoType ? CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          padding: const EdgeInsetsDirectional.only(start: 6),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Icon(Icons.close),
          ),
          middle: banner,
        ),
        child: SafeArea(bottom: false,child: child)):
    Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: banner,
      ),
      body: child,
    );
  }

  @override
  void dispose() {
    _closeNotifier.dispose();
    super.dispose();
  }
}

class _CollectionListWidget extends StatefulWidget{

  final List<AssetCollection> collection;
  final double height;
  final VoidCallback dismissCallback;
  final ValueChanged<int> indexChangeCallback;
  final int index;
  final _InnerNotifier notifier;
  const _CollectionListWidget({required this.dismissCallback,required this.indexChangeCallback,required this.index,required this.notifier ,required this.collection, required this.height});

  @override
  State<StatefulWidget> createState() {
    return _CollectionListState();
  }

}
class _CollectionListState extends State<_CollectionListWidget>{

  bool _animated = false;

  void dismiss(){
    if(mounted){
      setState(() {
        _animated = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _CollectionListWidget oldWidget) {
    if(oldWidget.notifier != widget.notifier){
      oldWidget.notifier.removeListener(dismiss);
      widget.notifier.addListener(dismiss);
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(dismiss);
    super.dispose();
  }

  @override
  void initState() {
    widget.notifier.addListener(dismiss);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted){
        setState(() {
          _animated = true;
        });
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    final query = MediaQuery.of(context);
    final double dWidth = query.size.width * query.devicePixelRatio;
    final picSizeWidth1 = (query.devicePixelRatio * 66).toInt();
    final int picSizeWidth = dWidth ~/ (query.orientation == Orientation.landscape ? 5 :3.2);

    return Stack(
      children: [
        AnimatedPositioned(
          top: _animated ? 0 : -widget.height,
          left: 0,
          right: 0,
          curve: Curves.easeInOut,
          onEnd: (){
            if(!_animated){
              widget.dismissCallback();
            }
          },
          duration: const Duration(milliseconds: 250),
          child: Container(
            color: Colors.white,
            height: widget.height,
            child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: widget.collection.length,
                itemExtent: 67,
                itemBuilder: (ctx,index){
                  final collection = widget.collection[index];
                  final Widget iconWidget = collection.lastAsset != null ? AssetThumbImage(
                    width:  collection.lastAsset != null ? picSizeWidth : picSizeWidth1,
                    needCache: true,
                    asset: collection.lastAsset!,
                  ) : Icon(
                    Icons.insert_photo,
                    size: 66,
                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                  );
                  return Column(
                    children: [
                      Expanded(child: AssetCollectionDropCell(
                        title: collection.name,
                        icon: iconWidget,
                        selected: widget.index == index,
                        count: collection.count,
                        callback: (){
                          setState(() {
                            _animated = false;
                          });

                          widget.indexChangeCallback(index);
                        },
                      )),
                      Divider(height: 1,color: Colors.grey[200],thickness: 1,)
                    ],
                  );
                }
            ),
          ),
        ),
      ],
    );
  }

}
