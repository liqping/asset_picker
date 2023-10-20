
import 'dart:io';

import 'package:asset_picker/asset_picker.dart';
import 'package:asset_picker/src/widget/asset_cupertino_page_route.dart';
import 'package:asset_picker/src/widget/picker_photo_browser.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class PickerMainPage extends StatefulWidget{
  final AssetCollection? assetCollection;
  final ValueNotifier<List<AssetCollection>?>? assetsCatalogChanged;

  final int maxNumber;

  ///show last asset on gridView bottom
  final bool scrollReverse;

  final bool fromDropMode;

  final AssetCupertinoPageRoute? myRoute;

  final AssetPickerType? type; //0 图片 1 视频 2 音频 -1 所有的
  final bool isCupertinoType;
  final AssetPickedCallback? photoDidSelectCallBack;
  final VoidCallback? popCallback;
  const PickerMainPage({super.key,
    this.assetCollection,
    required this.maxNumber,
    required this.scrollReverse,
    this.fromDropMode = false,
    this.assetsCatalogChanged,
    this.myRoute,
    this.type = AssetPickerType.picture,this.photoDidSelectCallBack,this.popCallback,required this.isCupertinoType}) :
        assert(assetCollection != null || photoDidSelectCallBack != null,'assetCollection != null || photoDidSelectCallBack != null');

  @override
  State<StatefulWidget> createState() {
    return _PickerMainPage();
  }

}

class AssetListModel extends ChangeNotifier{
  List<Map<String,dynamic>> _assetList = [];
  List<Map<String,dynamic>> get assetList => _assetList;

  void updateData(List<Map<String,dynamic>> list){
    if(_assetList != list)
    {
      _assetList = list;
    }
    notifyListeners();
  }

  void deleteDataWithIndex(int index)
  {
    if(index < _assetList.length)
    {
      _assetList = _assetList.toList();
      _assetList.removeAt(index);
      notifyListeners();
    }
  }

  void deleteDataWithObject(dynamic obj)
  {
    _assetList = _assetList.toList();
    _assetList.remove(obj);
    notifyListeners();
  }

  void clearData()
  {
    _assetList = _assetList.toList();
    _assetList.clear();
    notifyListeners();
  }

  void addDataObject(dynamic obj)
  {
    _assetList = _assetList.toList();
    _assetList.add(obj);
    notifyListeners();
  }

  void addDataWithList(List<Map<String,dynamic>> objList)
  {
    if(objList.isNotEmpty)
    {
      _assetList = _assetList.toList();
      _assetList.addAll(objList);
      notifyListeners();
    }
  }

  void updateModel()
  {
    notifyListeners();
  }
}

class _PickerMainPage extends State<PickerMainPage>{

  final AssetListModel _assetListModel = AssetListModel();

  Size? _screenSize;

  bool _showVideoLoading = false;

  bool _request = false;

  bool _hideCell = false;

  int? picSizeWidth;
 final ScrollController _controller = ScrollController();

  AssetCollection? _assetCollection;

  void catalogChanged() async{
    final catalogs = widget.assetsCatalogChanged?.value;
    if(catalogs != null){
      widget.assetsCatalogChanged?.removeListener(catalogChanged);
      if(!mounted){
        return;
      }

      if(catalogs.isEmpty){
        setState(() {
          _request = false;
        });
        return;
      }
      setState(() {
        _assetCollection = catalogs.first;
      });
      requestAssets();
    }else{
      if(mounted){
        setState(() {
          _request = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant PickerMainPage oldWidget) {
    if(oldWidget.assetsCatalogChanged != widget.assetsCatalogChanged){
      oldWidget.assetsCatalogChanged?.removeListener(catalogChanged);
    }
    if(widget.assetCollection != null && widget.fromDropMode && widget.assetCollection != oldWidget.assetCollection){
      _assetCollection = widget.assetCollection;
      _request = false;
      requestAssets();
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.assetsCatalogChanged?.removeListener(catalogChanged);
    _controller.dispose();
    super.dispose();
  }

  void requestAssets() async {

    try {
      var list =_assetCollection!.children;
      if(list == null) {
        _request = true;
        int assetType = widget.type!.index;
        if(widget.type == AssetPickerType.all)
        {
          assetType = -1;
        }
        list = (await AssetPicker.getAssetsFromCatalog(_assetCollection!.identifier,!widget.scrollReverse, assetType)) as List<Asset>;
        if(!mounted){
          return;
        }
        setState(() {
          _request = false;
        });
        List<Map<String,dynamic>> temp = [];
        _assetCollection!.children = list;
        for(var asset in list)
        {
          temp.add({'asset':asset,'selectIndex':-1});
        }

        if(widget.scrollReverse){
          _hideCell = true;
          if(_controller.hasClients){
            _assetListModel.updateData([]);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _assetListModel.updateData(temp);
            WidgetsBinding.instance.addPostFrameCallback((_){
              if(_controller.hasClients && _controller.position.maxScrollExtent > 0){
                _hideCell = false;
                _controller.jumpTo(_controller.position.maxScrollExtent);
              }else if(mounted){
                setState(() {
                  _hideCell = false;
                });
              }
            });

          });
        }else{
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if(_controller.hasClients){
              _controller.jumpTo(0);
            }
          });
          _assetListModel.updateData(temp);
        }

      } else{
        List<Map<String,dynamic>> temp = [];
        for(var asset in list){
          temp.add({'asset':asset,'selectIndex':-1});
        }
        if(widget.scrollReverse){
          _hideCell = true;
          if(_controller.hasClients){
            _assetListModel.updateData([]);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _assetListModel.updateData(temp);
            WidgetsBinding.instance.addPostFrameCallback((_){
              if(_controller.hasClients && _controller.position.maxScrollExtent > 0){
                _hideCell = false;
                _controller.jumpTo(_controller.position.maxScrollExtent);
              }else if(mounted){
                setState(() {
                  _hideCell = false;
                });
              }
            });

          });
        }else{
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if(_controller.hasClients){
              _controller.jumpTo(0);
            }
          });
          _assetListModel.updateData(temp);
        }
      }
    }
    on PlatformException catch(e){
      AssetToast.show(e.message, context,gravity: AssetToast.CENTER,backgroundRadius: 8);
      if(int.parse(e.code) == -1000){
        if (widget.popCallback != null) {
          widget.popCallback!();
        }
      }
    }catch(e){
      AssetToast.show(e.toString(), context,gravity: AssetToast.CENTER,backgroundRadius: 8);
    }
  }

  void toBrowser(int index){
    Navigator.of(context).push(
        AssetCupertinoPageRoute(
            context: context,
            widgetBuilder: (_,route){
              return GalleryPhotoViewWrapper(
                pageRoute: route,
                parentPageRoute: widget.myRoute,
                fromDropMode: widget.fromDropMode,
                isCupertinoType: widget.isCupertinoType,
                galleryItems: _assetListModel.assetList,
                // orientType: widget.orientType,
                // parentRoute: ModalRoute.of(context),
                // rootRoute: widget.rootRoute,
                backgroundDecoration: const BoxDecoration(
                  color: Colors.black,
                ),
                scrollDirection: Axis.horizontal,
                initialIndex: index,maxNumber: widget.maxNumber,
                photoDidSelectCallBack: widget.photoDidSelectCallBack,);
            }
        )
    ).then((_)=>_assetListModel.updateModel());

  }

  void checkTaped(int? selectIndex,Asset asset,int index) async{
    if(selectIndex == -1){
      final int selCount = totalSelect();
      if(selCount >= widget.maxNumber){
        String typeString;
        switch(widget.type){
          case AssetPickerType.picture:
            typeString = '照片';
            break;
          case AssetPickerType.video:
            typeString = '视频';
            break;
          case AssetPickerType.audio:
            typeString = '音频';
            break;
          default:
            typeString = '媒体';
            break;
        }

        AssetToast.show('最多选择${widget.maxNumber}个$typeString',context,gravity: AssetToast.CENTER);
        return;
      }

      if(Platform.isAndroid || asset.mediaType == 0 || (asset.mediaUrl != null && asset.mediaUrl!.isNotEmpty)){
        final data = _assetListModel.assetList.toList();
        final dataItem =  data[index];

        dataItem['selectIndex'] = selCount+1;
        _assetListModel.updateData(data);
      }
      else{
        setState(()=>_showVideoLoading = true);
        final videoFilePath = await AssetPicker.requestVideoUrl(asset.identifier);
        setState(() {
          _showVideoLoading = false;
        });

        if(videoFilePath != null){
          asset.mediaUrl = videoFilePath;
          final data = _assetListModel.assetList.toList();
          final dataItem =  data[index];
          dataItem['selectIndex'] = selCount+1;
          _assetListModel.updateData(data);
        }
        else if(mounted){
          AssetToast.show('同步视频失败!',context,gravity: AssetToast.CENTER);
        }

      }
    }
    else{
      final data = _assetListModel.assetList.toList();
      final dataItem =  data[index];

      int? selectIndex = dataItem['selectIndex'];
      dataItem['selectIndex'] = -1;

      for(final item in data)
      {
        int? itemIndex = item['selectIndex'];
        if(itemIndex != -1 && itemIndex! > selectIndex!) {
          item['selectIndex'] = itemIndex - 1;
        }
      }
      _assetListModel.updateData(data);
    }
  }


  Widget getItemCell(int index){
    return Builder(builder: (ctx){
      final obj = ctx.select(((AssetListModel model) => index >= model.assetList.length  ? null :
      model.assetList[index]));
      //
      final editInfo = ctx.select<AssetListModel,Map?>((value) => index >= value.assetList.length  ? null : (value.assetList[index]['asset'] as Asset).editInfo);
      Asset asset = obj!['asset'];
      return Container(
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0x11000000))
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              AssetThumbImage(asset: asset,width:picSizeWidth!,index: index,needCache: true,),
              if (editInfo != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 28,
                    foregroundDecoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [ Color(0x90000000), Colors.transparent],
                      ),
                    ),
                  ),
                ),

              Builder(builder: (ctx)
              {
                final selectIndex = ctx.select<AssetListModel,int?>((AssetListModel model) => index >=  model.assetList.length  ? -1 :
                model.assetList[index]['selectIndex']);
                final child = AnimatedSwitcher(
                  switchInCurve: Curves.bounceOut,
                  transitionBuilder: (child, anim) {
                    return selectIndex != -1 ? ScaleTransition(
                      scale: anim,
                      child: child,
                    ) : child;
                  },
                  duration:const Duration(milliseconds: 400),
                  reverseDuration:const Duration(milliseconds: 10),
                  child:
                  Container(
                    padding: const EdgeInsets.all(6),
                    // color: Colors.red,
                    key: ValueKey<int>(selectIndex == -1 ? -1 : 0),
                    child: selectIndex == -1 ? Container(
                      decoration: BoxDecoration(
                          color: const Color(0x2F000000),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white,width: 2)
                      ),
                    ) :
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(child:Text('$selectIndex',style: const TextStyle(fontSize: 15,color: Colors.white),)),
                    ),
                  ),
                );

                return  Container(
                  color: selectIndex != -1 ? Colors.black45 : Colors.transparent,
                  alignment: Alignment.topRight,
                  child:
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => checkTaped(selectIndex,asset,index),
                    child: SizedBox(
                      width: 36,height: 36,
                      child: child,
                    ),
                  ),
                );
              }),
              if(asset.editInfo != null) Positioned(
                  bottom: 3,
                  left: 3,
                  child: Image.asset('images/md_mark.png',width: 15,height: 15,package: 'asset_picker',)
              ),

              if (asset.mediaType != 0)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.only(left: 6,right: 6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [ Color(0x90000000), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Padding(padding: EdgeInsets.only(right: 3),child: Icon(Icons.videocam_outlined,size: 18,color: Colors.white,),) ,
                        Builder(builder: (ctx){
                          String secondsString = '';
                          int seconds = asset.duration! % 60;
                          int minutes = asset.duration! ~/ 60;
                          if(minutes < 10){
                            secondsString += '0$minutes';
                          }
                          else{
                            secondsString += minutes.toString();
                          }
                          secondsString += ':';
                          if(seconds < 10){
                            secondsString += '0$seconds';
                          }
                          else{
                            secondsString += seconds.toString();
                          }

                          return Text(secondsString,style: const TextStyle(color: Colors.white,fontSize: 12),);
                        })
                        // Text()
                      ],
                    ),
                  ),
                ),
            ],)
      );
    },);
  }

  int totalSelect(){
    int selCount = 0;
    for(var asset in _assetListModel.assetList)
    {
      if(asset['selectIndex'] != -1)
      {
        selCount++;
      }
    }
    return selCount;
  }

  void popToDismiss(){
    var navi = Navigator.of(context);
    if(widget.fromDropMode){
      navi.pop();
      return;
    }
    widget.myRoute?.cancel = true;
    navi.pop();
    navi.pop();
  }

  void fitScrollPosition({required MediaQueryData data}){
    if(_controller.hasClients && _controller.offset > 0 ){
      final preOffset = _controller.offset;
      final int count = data.orientation == Orientation.landscape ? 6 : 4;
      final int preCount = count == 4 ? 6 : 4;
      final double preImageWidth = (_screenSize!.width - (preCount+1) * 5) / preCount;
      final double imageWidth = (data.size.width - (count+1) * 5) / count;
      final offset =  preOffset / (preImageWidth + 5) * preCount / count * (imageWidth + 5);
      if (kDebugMode) {
        print('preOffset:$preOffset offset:$offset');
      }
      _controller.jumpTo(offset);
    }
  }

  void previewAsset() async{
    await Navigator.of(context).push( AssetCupertinoPageRoute(
        context: context,
        widgetBuilder: (_,route) {
          List<Map<String, dynamic>>
          selectAssets = [];
          for (final asset in _assetListModel.assetList) {
            if (asset['selectIndex'] != -1) {
              selectAssets.add(asset);
            }
          }
          selectAssets.sort((obj1, obj2) =>obj1['selectIndex'].compareTo(obj2['selectIndex']));
          return GalleryPhotoViewWrapper(
            isCupertinoType: widget.isCupertinoType,
            parentPageRoute: widget.myRoute,
            pageRoute: route,
            fromDropMode: widget.fromDropMode,
            galleryItems: selectAssets,
            initialIndex: 0,
            maxNumber: widget.maxNumber,
            backgroundDecoration: const BoxDecoration(color: Colors.black,),
            scrollDirection: Axis.horizontal,
            photoDidSelectCallBack:widget.photoDidSelectCallBack,
            isFromPreview: true,
          );
        })
    );
    _assetListModel.updateModel();
  }

  void finishChoose(){
    if (widget.photoDidSelectCallBack != null) {
      List<Asset> selectAssets = [];
      if (_assetListModel.assetList.isNotEmpty) {
        _assetListModel.assetList.sort((obj1, obj2) => obj2['selectIndex'].compareTo(obj1['selectIndex']));
      }

      for (final asset in _assetListModel.assetList) {
        if (asset['selectIndex'] == -1) {
          break;
        }
        selectAssets.add(asset['asset']);
      }
      widget.photoDidSelectCallBack!(selectAssets.reversed.toList());
    }
    popToDismiss();
    if (widget.popCallback != null) {
      widget.popCallback!();
    }
  }


  @override
  void initState() {

    super.initState();
    _assetCollection = widget.assetCollection;
    if(_assetCollection != null){
      requestAssets();
    }else{
      widget.assetsCatalogChanged!.addListener(catalogChanged);
    }
  }
  @override
  Widget build(BuildContext context) {
    var query = MediaQuery.of(context);
    if(query.size != _screenSize){
      if(_screenSize != null){
        fitScrollPosition(data: query);
      }
      _screenSize = query.size;

    }
    final double dWidth =  query.size.width * query.devicePixelRatio;
    picSizeWidth = dWidth ~/ (query.orientation == Orientation.landscape ? 5 :3.2);

    final child = Builder(builder: (context) {
      return Stack(
        children: [
          Positioned.fill(child: Selector<AssetListModel, List>(
            selector: (_, model) => model.assetList,
            builder: (ctx, assetList, _) {
              return Scrollbar(
                controller: _controller,
                child: GridView.builder(
                 controller: _controller,
                  physics: widget.isCupertinoType ? const BouncingScrollPhysics() : null,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    crossAxisCount: query.orientation == Orientation.landscape ? 6 : 4,
                  ),
                  padding: EdgeInsets.fromLTRB(5, 5 + MediaQuery.of(context).padding.top,5, 52 + query.viewPadding.bottom),
                  itemBuilder: (BuildContext context, int index) =>GestureDetector(
                      onTap: () => toBrowser(index),
                      child: _hideCell ? Container(color: const Color(0x10000000),) : getItemCell(index)
                  ),
                  itemCount: assetList.length,
                ),
              );
            },
          )),
          Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                children: <Widget>[
                  Divider(
                    color: const CupertinoDynamicColor.withBrightness(color:  Color(0xFFE5E5E5),darkColor: Color(0xFF1C1C1C)).resolveFrom(context),
                    height: 1,
                    thickness: 1,
                  ),
                  Container(
                      height: MediaQuery.of(context).padding.bottom + 44,
                      alignment: Alignment.topCenter,
                      color: Theme.of(context).scaffoldBackgroundColor.withAlpha(240),
                      child: SizedBox(
                          height: 44,
                          child: Builder(builder: (ctx)=>Selector<AssetListModel, List>(
                            selector: (_, model) => model.assetList,
                            shouldRebuild: (_, __) => true,
                            builder: (ctx, assetList, _) {
                              int selCount = 0;
                              for (var asset in assetList) {
                                if (asset['selectIndex'] != -1) {
                                  selCount++;
                                }
                              }
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  CupertinoButton(
                                    padding: const EdgeInsets.only(left: 16, right: 16),
                                    onPressed: selCount > 0? previewAsset: null,
                                    child: const Text('预览',),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(right: 16),
                                    height: 35,
                                    child: CupertinoButton(
                                      padding: const EdgeInsets.only(
                                          left: 5, right: 5, bottom: 2),
                                      minSize: 65,
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(5.0)),
                                      onPressed: selCount > 0 ? finishChoose: null,
                                      color: Colors.lightGreen,
                                      disabledColor: const Color(0xFF226622),
                                      child: Text(selCount > 0 ? '确定($selCount)' : '确定',style: TextStyle(fontSize: 15,color: selCount > 0 ? Colors.white : Colors.white70)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),),
                      ))
                ],
              )),
          if (_showVideoLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black12,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black87,borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
                    child: const Text('视频同步中,请稍后...',style: TextStyle(fontSize: 17, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          if(_request) const Center(child: CupertinoActivityIndicator(),)
        ],
      );
    });

    if(widget.isCupertinoType){
      final subChild = Platform.version.substring(0,2).replaceAll('.', '').compareTo('3') < 0 ?  AnnotatedRegion(
          value: const SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          ),child: child) : child;
      return ChangeNotifierProvider.value(value: _assetListModel,child: widget.fromDropMode ? subChild : CupertinoPageScaffold(
        // backgroundColor: Color(0xFFFFFFFF),
        navigationBar: CupertinoNavigationBar(
          middle: _assetCollection == null ? null : Text(
            _assetCollection!.name,
          ),
          trailing: CupertinoButton(padding: const EdgeInsets.only(top: 4,bottom: 4),
            onPressed: popToDismiss,child: const Text('取消'),
          ),
        ),
        child: subChild,
      ),);
    }

    return  ChangeNotifierProvider.value(
        value: _assetListModel,
        child: widget.fromDropMode ? child : Scaffold(
          appBar: AppBar(
            title: _assetCollection == null ? null : Text(_assetCollection!.name,),
            actions: [
              Builder( builder: (context) =>TextButton(
                onPressed: popToDismiss,
                child: Text('取消',style: DefaultTextStyle.of(context).style.copyWith(fontSize: 17),),
              )
              )
            ],
          ),
          body: child,
        ));
  }
}



