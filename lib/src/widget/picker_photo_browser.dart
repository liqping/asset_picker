
import 'dart:math';
import 'dart:ui';
import 'dart:io';

import 'package:asset_picker/src/widget/asset_cupertino_page_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../asset_picker.dart';
import 'package:asset_photo_view/photo_view.dart';
import 'package:asset_photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';

import 'asset_video_player_scaffold.dart';

class GalleryPhotoViewWrapper extends StatefulWidget{
  const GalleryPhotoViewWrapper({super.key,
    this.imageEditCallback,
    required this.isCupertinoType,
    required this.fromDropMode,
    this.pageRoute,
    this.loadingBuilder,
    this.backgroundDecoration,
    this.minScale,
    this.maxScale,
    this.initialIndex = 0,
    this.picMaxWidth,
    this.picMaxHeight,
    required this.maxNumber,
    this.photoDidSelectCallBack,
    this.parentPageRoute,  //上级页面，退出时需要通知上级页面退出
    this.isFromPreview = false,
    required this.galleryItems,
    this.scrollDirection = Axis.horizontal,
  });

  final LoadingBuilder? loadingBuilder;
  final BoxDecoration? backgroundDecoration;
  final double? minScale;
  final double? maxScale;
  final int initialIndex;
  final int? picMaxWidth;
  final int? picMaxHeight;
  final AssetCupertinoPageRoute? parentPageRoute;
  final AssetCupertinoPageRoute? pageRoute;
  final List<Map<String,dynamic>>? galleryItems;
  final Axis scrollDirection;
  final int maxNumber;

  final AssetPickedCallback? photoDidSelectCallBack;
  final bool? isFromPreview;  //是否预览

  final VoidCallback? imageEditCallback;
  final bool isCupertinoType;
  final bool fromDropMode;

  @override
  State<StatefulWidget> createState() {
    return _GalleryPhotoViewWrapperState();
  }

}

class _AssetSelectItem
{
  final Map<String,dynamic> assetInfo;
  final int? index;  //选中的asset在原始数组中的序号
 _AssetSelectItem(this.assetInfo,this.index);
}


class _AssetSelectListModel extends ChangeNotifier
{
  List<_AssetSelectItem> _assetList = [];
  List<_AssetSelectItem> get assetList => _assetList;

  List<Map<String,dynamic>>? _allAssetList;

  int? currentIndex = 0;

  int? dragCurrentIndex = -1; //点击拖动控件的index

  int dragBelowIndex = -1; //拖动的控件经过下面的控件index;

  bool isEndDrag = true; //当结束拖动时不执行动画

  void updateCurrentIndex(int index){
    if(currentIndex != index){
        currentIndex = index;
        notifyListeners();
    }
  }

  void updateData(List<_AssetSelectItem> list){
    if(_assetList != list){
      _assetList = list;
    }
    notifyListeners();
  }

  void deleteDataWithIndex(int? index){
    for(final item in _assetList){
      if(item.index == index)
      {
        _assetList = _assetList.toList();
        _assetList.remove(item);
        notifyListeners();
        return;
      }
    }
  }


  void addDataObject(dynamic obj){
    _assetList = _assetList.toList();
    _assetList.add(obj);
    notifyListeners();
  }

  void addDataWithList(List<_AssetSelectItem> objList){
    if(objList.isNotEmpty){
      _assetList = _assetList.toList();
      _assetList.addAll(objList);
      notifyListeners();
    }
  }

  void updateModel(){
    notifyListeners();
  }

  void updateDragCurrentIndex(int index){
    if(dragCurrentIndex != index)
    {
      dragCurrentIndex = index;
      notifyListeners();
    }
  }

  void updateDragBelowIndex(int index){
    if(dragBelowIndex != index)
    {
      dragBelowIndex = index;
      notifyListeners();
    }
  }

  void updateEndDrag(bool endDragged){
    if(isEndDrag != endDragged)
    {
      isEndDrag = endDragged;
      notifyListeners();
    }
  }

}

class _GalleryPhotoViewWrapperState extends State<GalleryPhotoViewWrapper>
    with TickerProviderStateMixin{
  // double picWidth;


  //缩略图内存缓存
   final _thumbCache = <String,Uint8List?>{};

  final _AssetSelectListModel _assetListModel = _AssetSelectListModel();

  final _listController = ScrollController();


  bool _currentIndexChanged = false;  //判定是由于翻页引起的选择的序号的变化

  int? _initialSltIndex = -1; //下面的缩略图跳转到选中的初始化页

  ///点击banner消失

  AnimationController? controller;
  late Animation<Offset> animation;
  late Animation<Offset> animationTop;

  ///长按放大
  AnimationController? scaleController;
  late Animation<double> scaleAnimation;


  ///当拖动的控件是倒数第二个的时候，移动位置超过最后一个控件的尾部时，不需要移动
  ///dragMoveOffset 表示距离尾部的offsetX;
  double dragMoveOffset = -1;

  PageController? _pageController;

  final Set<int> _videoUrlLoadingIndexes = <int>{};

  @override
  void initState() {
    _assetListModel.currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex,keepPage:true);

    for(int i = 0;i<widget.galleryItems!.length;i++)
      {
        final item = widget.galleryItems![i];
        if(widget.isFromPreview! || (item.containsKey('selectIndex') && item['selectIndex'] != -1))
          {
            _assetListModel.assetList.add(_AssetSelectItem(item, i));
            if(!widget.isFromPreview! && i == widget.initialIndex && _initialSltIndex == -1)
              {
                _initialSltIndex = item['selectIndex'];
              }
          }
      }
    if(!widget.isFromPreview!) {
      _assetListModel.assetList.sort((obj1, obj2) =>
          obj1.assetInfo['selectIndex'].compareTo(
              obj2.assetInfo['selectIndex']));
    }
    _assetListModel._allAssetList = widget.galleryItems;
    controller = AnimationController(duration: const Duration(milliseconds: 200), vsync:this);
    animation = Tween(begin: Offset.zero, end: const Offset(0, 1)).animate(controller!);
    animationTop = Tween(begin: Offset.zero, end: const Offset(0, -1)).animate(controller!);

    scaleController = AnimationController(duration: const Duration(milliseconds: 150),vsync: this);
    scaleAnimation = Tween<double>(begin: 1.0,end: 1.2,).animate(scaleController!);

    if(_initialSltIndex != -1 && _initialSltIndex != 0) {
      Future.delayed(Duration.zero, ()=>listViewAnimationToIndex(_initialSltIndex));
    }

    super.initState();
    getVideoPathWithIndex(widget.initialIndex);
  }


  @override
  void dispose() {
    controller?.dispose();
    scaleController?.dispose();
    _listController.dispose();
    _pageController!.dispose();
    super.dispose();
  }

   ///选中按钮点击事件
   /// selectIndex : 当前操作的item选中序号
   /// index : 当前操作的item在预览图中的序号
   void didTapCheckBox(int? selectIndex,int index)
   {
     if(selectIndex == -1) {
       if (_assetListModel.assetList.length >= widget.maxNumber) {
         AssetToast.show('最多选择${widget.maxNumber}个照片',context,gravity: AssetToast.CENTER,backgroundRadius: 8);
         return;
       }
     }
     if (selectIndex == -1) {
       if(widget.isFromPreview!){  //预览只需要设置选中序号,并把后面的选中改变序号
         final data = _assetListModel._allAssetList![index];
         int thumbIndex = _assetListModel.assetList.indexWhere((element) => element.assetInfo == data);
         int? selIndex = -1;
         for(int i = 1;;i++){
           int beforeIndex = thumbIndex - i;
           int afterIndex = thumbIndex + i;
           if(beforeIndex < 0 && afterIndex >= _assetListModel.assetList.length){
             break;
           }
           if(beforeIndex >=0 && selIndex == -1){
             int? beforeModelIndex = _assetListModel.assetList[beforeIndex].assetInfo['selectIndex'];
             if(beforeModelIndex != -1){
               selIndex = beforeModelIndex! + 1;
             }
           }

           if(afterIndex < _assetListModel.assetList.length){
             int? afterModelIndex = _assetListModel.assetList[afterIndex].assetInfo['selectIndex'];
             if(afterModelIndex != -1)
             {
               _assetListModel.assetList[afterIndex].assetInfo['selectIndex'] = afterModelIndex! + 1;
               if(selIndex == -1) {
                 selIndex = afterModelIndex;
               }
             }
           }
         }
         data['selectIndex'] = selIndex == -1 ? 1 : selIndex;
         _assetListModel.updateModel();
       }
       else {

         _assetListModel.addDataObject(_AssetSelectItem(_assetListModel._allAssetList![index],index));

         final data = _assetListModel._allAssetList![index];
         data['selectIndex'] = _assetListModel.assetList.length;
         _assetListModel.updateModel();

         Future.delayed(const Duration(milliseconds: 20),() =>_listController.animateTo(_listController.position.maxScrollExtent,duration: const Duration(milliseconds: 150),curve: Curves.linear)
         );
       }
     } else {
       if(widget.isFromPreview!)
       {
         final data = _assetListModel._allAssetList![index];

         int thumbIndex = _assetListModel.assetList.indexWhere((element) => element.assetInfo == data);

         for(int i = thumbIndex + 1;i < _assetListModel.assetList.length;i++){
           int? afterModelIndex = _assetListModel.assetList[i].assetInfo['selectIndex'];
           if(afterModelIndex != -1)
           {
             _assetListModel.assetList[i].assetInfo['selectIndex'] = afterModelIndex! - 1;
           }
         }

         data['selectIndex'] = -1;
         _assetListModel.updateModel();
       }
       else{
         _assetListModel.deleteDataWithIndex(_assetListModel.currentIndex);

         for(final item in _assetListModel.assetList)
         {
           int itemIndex = item.assetInfo['selectIndex'];
           if(itemIndex > selectIndex!)
           {
             item.assetInfo['selectIndex'] = itemIndex - 1;
           }
         }

         final data = _assetListModel._allAssetList![index];
         data['selectIndex'] = -1;
         _assetListModel.updateModel();

       }
     }
   }

  ///拖动结束后需要重新排序缩略图

  void endDrag()
  {

    if (_assetListModel.dragCurrentIndex != -1 &&
        _assetListModel.dragBelowIndex != -1 &&
        _assetListModel.dragCurrentIndex !=
            _assetListModel.dragBelowIndex){ //reorder
      //重新排序
       final temp = _assetListModel._assetList.toList();
       final currentData = temp.removeAt(_assetListModel.dragCurrentIndex!);
       temp.insert(_assetListModel.dragBelowIndex, currentData);

       if(currentData.assetInfo['selectIndex'] != -1) {//未选中，则不操作修改选中序号
         int beginIndex = currentData.assetInfo['selectIndex'];
         //分开处理，若拖动的在后面，则逆向遍历
         if(_assetListModel.dragBelowIndex > _assetListModel.dragCurrentIndex!){ //正向遍历
           for (int i = _assetListModel.dragCurrentIndex!;i <= _assetListModel.dragBelowIndex; i++) {
             final item = temp[i];
             int? itemIndex = item.assetInfo['selectIndex'];
             if(itemIndex != -1) {
               item.assetInfo['selectIndex'] = beginIndex;
               beginIndex++;
             }
           }
         }
         else {
           int? beginIndex = currentData.assetInfo['selectIndex'];
           if(beginIndex != null) {
             for (int i = _assetListModel.dragCurrentIndex!; i >=
                 _assetListModel.dragBelowIndex; i--) {
               final item = temp[i];
               int itemIndex = item.assetInfo['selectIndex'];
               if (itemIndex != -1) {
                 item.assetInfo['selectIndex'] = beginIndex;
                 beginIndex = beginIndex!-1;
               }
             }
           }
         }
       }

      _assetListModel.isEndDrag = true;
      _assetListModel.dragBelowIndex = -1;
      _assetListModel.dragCurrentIndex = -1;
       _assetListModel.updateData(temp);

    } else if(_assetListModel.dragCurrentIndex != -1 || _assetListModel.dragBelowIndex != -1)
    {
      _assetListModel.isEndDrag = true;
      _assetListModel.dragBelowIndex = -1;
      _assetListModel.dragCurrentIndex = -1;
      _assetListModel.updateModel();
    }

  }

  void listViewAnimationToIndex(int? index)
  {
    RenderBox? box = context.findRenderObject() as RenderBox?;
    if(box != null)
    {
      double oriX = index!*58 + 38 - box.size.width*0.5;
      if(oriX < 0)
      {
        oriX = 0;
      }
      if(oriX > _listController.position.maxScrollExtent)
      {
        oriX = _listController.position.maxScrollExtent;
      }
      _listController.animateTo(oriX,duration: const Duration(milliseconds: 150),curve: Curves.linear);
    }
  }

  void onPageChanged(int index) {

    _assetListModel.updateCurrentIndex(index);

    for (int i = 0; i < _assetListModel.assetList.length; i++) {
      final item = _assetListModel.assetList[i];
      if(item.index == index){
          listViewAnimationToIndex(i);
          break;
        }
    }
    getVideoPathWithIndex(index);
  }

  void getVideoPathWithIndex(int index) async{
    final data = _assetListModel._allAssetList![index];
    final asset = data['asset'] as Asset;
    if(asset.mediaType != 0 && asset.mediaUrl == null && !_videoUrlLoadingIndexes.contains(index)){
      final videoFilePath = await AssetPicker.requestVideoUrl(asset.identifier);
      if(videoFilePath != null && mounted){
        _videoUrlLoadingIndexes.remove(index);
        asset.mediaUrl = videoFilePath;

        if(_assetListModel.currentIndex == index){
          setState(() {
          });
        }
      }
    }
  }

  ///点击完成事件
  void didSelectItem(){
    if (widget.photoDidSelectCallBack != null) {
      List<Asset> selectAssets = [];
      if(widget.isFromPreview!){
        for (var item in _assetListModel.assetList) {
          if(item.assetInfo['selectIndex'] != -1) {
            selectAssets.add(item.assetInfo['asset']);
          }
        }
      }
      else {
        for (var item in _assetListModel.assetList) {
          selectAssets.add(item.assetInfo['asset']);
        }
      }
      if(selectAssets.isEmpty){
        selectAssets.add(_assetListModel._allAssetList![_assetListModel.currentIndex!]['asset']);
      }
      widget.photoDidSelectCallBack!(selectAssets);
    }
    var navi = Navigator.of(context);
    widget.parentPageRoute?.cancel = true;
    widget.pageRoute?.cancel = true;

    navi.pop();
    navi.pop();
    if(!widget.fromDropMode){
      navi.pop();
    }
  }

  ///底部选择数量及完成bannber(抽取的公共组件)
   Widget _bottomWidget(int total,bool showModify)
   {
     return Stack(
       children: <Widget>[
         if(showModify)
           Align(
             alignment: Alignment.centerLeft,
             child: CupertinoButton(
               padding: const EdgeInsets.only(right: 8, left: 16),
               child: Text('编辑',style:TextStyle(color: (widget.isFromPreview! && total == 0) ? Colors.grey[600]: Colors.white)),
               onPressed:(){
                 final data = _assetListModel._allAssetList![_assetListModel.currentIndex!];
                 final asset = data['asset'] as Asset?;
                 Navigator.of(context).push(
                     PageRouteBuilder<Map>(
                         pageBuilder: (_,__,___) {
                           return Material(
                             child: AssetImageEditScaffold(asset!,widget.isCupertinoType,(delete){
                               _thumbCache.remove(asset.identifier);

                               //点了编辑后自动添加
                               if(data['selectIndex'] == -1 && _assetListModel.assetList.length < widget.maxNumber){
                                 if(widget.isFromPreview!){  //预览只需要设置选中序号,并把后面的选中改变序号

                                   int thumbIndex = _assetListModel.assetList.indexWhere((element) => element.assetInfo == data);
                                   int? selIndex = -1;
                                   for(int i = 1;;i++){
                                     int beforeIndex = thumbIndex - i;
                                     int afterIndex = thumbIndex + i;
                                     if(beforeIndex < 0 && afterIndex >= _assetListModel.assetList.length){
                                       break;
                                     }
                                     if(beforeIndex >=0 && selIndex == -1){
                                       int? beforeModelIndex = _assetListModel.assetList[beforeIndex].assetInfo['selectIndex'];
                                       if(beforeModelIndex != -1){
                                         selIndex = beforeModelIndex! + 1;
                                       }
                                     }

                                     if(afterIndex < _assetListModel.assetList.length){
                                       int? afterModelIndex = _assetListModel.assetList[afterIndex].assetInfo['selectIndex'];
                                       if(afterModelIndex != -1)
                                       {
                                         _assetListModel.assetList[afterIndex].assetInfo['selectIndex'] = afterModelIndex! + 1;
                                         if(selIndex == -1) {
                                           selIndex = afterModelIndex;
                                         }
                                       }
                                     }
                                   }
                                   data['selectIndex'] = selIndex == -1 ? 1 : selIndex;
                                 }
                                 else {
                                   _assetListModel.addDataObject(_AssetSelectItem(data,_assetListModel.currentIndex));
                                   data['selectIndex'] = _assetListModel.assetList.length;
                                   Future.delayed(const Duration(milliseconds: 20),() {
                                     if(mounted && _listController.hasClients) {
                                       _listController.animateTo(_listController.position.maxScrollExtent,duration: const Duration(milliseconds: 150),curve: Curves.linear);
                                     }
                                   }
                                   );
                                 }
                               }

                               if(delete){
                                 if(asset.editInfo != null){
                                   String? path = asset.editInfo!['path'];
                                   String? thumbPath = asset.editInfo!['thumb'];
                                   asset.editInfo = null;
                                   WidgetsBinding.instance.addPostFrameCallback((_) {
                                     try {
                                       if (path != null) {
                                         File(path).deleteSync();
                                       }
                                       if (thumbPath != null) {
                                         File(thumbPath).deleteSync();
                                       }
                                     }
                                     catch (e) {
                                       if (kDebugMode) {
                                         print('delete failure!');
                                       }
                                     }
                                   });
                                 }
                               }
                               _assetListModel.updateModel();
                               widget.imageEditCallback?.call();

                             }),
                           );
                         }
                     )
                 );
               },
             ),
           ),
         Center( child: Text('已选择（$total）',style: const TextStyle(color: Colors.white,fontSize: 17),)),
         Align( alignment: Alignment.centerRight,
           child:CupertinoButton(
             padding: const EdgeInsets.only(right: 16, left: 8),
             onPressed:(widget.isFromPreview! && total == 0) ? null : didSelectItem,
             child: Text('完成',style:TextStyle(color: (widget.isFromPreview! && total == 0) ? Colors.grey[600]: Colors.white)),
           ),)
       ],
     );
   }

   /// 缩略图item widget
   /// thumbData: 缩略图数据
   /// index: 缩略图在listview数据数组中的序号
   /// previewIndex: 缩略图在预览图中的原始序号

   Widget _thumbItemWidget(Uint8List? thumbData,int index,int? previewIndex,int? mediaType)
   {
     final imageWidget = thumbData == null ? Container(
       width: 50,
       height: 50,
       color: Colors.grey[350],
       child: const Icon(Icons.music_video_rounded,size: 25,color: Colors.white,),
     ) : Image.memory(thumbData,
         width: 50,
         height: 50,
         color: const CupertinoDynamicColor.withBrightness(color: Color(0xFFFFFFFF),darkColor: Color(0xFFB0B0B0)).resolveFrom(context),
         colorBlendMode: BlendMode.modulate,
         fit: BoxFit.cover);

     return GestureDetector(
         behavior: HitTestBehavior.opaque,
         onTap: (){
           if(_assetListModel.currentIndex != previewIndex){
             _pageController!.jumpToPage(previewIndex!);
           }
         },
         child:DragTarget<int>(
           builder: (context,_,__) {
             return Builder(
               builder: (ctx) {
                 final dragCurrentIndex = ctx.select<_AssetSelectListModel,int?>((value) => value.dragCurrentIndex);
                 final dragBelowIndex = ctx.select<_AssetSelectListModel,int>((value) => value.dragBelowIndex);
                 Offset offset = Offset.zero;
                 if(dragCurrentIndex != -1 && dragBelowIndex != -1 &&
                     dragCurrentIndex != dragBelowIndex && dragCurrentIndex != index){
                   if(dragCurrentIndex! > dragBelowIndex) {
                     if(index < dragCurrentIndex && index >= dragBelowIndex){
                       offset = const Offset(58, 0);
                     }
                   }
                   else {
                     if(index > dragCurrentIndex && index <= dragBelowIndex){
                       offset = const Offset(-58, 0);
                     }
                   }
                 }

                 final child = Stack(
                   children: [
                     Container(
                         padding: const EdgeInsets.only(left: 8),
                         child: Stack(
                           children: [
                             imageWidget,
                             if(mediaType != 0)
                               Positioned(
                                 bottom: 0,
                                 left: 0,
                                 right: 0,
                                 child: Container(
                                   height: 25,
                                   alignment: Alignment.centerLeft,
                                   padding: const EdgeInsets.only(left: 6,right: 6),
                                   decoration: const BoxDecoration(
                                     gradient: LinearGradient(
                                       begin: Alignment.bottomCenter,
                                       end: Alignment.topCenter,
                                       colors: [ Color(0x90000000), Colors.transparent],
                                     ),
                                   ),
                                   child:Icon(mediaType == 1 ? Icons.videocam_outlined:Icons.audiotrack_rounded,size: 16,color: Colors.white,),
                                 ),
                               ),
                             Builder(
                                 builder: (ctx) {
                                   final selIndex = ctx.select<_AssetSelectListModel,int?>((model) =>  index >= model.assetList.length  ? -1 :
                                   model.assetList[index].assetInfo['selectIndex']);
                                   return Container(
                                     color: selIndex != -1 ? Colors.transparent:Colors.white54,
                                   );
                                 }

                             ),

                           ],
                         )
                     ),
                     Selector<_AssetSelectListModel, int?>(
                         builder: (_, index, __) {
                           return Container(
                             margin: const EdgeInsets.only(left: 8),
                             decoration: index == previewIndex ? BoxDecoration(
                                 border: Border.all(color: Colors.green,width: 2)
                             ):null,
                           );
                         },
                         selector: (_, data) => data.currentIndex)
                   ],
                 );

                 ///拖动的widget，由于拖动时widget加载在另外的context中，所以需要单独copy一份
                 final feedChild = Stack(
                   children: [
                     Container(
                         padding: const EdgeInsets.only(left: 8),
                         width:58,
                         height:50,
                         child: Stack(
                           children: [
                             imageWidget,
                             if(mediaType != 0)
                               Positioned(
                                 bottom: 0,
                                 left: 0,
                                 right: 0,
                                 child: Container(
                                   height: 25,
                                   alignment: Alignment.centerLeft,
                                   padding: const EdgeInsets.only(left: 6,right: 6),
                                   decoration: const BoxDecoration(
                                     gradient: LinearGradient(
                                       begin: Alignment.bottomCenter,
                                       end: Alignment.topCenter,
                                       colors: [ Color(0x90000000), Colors.transparent],
                                     ),
                                   ),
                                   child: const Icon(Icons.videocam_outlined,size: 16,color: Colors.white,),
                                 ),
                               ),
                             Builder(
                                 builder: (ctx) {
                                   final selIndex = _assetListModel.assetList[index].assetInfo['selectIndex'];
                                   return Container(
                                     color: selIndex != -1 ? Colors.transparent:Colors.white54,
                                   );
                                 }

                             )
                           ],
                         )
                     ),
                     Container(
                       width:50,
                       height:50,
                       margin: const EdgeInsets.only(left: 8),
                       decoration: _assetListModel.currentIndex == previewIndex ? BoxDecoration(
                           border: Border.all(color: Colors.green,width: 2)
                       ):null,
                     )
                   ],
                 );
                 return
                   AnimatedContainer(
                     transform: Transform.translate(
                       offset: offset,
                     ).transform,
                     duration: _assetListModel.isEndDrag ? Duration.zero : const Duration(milliseconds: 150),
                     child: LongPressDraggable(
                       axis: Axis.horizontal,
                       maxSimultaneousDrags: 1,
                       data: index,
                       childWhenDragging: const SizedBox(),
                       feedback:
                       ScaleTransition(
                         scale: scaleAnimation,
                         child: feedChild,
                       ),
                       onDragStarted: () {
                         dragMoveOffset = -1;
                         scaleController!.reset();
                         scaleController!.forward();
                       },
                       onDragCompleted: () {
                         dragMoveOffset = -1;
                         endDrag();
                       },
                       onDraggableCanceled: (Velocity velocity, Offset offset) {
                         dragMoveOffset = -1;
                         endDrag();
                       },
                       child: child,
                     ),
                   );
               },
             );
           },
           onWillAccept: (int? toAccept) {
             dragMoveOffset = -1;
             _assetListModel.isEndDrag = false;
             _assetListModel.dragCurrentIndex = toAccept;
             _assetListModel.dragBelowIndex = index;
             _assetListModel.updateModel();
             return true;
           },
           onMove: (details)
           {
             if(details.data == _assetListModel.assetList.length-2)
             {
               dragMoveOffset = details.offset.dx;
             }
             else
             {
               dragMoveOffset = -1;
             }
           },
           onLeave: (Object? leaving) {
             int dragIndex = leaving as int;
             if(index == dragIndex -1 || index == dragIndex + 1)//在自己位置
                 {
               if(dragIndex == _assetListModel.assetList.length-2 && index == dragIndex + 1 && dragMoveOffset > index * 58 + 10) {
                 return;
               }

               if(_assetListModel.dragCurrentIndex != -1 && _assetListModel.dragBelowIndex != -1) {
                 _assetListModel.isEndDrag = false;
                 _assetListModel.dragCurrentIndex = -1;
                 _assetListModel.dragBelowIndex = -1;
                 _assetListModel.updateModel();
               }
             }
           },
         ));
   }

   ///缩略图列表
   Widget _thumbWidget(List<_AssetSelectItem> dataList)
   {
     final picWidth = MediaQuery.of(context).devicePixelRatio * 50;
      return SizedBox(
          height: 70,
          child:
          ListView.builder(
            cacheExtent: 0,
            controller: _listController,
            padding: const EdgeInsets.only(left: 5,right: 15,top: 10,bottom: 10),
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (ctx,index)
            {
              return Builder(
                builder: (ctx)
                {
                  final obj = ctx.select<_AssetSelectListModel,_AssetSelectItem?>((value) => index >= value.assetList.length  ? null : value.assetList[index]);
                  final editInfo = ctx.select<_AssetSelectListModel,Map?>((value) => index >= value.assetList.length  ? null : (value.assetList[index].assetInfo['asset'] as Asset).editInfo);
                  if(obj == null){
                    return const SizedBox(width: 50,height: 50,);
                  }
                  Asset asset = obj.assetInfo['asset'];

                  if(asset.mediaType == 2) {
                    return _thumbItemWidget(null, index, obj.index,asset.mediaType);
                  }

                  int picSizeHeight = (asset.originalWidth == 0 ? picWidth : min(picWidth, asset.originalWidth)  * asset.ration).toInt();

                  Uint8List? cacheData = _thumbCache[asset.identifier];
                  if(cacheData != null){
                    return _thumbItemWidget(cacheData, index, obj.index,asset.mediaType);
                  }
                  else{
                    if(editInfo != null){
                      final file = File(asset.editInfo!['thumb']);
                      PaintingBinding.instance.imageCache.evict(FileImage(file));
                    }
                    return FutureBuilder<Uint8List?>(
                      future: Future( () async{
                            final data = await asset.getImageThumbByteData(picWidth.toInt(),picSizeHeight,quality: 70);
                            _thumbCache[asset.identifier] = data;
                            if(_thumbCache.length > 15){  //缓存不能过大，若过大，保留一屏幕多一点
                              int minPage = 7;
                              Size? size;
                              if(mounted){
                                size = context.size;
                              }
                              if(size != null)
                              {
                                minPage = min(15,(size.width / 58).ceil());
                              }
                              final removeKeys = _thumbCache.keys.toList().sublist(0,_thumbCache.length - minPage);
                              _thumbCache.removeWhere((key, _) => removeKeys.contains(key));
                            }
                            return data;
                          }
                      ),
                      builder: (_,snapshot) => snapshot.hasData ? _thumbItemWidget(snapshot.data, index, obj.index,asset.mediaType) : const SizedBox(),
                    );
                  }
                },
              );
            },
            itemCount: dataList.length,
            itemExtent: 58,
          )
        );
   }

  @override
  Widget build(BuildContext context) {

    final topNavigationWidget = SlideTransition(
      position: animationTop,
      child: ClipRRect(
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Container(
                alignment: Alignment.bottomLeft,
                color: const Color(0x99333333),
                padding: const EdgeInsets.only(left: 8,right: 8),
                height: 44 + MediaQuery.of(context).padding.top,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    CupertinoNavigationBarBackButton(
                      color: Colors.white,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Selector<_AssetSelectListModel, int?>(
                        builder: (_, index, __) {
                          return Text(
                            "${index! + 1} / ${_assetListModel._allAssetList!.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17.0,
                              decoration: null,
                            ),
                          );
                        },
                        selector: (_, data) => data.currentIndex),
                    Builder(
                      builder: (ctx) {
                        final index =
                        ctx.select<_AssetSelectListModel, int?>(
                                (value) => value.currentIndex)!;
                        final data = _assetListModel._allAssetList![index];
                        final asset = data['asset'] as Asset;
                        bool showSlt = asset.mediaType == 0 || asset.mediaUrl != null;
                        _currentIndexChanged = true;
                        return showSlt ? Builder(
                          builder: (ctx) {
                            final selectIndex = ctx.select<_AssetSelectListModel, int?>((value) =>value._allAssetList![index]
                            ['selectIndex']);
                            bool pageChanged = _currentIndexChanged;
                            _currentIndexChanged = false;
                            return
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: ()
                                {
                                  didTapCheckBox(selectIndex,index);
                                },
                                child: Container(
                                  width: 50,height: 44,
                                  padding: const EdgeInsets.only(left: 12,right: 12,top: 9,bottom: 9),
                                  child: AnimatedSwitcher(
                                    switchInCurve: Curves.bounceOut,
                                    transitionBuilder: (child, anim) {
                                      if(pageChanged || selectIndex == -1)
                                      {
                                        return child;
                                      }
                                      return ScaleTransition(
                                        scale: anim,
                                        child: child,
                                      );
                                    },
                                    duration:const Duration(milliseconds: 400),
                                    reverseDuration:const Duration(milliseconds: 10),
                                    child:
                                    selectIndex == -1 ? Container(
                                      key: ValueKey<int>(selectIndex == -1 ? -1 : 0),
                                      decoration: BoxDecoration(
                                          color: const Color(0x2F000000),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.white,width: 2)
                                      ),
                                    ) :
                                    Container(
                                      key: ValueKey<int>(selectIndex == -1 ? -1 : 0),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(child:Text('$selectIndex',style: const TextStyle(fontSize: 15,color: Colors.white),)),
                                    ),

                                  ),
                                ),
                              );
                          },
                        ) : const SizedBox(width: 20,height: 20,);
                      },
                    ),
                  ],
                ),
              )
          )
      ),
    );

    final child = Container(
      decoration: widget.backgroundDecoration,
      constraints: BoxConstraints.expand(
        height: MediaQuery.of(context).size.height,
      ),
      child:
      Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: _buildItem,
            itemCount: _assetListModel._allAssetList!.length,
            loadingBuilder:widget.loadingBuilder,
            backgroundDecoration: widget.backgroundDecoration,
            pageController: _pageController,
            onPageChanged: onPageChanged,

            scrollDirection: widget.scrollDirection,
            gaplessPlayback:true,
          ),
          ///顶部导航栏
          Positioned(
              top: 0,
              left: 0,
              width: MediaQuery.of(context).size.width,
              child:topNavigationWidget
          ),

          Positioned(
              bottom: 0,
              right: 0,
              width: MediaQuery.of(context).size.width,
              child:
              SlideTransition(position: animation,
                  child:
                  ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8.0,sigmaY: 8.0),
                      child:
                      widget.isFromPreview! ?
                      Container(
                        color: const Color(0x99333333),
                        height: (114) + MediaQuery.of(context).padding.bottom,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _thumbWidget(_assetListModel.assetList),
                            Selector<_AssetSelectListModel, int?>(
                                builder: (_, index, __) {
                                  bool showModify = false;
                                  if(index! >=0){
                                    final data = _assetListModel._allAssetList![index];
                                    final asset = data['asset'] as Asset;
                                    showModify = asset.mediaType == 0;
                                  }
                                  return SizedBox(
                                    height: 44,
                                    child:
                                    Selector<_AssetSelectListModel,List<_AssetSelectItem>>(
                                        shouldRebuild:(_,__) => true,
                                        builder: (_,dataList,__){
                                          int total = 0;
                                          for(final item in dataList) {
                                            if(item.assetInfo['selectIndex'] != -1){
                                              total++;
                                            }
                                          }
                                          return _bottomWidget(total,showModify);
                                        },
                                        selector: (_,data)=>data.assetList),
                                  );
                                },
                                selector: (_, data) => data.currentIndex)
                          ],
                        ),
                      ) :
                      Selector<_AssetSelectListModel, int?>(
                          builder: (_, index, __) {
                            bool showModify = false;
                            if(index! >=0){
                              final data = _assetListModel._allAssetList![index];
                              final asset = data['asset'] as Asset;
                              showModify = asset.mediaType == 0;
                            }
                            return Selector<_AssetSelectListModel,List<_AssetSelectItem>>(
                                builder: (_,dataList,__) =>
                                    Container(
                                      color: const Color(0x99333333),
                                      height: (dataList.isEmpty ? 44 : 114) + MediaQuery.of(context).padding.bottom,
                                      child:
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          if(dataList.isNotEmpty)
                                            _thumbWidget(dataList),
                                          SizedBox(
                                              height: 44,
                                              child: _bottomWidget(dataList.length,showModify)
                                          )
                                        ],
                                      ),
                                    ),
                                selector: (_,data)=>data.assetList);
                          },
                          selector: (_, data) => data.currentIndex),
                    ),
                  )
              )
          ),
        ],
      ),
    );

    return ChangeNotifierProvider.value(
      value: _assetListModel,
      child: widget.isCupertinoType ?  CupertinoPageScaffold(
        child: Material(
            child: child
        ),
      ) : Scaffold(
        body: child,
      ),
    );
  }

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index)  {
    final Map<String, dynamic> item = _assetListModel._allAssetList![index];
    Asset asset = item['asset'];
    return
      PhotoViewGalleryPageOptions.customChild(
      child: Builder(
        builder: (context) {
         context.select(((_AssetSelectListModel model) => index >= model._allAssetList!.length  ? null :
          (model._allAssetList![index]['asset'] as Asset).editInfo));
         Widget assetChild;
         var query = MediaQuery.of(context);
         var picWidth = query.size.width * query.devicePixelRatio;
         if (asset.mediaType == 0) {
           assetChild = AssetOriginalImage(
             asset: asset,
             fit: BoxFit.contain,
             picSizeWidth: picWidth ~/ (query.orientation == Orientation.landscape ? 5 :3.2),
             maxWidth: widget.picMaxWidth,
             maxHeight: widget.picMaxHeight,
             // width: width == asset.originalWidth ? 0 : width,
             // height: height == asset.originalHeight ? 0 : height,
           );
         } else {
           assetChild = Stack(
             children: [
               Positioned.fill(
                   child: AssetOriginalImage(
                     asset: asset,
                     fit: BoxFit.contain,
                     picSizeWidth: picWidth ~/ (query.orientation == Orientation.landscape ? 5 :3.2),
                     maxWidth: widget.picMaxWidth,
                     maxHeight: widget.picMaxHeight,
                   )),
               Positioned.fill(child:
               GestureDetector(
                 // behavior: HitTestBehavior.opaque,
                 onTap: () {
                   if(asset.mediaUrl != null){
                     Navigator.of(context).push(
                         CupertinoPageRoute<void>(
                             fullscreenDialog: true,
                             builder: (BuildContext context) {
                               if(Platform.isAndroid){
                                 return AssetVideoPlayerScaffold(fileId: asset.fileId,isAudio: asset.mediaType == 2, isCupertinoType: widget.isCupertinoType,);
                               }
                               return AssetVideoPlayerScaffold(videoPath: asset.mediaUrl,isAudio: asset.mediaType == 2,isCupertinoType: widget.isCupertinoType,);
                             }

                         )
                     );
                   }
                 },
                 child:Center(
                   child: Image.asset('images/browse_play_big.png',width: 90,height: 90,package: 'asset_picker',),
                 ),
               )),
               if(asset.mediaUrl == null)
                 const Positioned(left: 16,top: 50,right: 16,height: 100,child: SafeArea(child: Text('视频同步中...',style: TextStyle(backgroundColor: Colors.black26,color: Colors.white,fontSize: 17),)),)
             ],
           );
         }

          return assetChild;
        }
      ),
      onTapUp: (BuildContext context,
          TapUpDetails details,
          PhotoViewControllerValue? controllerValue,)
        {
          if(!controller!.isAnimating)
            {
              if(controller!.status == AnimationStatus.completed) {
                controller!.reverse();
              }
              else if(controller!.status == AnimationStatus.dismissed)
                {
                  controller!.forward();
                }
            }


        },
      childSize: Size(MediaQuery.of(context).size.width,MediaQuery.of(context)
          .size.height),
      initialScale: PhotoViewComputedScale.contained,
      minScale:
      PhotoViewComputedScale.contained * (widget.minScale ?? 1),
      maxScale: PhotoViewComputedScale.contained * (widget.maxScale ?? 3.5),
      heroAttributes: PhotoViewHeroAttributes(tag: asset.identifier),
      enableScaleAndDoubleTap: asset.mediaType == 0
    );

  }
}


