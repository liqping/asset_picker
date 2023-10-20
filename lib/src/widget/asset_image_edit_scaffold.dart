import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'dart:ui' as ui show ImageFilter, Image, Codec, instantiateImageCodec,ImageByteFormat;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:asset_photo_view/photo_view.dart';

import '../../asset_picker.dart';
import 'asset_bg_text.dart';

const int _mosaicWidthConst = 11;
const int _mosaicHeightConst = 11;
const double _mosaicRadiusRatio = 1.27;  //相对于宽度的比例

const double textFontSize = 30;

const double _textMinScale = 0.3;

const int _textTimerDuration = 3; //3 秒

const List<Color> _textColorList = [
  Colors.white,
  Colors.black,
  Color(0xFFE53935),
  Color(0xFFFFA726),
  Color(0xFF43A047),
  Color(0xFF039BE5),
  Colors.indigoAccent
];

class _LineModel {
  Color color;
  List<Offset> points = [];
  final double strokeWidth;
  final double density;
  _LineModel({required this.color, required this.density, this.strokeWidth = 5.0,});
}

class _MosaicModel {
  List<Offset> points = []; //原始的move点集合
  int validPointNumber = 0; //加入到需要渲染的点的个数，当移除此次操作，则需要从渲染点集合中移除这么多点
}

class _ScrawlPainter extends CustomPainter {
  late final Paint _linePaint;
  late final Paint _mosaicPaint;
  final List<_LineModel> lines;
  final Uint8List? imageRGBBytes; //马赛克rgb数据

  final List<Offset> mosaicList; // 马赛克绘制的点
  final int? mosaicColumns;

  final double? mosaicWidth;
  final double? mosaicHeight;

  final double imageUnit;
  final Offset cutOffset;

  _ScrawlPainter({
    required this.lines,
    required this.mosaicList,
    required this.mosaicColumns,
    required this.mosaicWidth,
    required this.mosaicHeight,
    required this.cutOffset,
    required this.imageUnit,
    // @required this.parentSize,
    this.imageRGBBytes,
  }) {
    _linePaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _mosaicPaint = Paint()..strokeWidth = 1;
  }

  /// 通过imageRGBBytes和图片大小，控件大小，获取控件相应点的马赛克颜色
  /// point 控件坐标 Size 画布大小

  Color getPointColor(Offset point) {
    Color pointColor;
    int picX = point.dx ~/ mosaicWidth!;
    int picY = point.dy ~/ mosaicHeight!;
    int colorIndex = (picY * mosaicColumns! + picX) * 4;

    assert(colorIndex + 3 < imageRGBBytes!.length, 'color index error');
    pointColor = Color.fromARGB(
        imageRGBBytes![colorIndex + 3],
        imageRGBBytes![colorIndex],
        imageRGBBytes![colorIndex + 1],
        imageRGBBytes![colorIndex + 2]);

    return pointColor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    //画马赛克
    if (imageRGBBytes != null && imageRGBBytes!.length > 2 && mosaicList.isNotEmpty) {
      for (final offset in mosaicList) {
        canvas.drawRect(Rect.fromLTWH(
            (offset.dx - cutOffset.dx) * imageUnit,
            (offset.dy - cutOffset.dy) * imageUnit,
            mosaicWidth! * imageUnit,mosaicHeight! * imageUnit),
            _mosaicPaint..color = getPointColor(offset));
      }
    }

    //画涂鸦
    if (lines.isNotEmpty) {
      for (int i = 0; i < lines.length; i++) {
        List<Offset> curPoints = lines[i].points;
        if (curPoints.isEmpty) {
          continue;
        }
        _linePaint.color = lines[i].color;
        _linePaint.strokeWidth = lines[i].strokeWidth * lines[i].density * imageUnit;
        Path path = Path();
        path.fillType = PathFillType.nonZero;

        path.moveTo((curPoints[0].dx - cutOffset.dx) * imageUnit, (curPoints[0].dy - cutOffset.dy) * imageUnit);
        for (int i = 1; i < curPoints.length; i++) {
          path.lineTo((curPoints[i].dx - cutOffset.dx) * imageUnit, (curPoints[i].dy - cutOffset.dy) * imageUnit);
        }
        canvas.drawPath(path, _linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ScrawlPainter other) {
    return true;
  }
}


class _TextSpanGestureDetector extends StatelessWidget {
  const _TextSpanGestureDetector(
      {Key? key,
      this.onTap,
      this.onTapUp,
      this.onTapCancel,
        this.onTapDown,
      this.onPanDown,
      this.child,
      this.onPanStart,
      this.onPanUpdate,
      this.onPanEnd,
      this.onPanCancel,
      this.behavior,
      this.shouldPan,
      this.excludeFromSemantics = false})
      : super(key: key);

  final Widget? child;

  final HitTestBehavior? behavior;

  final GestureDragDownCallback? onPanDown;

  /// A pointer has contacted the screen with a primary button and has begun to
  /// move.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragStartCallback? onPanStart;

  /// A pointer that is in contact with the screen with a primary button and
  /// moving has moved again.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragUpdateCallback? onPanUpdate;

  /// A pointer that was previously in contact with the screen with a primary
  /// button and moving is no longer in contact with the screen and was moving
  /// at a specific velocity when it stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragEndCallback? onPanEnd;

  /// The pointer that previously triggered [onPanDown] did not complete.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragCancelCallback? onPanCancel;

  /// A pointer has stopped contacting the screen at a particular location,
  /// which is recognized as a tap of a primary button.
  ///
  /// This triggers on the up event, if the recognizer wins the arena with it
  /// or has previously won, immediately followed by [onTap].
  ///
  /// If this recognizer doesn't win the arena, [onTapCancel] is called instead.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [onSecondaryTapUp], a similar callback but for a secondary button.
  ///  * [onTertiaryTapUp], a similar callback but for a tertiary button.
  ///  * [TapUpDetails], which is passed as an argument to this callback.
  ///  * [GestureDetector.onTapUp], which exposes this callback.
  final GestureTapUpCallback? onTapUp;

  /// A pointer has stopped contacting the screen, which is recognized as a tap
  /// of a primary button.
  ///
  /// This triggers on the up event, if the recognizer wins the arena with it
  /// or has previously won, immediately following [onTapUp].
  ///
  /// If this recognizer doesn't win the arena, [onTapCancel] is called instead.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [onTapUp], which has the same timing but with details.
  ///  * [GestureDetector.onTap], which exposes this callback.
  final GestureTapCallback? onTap;


  /// A pointer has contacted the screen at a particular location with a primary
  /// button, which might be the start of a tap.
  ///
  /// This triggers after the down event, once a short timeout ([deadline]) has
  /// elapsed, or once the gestures has won the arena, whichever comes first.
  ///
  /// If this recognizer doesn't win the arena, [onTapCancel] is called next.
  /// Otherwise, [onTapUp] is called next.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [onSecondaryTapDown], a similar callback but for a secondary button.
  ///  * [onTertiaryTapDown], a similar callback but for a tertiary button.
  ///  * [TapDownDetails], which is passed as an argument to this callback.
  ///  * [GestureDetector.onTapDown], which exposes this callback.
 final GestureTapDownCallback? onTapDown;

  /// A pointer that previously triggered [onTapDown] will not end up causing
  /// a tap.
  ///
  /// This triggers once the gesture loses the arena if [onTapDown] has
  /// previously been triggered.
  ///
  /// If this recognizer wins the arena, [onTapUp] and [onTap] are called
  /// instead.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [onSecondaryTapCancel], a similar callback but for a secondary button.
  ///  * [onTertiaryTapCancel], a similar callback but for a tertiary button.
  ///  * [GestureDetector.onTapCancel], which exposes this callback.
  final GestureTapCancelCallback? onTapCancel;

  final bool Function(PointerEvent event)? shouldPan;

  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build

    final Map<Type, GestureRecognizerFactory> gestures =
        <Type, GestureRecognizerFactory>{};
    gestures[_TextSpanGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<_TextSpanGestureRecognizer>(
      () => _TextSpanGestureRecognizer(debugOwner: this),
      (_TextSpanGestureRecognizer instance) {
        instance
          ..onDown = onPanDown
          ..onStart = onPanStart
          ..onUpdate = onPanUpdate
          ..onEnd = onPanEnd
          ..shouldPan = shouldPan
          ..onCancel = onPanCancel;
      },
    );

    gestures[TapGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
      () => TapGestureRecognizer(debugOwner: this),
      (TapGestureRecognizer instance) {
        instance
          ..onTap = onTap
          ..onTapCancel = onTapCancel
          ..onTapUp = onTapUp
          ..onTapDown = onTapDown;
      },
    );

    return RawGestureDetector(
      gestures: gestures,
      behavior: behavior,
      excludeFromSemantics: excludeFromSemantics,
      child: child,
    );
  }
}

class _TextSpanGestureRecognizer extends PanGestureRecognizer {
  _TextSpanGestureRecognizer({Object? debugOwner})
      : super(debugOwner: debugOwner);

  // final Set<int> _addedPointer = HashSet<int>();
  // bool ready = true;

  bool Function(PointerEvent event)? shouldPan;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (shouldPan != null && !shouldPan!(event)) {
      resolve(GestureDisposition.rejected);
      return;
    }

    super.addAllowedPointer(event);
  }

  @override
  String get debugDescription => 'single_text_span';
}

class _TextCutModel {
  final Map textInfo; //文本及颜色信息
  final double scale; //缩放倍数
  final double pixelDensity; // 文本放入时的图片像素密度
  final double rotate; //旋转角度
  final Offset offset;
  final bool showOperationFrame;
  final bool shouldClip; //是否裁剪多余的文本

  _TextCutModel(this.textInfo,this.pixelDensity, this.scale, this.rotate, this.offset,
      this.showOperationFrame,
      {this.shouldClip = false}); //偏移量
}

class _MosaicCutModel {
  final Uint8List? imageRGBBytes; //马赛克rgb数据

  final List<Offset>? mosaicList; // 马赛克绘制的点
  final int? mosaicColumns;

  final double? mosaicWidth;
  final double? mosaicHeight;

  _MosaicCutModel(
      {this.imageRGBBytes,
      this.mosaicList,
      this.mosaicColumns,
      this.mosaicWidth,
      this.mosaicHeight});
}

class _TextModel {
  Map textInfo; //文本及颜色信息
  double scale; //缩放倍数
  final double pixelDensity; // 文本放入时的图片像素密度
  late double scaleTemp; //记录开始缩放时的当前缩放倍数
  double rotate; //旋转角度
  late double rotateTemp; //记录开始旋转时的当前旋转度数
  Offset offset; //文本中心点相对于图片像素的坐标
  late Offset leftTop; //开始拖动前的左上角坐标
  bool shouldClip; //是否裁剪多余的文本
  bool showOperationFrame; //是否显示缩放以及旋转操作框
  bool shouldShow = true; //当处于编辑状态时需要隐藏
  GlobalKey key = GlobalKey();

  _TextModel(this.textInfo,this.pixelDensity,
      {this.scale = 1.0,
      this.rotate = 0.0,
      this.offset = Offset.zero,
      this.shouldClip = true,
      this.showOperationFrame = false});
}



class AssetImageEditScaffold extends StatefulWidget {
  final Asset asset;
  final void Function(bool delete) assetChanged;
  final bool isCupertinoType;

  const AssetImageEditScaffold(this.asset,this.isCupertinoType, this.assetChanged, {super.key});

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return __MainWidgetState();
  }
}

class __MainWidgetState extends State<AssetImageEditScaffold> {
  PhotoViewController? _photoController;
  double? _photoScale = 1.0;
  final GlobalKey _repaintKey = GlobalKey();

  final GlobalKey _currentMoveKey = GlobalKey(); //_currentMoveIndex 对应的key

  final GlobalKey _removeBarKey = GlobalKey();

  bool _showOptionBar = true;
  bool _showBackButton = true;

  bool _showSaveTips = false;

  bool _showRemoveBar = false;

  ValueNotifier? _indexData;

  int _opIndex = -1; //0 画线模式 1 马赛克模式
  int _colorIndex = 2;

  List<_LineModel> _lines = [];
  List<_MosaicModel> _mosaics = [];

  List<Offset> _mosaicsPoints = [];

  ui.Image? _paintImage;
  Offset _imageCutOffset = Offset.zero;

  Size? _imageCutSize;

  late int _quarterTurns;

  Uint8List? _imageRGBBytes; //马赛克rgb数据

  final List<_TextModel> _textList = []; //文本列表

  int _currentMoveIndex = -1; //需要加在stack下面的序号 为了把移动的文本放在最上面，copy 这个放在stack最下面

  int _findNeedMoveIndex = -1; //需要移动的文本序号
  bool _textBeginMove = false;

  bool _isPanInRemoveBtn = false; //是否移动文本到删除框内了

  Timer? _txtModifyTimer;

  // double? _mosaicScale; //马赛克缩放比例，保证马赛克方块大小为逻辑像素
  int? _mosaicWidthPx; //马赛克每个块的宽度：px
  int? _mosaicHeightPx; //马赛克每个块的高度：px
  int? _mosaicColumns;  //马赛克列数
  double? _mosaicScale;

  ui.Image? _heroImage;

  //文本是否缩放中
  bool _txtScaling = true;



  void listener(PhotoViewControllerValue? value) {
    if (mounted && value != null && value.scale != null) {
      setState(() {
        _photoScale = value.scale;
        // _photoPosition = value.position;
      });
    }
  }


  void getImageData() async {
    final imageBytes = await widget.asset.getImageByteData(maxWidth: 3000, maxHeight: 3000,ignoreEditInfo: true);
    if (imageBytes == null) return;
    ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    _paintImage?.dispose();
    _paintImage = frame.image;
    if (widget.asset.editInfo != null) {
      initEditInFo();
    } else {
      _quarterTurns = 0;
      _imageCutSize = Size(_paintImage!.width.toDouble(), _paintImage!.height.toDouble());
      _imageCutOffset = Offset.zero;
    }
    if(!mounted){
      return;
    }
    final queryData = MediaQuery.of(context);
    final photoSize = Size(queryData.size.width, queryData.size.height);
    double ration2 = photoSize.width / photoSize.height;
    initMosaicInfo(ration2, photoSize);
    if (mounted && _paintImage != null) {
      setState(() {});
    }
  }

  void initEditInFo() {
    final editInfo = widget.asset.editInfo!;

    // _imageCutScale = editInfo['imageCutScale'];
    _imageCutOffset = editInfo['cut']['offset'];
    _imageCutSize = editInfo['cut']['size'];
    _quarterTurns = editInfo['quarterTurns'];

    ///添加文本
    List<_TextCutModel> cutTextList = editInfo['txt'];

    for (final txtModel in cutTextList) {
      _textList.add(_TextModel(txtModel.textInfo,
          txtModel.pixelDensity,
          scale: txtModel.scale,
          rotate: txtModel.rotate,
          offset: txtModel.offset,
          showOperationFrame: txtModel.showOperationFrame,
          shouldClip: txtModel.shouldClip));
    }

    ///添加马赛克
    _mosaics = List.of(editInfo['mosaics']);

    _lines = List.of(editInfo['lines']);
    _mosaicsPoints = List.of(editInfo['mosaicsPoints']);
  }

  void getMosaicData() {
    if (_imageRGBBytes == null) {
      // _imageRGBBytes = Uint8List(1);

      _paintImage!.toByteData(format: ui.ImageByteFormat.rawStraightRgba).then((ByteData? value) {
        if (!mounted) return;
        int picWidth = _paintImage!.width;
        int picHeight = _paintImage!.height;

        int mosaicColumns = (picWidth.toDouble() / _mosaicWidthPx!).ceil(); //列数
        int mosaicRows = (picHeight.toDouble() / _mosaicHeightPx!).ceil(); //行数
        Uint8List mosaicArray = Uint8List(mosaicRows * mosaicColumns * 4);
        int middleColumns = _mosaicWidthPx! ~/ 2;
        int middleRows = _mosaicHeightPx! ~/ 2;

        for (int i = 0; i < mosaicRows; i++) {
          for (int j = 0; j < mosaicColumns; j++) {
            int columnIndex = min(j * _mosaicWidthPx! + middleColumns, picWidth - 1);
            int rowIndex = min(i * _mosaicHeightPx! + middleRows, picHeight - 1);
            int index = (rowIndex * picWidth + columnIndex) * 4;

            for (int k = 0; k < 4; k++) {
              mosaicArray[(i * mosaicColumns + j) * 4 + k] = value!.getUint8(index + k);
            }
          }
        }
        setState(() {
          _imageRGBBytes = mosaicArray;
        });
      });
    }
  }

  double getMosaicScale(double ration2, Size photoSize){
    double width = _paintImage!.width.toDouble();
    double height = _paintImage!.height.toDouble();
    double xPadding = 0;
    double yPadding = 0;

    double ration1 = width / height;

    if (ration1 > ration2) {
      yPadding = (photoSize.height - photoSize.width / ration1) * 0.5;
    } else {
      xPadding = (photoSize.width - photoSize.height * ration1) * 0.5;
    }
    final size = Size(photoSize.width - xPadding * 2, photoSize.height - yPadding * 2);
    if (ration1 > ration2) {
      return  width / size.width;
    } else {
      return height / size.height;
    }
  }

  void initMosaicInfo(double ration2, Size photoSize) {
    if(_mosaicColumns == null){
      if(widget.asset.editInfo != null){
        _mosaicScale = widget.asset.editInfo!['mosaicScale'];
      }
      _mosaicScale ??= getMosaicScale(ration2,photoSize);
      _mosaicWidthPx = max(2, (_mosaicWidthConst * _mosaicScale!).toInt());
      _mosaicHeightPx = max(2, (_mosaicHeightConst * _mosaicScale!).toInt());
      _mosaicColumns = (_paintImage!.width.toDouble() / _mosaicWidthPx!).ceil();
      if (_mosaics.isNotEmpty || _mosaicsPoints.isNotEmpty) {
        getMosaicData();
      }
    }
  }

  ///马赛克操作

  //获取马赛克方块中的左上角点（比如(3,3)=>(0,0),(13,13)=>(10,10))
  Offset getTopLeftPoint(Offset originalPoint) {
    final int column = originalPoint.dx ~/ _mosaicWidthPx!;
    final int row = originalPoint.dy ~/ _mosaicHeightPx!;
    return Offset(column * _mosaicWidthPx!.toDouble(), row * _mosaicHeightPx!.toDouble());
  }

  //添加移动点
  void addMovePoint(Offset offset, StateSetter setState, Size? contentSize) {
    double mosaicRadius = _mosaicRadiusRatio * _mosaicWidthPx!;
        // _mosaicRadius / _photoScale!;

    double radiusSquare = mosaicRadius * mosaicRadius;

    final lastElement = _mosaics.last;
    lastElement.points.add(offset);
    int mosaicPointLen = _mosaicsPoints.length;
    if (lastElement.points.length > 1) {
      addOriginalPoint(lastElement, contentSize!,mosaicRadius, radiusSquare);
    }

    final addedNumber = _mosaicsPoints.length - mosaicPointLen;

    ///有新增点，则绘制
    if (addedNumber > 0) {
      lastElement.validPointNumber += addedNumber;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void addPointToMosaics(Offset offset) {
    final pt = getTopLeftPoint(offset);
    if (!_mosaicsPoints.contains(pt)) {
      _mosaicsPoints.add(pt);
    }
  }

  /// 添加原始点
  void addOriginalPoint(_MosaicModel model, Size size, double mosaicRadius, double radiusSquare) {
    Offset curPoints0 = model.points[model.points.length - 2];
    Offset curPoints1 = model.points.last;
    int intervalX = (_mosaicWidthPx! * 0.5).ceil();
    // (_mosaicWidth! * 0.5).ceil();
    int intervalY =  (_mosaicHeightPx! * 0.5).ceil();
        // (_mosaicHeight! * 0.5).ceil();

    ///添加最后的点
    addPointToMosaics(curPoints1);
    addRadiusPoints(curPoints1, size, intervalX, intervalY, mosaicRadius, radiusSquare);

    /// y=kx+b 计算直线上经过的点
    double offsetDx = curPoints1.dx - curPoints0.dx;
    double offsetDy = curPoints1.dy - curPoints0.dy;
    double k = offsetDx == 0 ? 0 : offsetDy / offsetDx;
    double b = curPoints1.dy - k * curPoints1.dx;

    if (offsetDx.abs() > offsetDy.abs()) {
      int minX = min(curPoints1.dx, curPoints0.dx).toInt();
      int maxX = max(curPoints1.dx, curPoints0.dx).toInt();
      for (int i = minX + 1; i < maxX; i += intervalX) {
        Offset offset = Offset(i.toDouble(), (k * i + b).floor().toDouble());
        addPointToMosaics(offset);
        addRadiusPoints(offset, size, intervalX, intervalY,mosaicRadius, radiusSquare);
      }
    } else {
      int minY = min(curPoints1.dy, curPoints0.dy).toInt();
      int maxY = max(curPoints1.dy, curPoints0.dy).toInt();
      for (int i = minY + 1; i < maxY; i += intervalY) {
        Offset offset = Offset(
            k == 0 ? curPoints0.dx : ((i - b) / k).floor().toDouble(),
            i.toDouble());
        addPointToMosaics(offset);
        addRadiusPoints(offset, size, intervalX, intervalY, mosaicRadius, radiusSquare);
      }
    }
  }

  ///添加半径点

  void addRadiusPoints(Offset point,Size size,int intervalX,int intervalY,double mosaicRadius,double radiusSquare) {

    ///圆的公式 : (x-a)^2 + (y-b)^2 <= r^2
    double xLeft = max(0, point.dx - mosaicRadius);
    double xRight = min(point.dx + mosaicRadius, size.width - 1);

    double yTop = min(point.dy + mosaicRadius, size.height - 1);
    double yBottom = max(0, point.dy - mosaicRadius);
    double leftScope = point.dx - intervalX;
    double rightScope = point.dx + intervalX;

    for (int i = xLeft.toInt(); i <= xRight.toInt(); i++) {
      if (i >= leftScope && i <= rightScope) continue;

      //y轴上下限
      double squareValue = (i - point.dx);

      double sqrtValue = sqrt(max(0, radiusSquare - squareValue * squareValue));
      double y0 = min(yTop, point.dy + sqrtValue);

      double y1 = max(yBottom, point.dy - sqrtValue);

      for (int j = y1.toInt(); j <= y0.toInt(); j += intervalY) {
        final offset = Offset(i.toDouble(), j.toDouble());
        addPointToMosaics(offset);
      }
    }
  }

  void addText(double density) {
    if (!mounted) {
      return;
    }
    setState(() {
      _showOptionBar = false;
    });

    final page = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
        child: const _PhotoAddTextWidget());

    Navigator.of(context).push<Map>(
        _PhotoPopupRoute(
            child: widget.isCupertinoType ? CupertinoPageScaffold(backgroundColor: Colors.transparent,child: page,) :
            Scaffold(
              body: page,
              backgroundColor: Colors.transparent,
            )
    )).then((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _showOptionBar = true;
        if (value != null && value.isNotEmpty) {
          _textList.add(_TextModel(value,density,offset: Offset(_imageCutOffset.dx + _imageCutSize!.width * 0.5,_imageCutOffset.dy + _imageCutSize!.height * 0.5)));
        }
      });
    });
  }

  void modifyText(_TextModel? model) {
    stopTimer();
    if (!mounted) {
      return;
    }
    setState(() {
      model!.showOperationFrame = false;
      _showOptionBar = false;
      model.shouldShow = false;
    });

    final page = _PhotoAddTextWidget(textInfo: model!.textInfo,);
    Navigator.of(context).push<Map>(_PhotoPopupRoute(
        child:widget.isCupertinoType ? CupertinoPageScaffold(
          backgroundColor: Colors.transparent,
          child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),child: page),
        ):
        Scaffold(
          backgroundColor: Colors.transparent,
          body: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),child: page),
        )
    )).then((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _showOptionBar = true;
        model.shouldShow = true;
        if (value != null) {
          if (value.isNotEmpty) {
            model.textInfo = value;
          } else {
            _textList.remove(model);
          }
        }
      });
    });
  }

  ///文本编辑状态消失定时器

  void stopTimer() {
    _txtModifyTimer?.cancel();
    _txtModifyTimer = null;
  }

  void startTimer() {
    stopTimer();
    assert(_txtModifyTimer == null);
    _txtModifyTimer = Timer(const Duration(seconds: _textTimerDuration), () {
      _txtModifyTimer = null;
      if (!mounted) {
        return;
      }
      for (final txtModel in _textList) {
        if (txtModel.showOperationFrame) {
          txtModel.showOperationFrame = false;
          break;
        }
      }
      setState(() {
        _showOptionBar = true;
      });
    });
  }

  void showOperationFrame(int index, _TextModel model) {
    if (!mounted) {
      return;
    }
    if (!model.showOperationFrame) {
      //保证只有唯一被选中操作的文本
      if (_textList.length > 1) {
        for (final txtModel in _textList) {
          if (txtModel.showOperationFrame) {
            txtModel.showOperationFrame = false;
            break;
          }
        }
      }

      setState(() {
        _showOptionBar = false;
        _txtScaling = false;
        if (_textList.last != model) {
          _textList.remove(model);
          _textList.add(model);
        }
        model.showOperationFrame = true;
      });
    }
    startTimer();
  }

  ///检查是否已经进入了删除区域
  void checkMoveInRemoveBar(Offset globalOffset) {
    final box = _removeBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      if (box.hasSize) {
        var localPosition = box.globalToLocal(globalOffset);
        if (box.paintBounds.contains(localPosition)) {
          if (!_isPanInRemoveBtn) {
            _isPanInRemoveBtn = true;
          }
        } else {
          //当从删除控件中移走，需要让删除控件隐藏
          if (_isPanInRemoveBtn) {
            _isPanInRemoveBtn = false;
            _showRemoveBar = false;
          }
        }
      }
    }
  }

  void toCutImage(double width,double imagePixelDensity) async{
    RenderRepaintBoundary boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    if (_heroImage != null) {
      _heroImage!.dispose();
    }
    _heroImage = await boundary.toImage(pixelRatio: width / boundary.size.width);
    if(!mounted){
      return;
    }
    _MosaicCutModel? cutMosaicList;
    if (_mosaicsPoints.isNotEmpty) {
      cutMosaicList = _MosaicCutModel(
          imageRGBBytes: _imageRGBBytes,
          mosaicList: _mosaicsPoints,
          mosaicColumns: _mosaicColumns,
          mosaicWidth: _mosaicWidthPx!.toDouble(),
          mosaicHeight: _mosaicHeightPx!.toDouble());
    }

    _photoController?.reset();

    final page =  Material(
      color: Colors.transparent,
      child: _CutPhotoView(
        image: _paintImage!,
        repaintImage: _heroImage!,
        quarterTurns: _quarterTurns,
        lines: _lines,
        cutMosaicList: cutMosaicList,
        cutTextList: _textList,
        imageTopLeft: _imageCutOffset,
        imageCutSize: _imageCutSize,
      ),
    );

    Navigator.of(context).push<Map>(
        PageRouteBuilder<Map>(pageBuilder:(context, animation1, animation2) {
          return widget.isCupertinoType ? CupertinoPageScaffold(backgroundColor: Colors.black,child:page) :
          Scaffold(
            backgroundColor: Colors.black,
            body: page,
          );
        })
    ).then((cutInfo){
      if (cutInfo != null) {
        resetImageInfoWithCutInfo(cutInfo);
      }
    });
  }

  void resetImageInfoWithCutInfo(Map cutInfo){
    Rect cutRect = cutInfo['rect'];
    final cutHeroImage = cutInfo['hero'];
    final int quarterTurns = cutInfo['quarterTurns'];
    if (cutHeroImage != null) {
      _heroImage?.dispose();
      _heroImage = cutHeroImage;
    }
    if (mounted && (quarterTurns != _quarterTurns || cutRect.size != _imageCutSize || cutRect.topLeft != _imageCutOffset)) {
      setState(() {
        _imageCutSize = cutRect.size;
        _imageCutOffset = cutRect.topLeft;
        _quarterTurns = quarterTurns;
      });
    }
  }

  Offset convertTextOffset(Offset offset,[bool toImage = true]){
    Offset ret;
    if(_quarterTurns == 0){
      ret = Offset(offset.dx, offset.dy);
    }else if(_quarterTurns == 1 || _quarterTurns == -3){
      ret = toImage ? Offset(offset.dy, -offset.dx) : Offset(-offset.dy, offset.dx);
    }else if(_quarterTurns.abs() == 2){
      ret = Offset(-offset.dx , -offset.dy);
    }else{
      ret = toImage ? Offset(-offset.dy , offset.dx ) : Offset(offset.dy, -offset.dx);
    }
    return ret;
  }

  void textPanStart(DragStartDetails detail,double density){
    if (_findNeedMoveIndex != -1) {
      if (!mounted) return;
      _textBeginMove = true;
      final txtModel = _textList[_findNeedMoveIndex];
      txtModel.shouldClip = false;
      if (_textList.last != txtModel) {
        _currentMoveIndex = _findNeedMoveIndex;
      }
      setState(() {
        _showOptionBar = false;
        _showRemoveBar = true;
        txtModel.offset += convertTextOffset((detail.globalPosition - txtModel.leftTop) * density / _photoScale!);
      });
      txtModel.leftTop = detail.globalPosition;
    }
  }

  void textPanUpdate(DragUpdateDetails detail,double density){
    if (_findNeedMoveIndex != -1) {
      if (!mounted) return;
      //判断是否需要删除
      checkMoveInRemoveBar(detail.globalPosition);
      final txtModel = _textList[_findNeedMoveIndex];
      setState(() {
        txtModel.offset += convertTextOffset((detail.globalPosition - txtModel.leftTop) * density / _photoScale!);
      });
      txtModel.leftTop = detail.globalPosition;
    }
  }

  void textPanCancel(Size photoSize,double xPadding,double yPadding,double density){
    if (!mounted) return;
    if (_textBeginMove) {
      _textBeginMove = false;
      if (!_showOptionBar || _showRemoveBar) {
        setState(() {
          _showOptionBar = true;
          _showRemoveBar = false;
          _isPanInRemoveBtn = false;
        });
      }
      if (_findNeedMoveIndex != -1) {
        //检查是否超过图像不能显示，如果越界，则不让移动
        final txtModel = _textList[_findNeedMoveIndex];
        RenderBox? box = txtModel.key.currentContext?.findRenderObject() as RenderBox?;

        box ??= _currentMoveKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          if (box.hasSize) {
            if (yPadding > 0 || xPadding > 0) {
              RenderRepaintBoundary? boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
              if (boundary == null || !boundary.hasSize) {
                if (kDebugMode) {
                  print('error at check edge with no bundary !!!!');
                }
                return;
              }
              //转换文本所占的rect
              var txtRect = MatrixUtils.transformRect(box.getTransformTo(boundary),box.paintBounds).inflate(-10);
              if (txtRect.isEmpty) {
                txtRect.inflate(10);
              }
              if (!boundary.paintBounds.overlaps(txtRect)) {
                txtModel.offset = Offset(_imageCutOffset.dx + _imageCutSize!.width*0.5,_imageCutOffset.dy + _imageCutSize!.height*0.5);
              }
            }
          }
        }
        txtModel.shouldClip = true;
        _findNeedMoveIndex = -1;
        if (_currentMoveIndex != -1) _currentMoveIndex = -1;
        setState(() {});
      }
    } else if (_findNeedMoveIndex != -1) {
      _findNeedMoveIndex = -1;
    }
  }

  void textPanEnd(double xPadding,double yPadding){
    if (!mounted) return;
    if (_textBeginMove) {
      if (_findNeedMoveIndex != -1) {
        final txtModel = _textList[_findNeedMoveIndex];
        //移除文本
        if (_showRemoveBar && _isPanInRemoveBtn) {
          _textList.remove(txtModel);
        } else {
          RenderBox? box = txtModel.key.currentContext?.findRenderObject() as RenderBox?;

          box ??= _currentMoveKey.currentContext?.findRenderObject() as RenderBox?;
          if (box != null) {
            if (box.hasSize) {
              if (yPadding > 0 || xPadding > 0) {
                RenderRepaintBoundary? boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                if (boundary == null || !boundary.hasSize) {
                  if (kDebugMode) {
                    print('error at check edge with no bundary !!!!');
                  }
                  return;
                }
                //转换文本所占的rect
                var txtRect = MatrixUtils.transformRect(box.getTransformTo(boundary),box.paintBounds).inflate(-10);
                if (txtRect.isEmpty) {
                  txtRect.inflate(10);
                }
                if (!boundary.paintBounds.overlaps(txtRect)) {
                  txtModel.offset = Offset(_imageCutOffset.dx + _imageCutSize!.width*0.5,_imageCutOffset.dy + _imageCutSize!.height*0.5);
                }
              }
            }
          }
          txtModel.shouldClip = true;
          _findNeedMoveIndex = -1;
          if (_currentMoveIndex != -1) {
            final txtModel = _textList[_currentMoveIndex];
            _currentMoveIndex = -1;
            _textList.remove(txtModel);
            _textList.add(txtModel);
          }
        }
      }

      if (!_showOptionBar || _showRemoveBar) {
        _showOptionBar = true;
        _showRemoveBar = false;
        _isPanInRemoveBtn = false;
      }
      setState(() {});
    } else if (_findNeedMoveIndex != -1) {
      _findNeedMoveIndex = -1;
    }
  }


  void mosaicPanStart(DragStartDetails details,double density){
    if (_opIndex == 0) {
      final model = _LineModel(color:_textColorList[_colorIndex],density: density, strokeWidth: 5.0 / _photoScale!);
      _lines.add(model);
    } else {
      _mosaics.add(_MosaicModel());
    }
    setState(() {
      _showOptionBar = false;
      _showBackButton = false;
    });
  }

  void mosaicPanUpdate(DragUpdateDetails details,BuildContext ctx,StateSetter state){
    RenderBox referenceBox = ctx.findRenderObject() as RenderBox;
    Offset localPosition = referenceBox.globalToLocal(details.globalPosition);
    if (_opIndex == 0) {
      if (_lines.isNotEmpty) {
        final dx = max(0.0, min(localPosition.dx,ctx.size!.width));
        final dy = max(0.0, min(localPosition.dy,ctx.size!.height));
        final unitDx = (_imageCutSize == null ? _paintImage!.width : _imageCutSize!.width) / ctx.size!.width;
        //转换为图片像素点
        state(() {
          _lines.last.points.add(Offset(dx * unitDx + _imageCutOffset.dx,dy * unitDx + _imageCutOffset.dy));
        });
      }
    } else {
      if (localPosition.dy >= 0 && localPosition.dx >= 0 && localPosition.dy <= ctx.size!.height
          &&localPosition.dx <= ctx.size!.width) {
        if (_mosaics.isNotEmpty) {
          final dx = max(0.0, min(localPosition.dx,ctx.size!.width));
          final dy = max(0.0, min(localPosition.dy,ctx.size!.height));
          final unitDx = (_imageCutSize == null ? _paintImage!.width : _imageCutSize!.width) / ctx.size!.width;

          addMovePoint( Offset(dx * unitDx + _imageCutOffset.dx,dy * unitDx + _imageCutOffset.dy),state, ctx.size);
        }
      }
    }
  }

  void mosaicPanEnd(){
    if (_opIndex == 0) {
      if (_lines.isNotEmpty && (_lines.last.points.isEmpty || _lines.last.points.length < 2)) {
        _lines.removeLast();
      }
    } else {
      if (_mosaics.isNotEmpty && (_mosaics.last.points.isEmpty || _mosaics.last.points.length < 2)) {
        _mosaics.removeLast();
      }
    }
    setState(() {
      _showOptionBar = true;
      _showBackButton = true;
    });
  }


  //文本旋转缩放操作
  void textScaleStart(ScaleStartDetails detail,_TextModel opModel){
    opModel.scaleTemp = opModel.scale;
    opModel.rotateTemp = opModel.rotate;
    opModel.leftTop = detail.focalPoint;
    stopTimer();
    setState(() {
      _txtScaling = true;
    });
  }

  void textScaleUpdate(ScaleUpdateDetails detail,_TextModel opModel){
    if (!mounted) return;
    setState(() {
      opModel.scale = opModel.scaleTemp * detail.scale;
      //判定文本最小缩放倍数
      if (opModel.scale < _textMinScale) {
        opModel.scale = _textMinScale;
      }
      opModel.rotate = opModel.rotateTemp + detail.rotation;

      final repaintSize = _repaintKey.currentContext?.size;
      var offset = (detail.focalPoint - opModel.leftTop) / _photoScale!;
      if(repaintSize != null && !repaintSize.isEmpty){
        offset = Offset(offset.dx / repaintSize.width, offset.dy / repaintSize.height);
      }
      opModel.offset += offset;
      opModel.leftTop = detail.focalPoint;
    });
  }

  void textScaleEnd(ScaleEndDetails detail,_TextModel opModel,double xPadding,double yPadding){
    if (!mounted) return;

    startTimer();

    setState(() {

      _txtScaling = false;

      //判定是否越界
      RenderBox? box = opModel.key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        if (box.hasSize) {
          if (yPadding > 0 || xPadding > 0) {
            RenderRepaintBoundary? boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
            if (boundary == null || !boundary.hasSize) {
              if (kDebugMode) {
                print('error at check edge with no bundary !!!!');
              }
              return;
            }
            //转换文本所占的rect
            var txtRect = MatrixUtils.transformRect(box.getTransformTo(boundary),box.paintBounds).inflate(-10);
            if (txtRect.isEmpty) {
              txtRect = txtRect.inflate(10);
            }
            if (!boundary.paintBounds.overlaps(txtRect)) {
              opModel.offset = Offset.zero;
            }
          }
        }
      }
    });
  }


  //保存
  void saveImage() async{
    if (_lines.isEmpty && _mosaics.isEmpty && _textList.isEmpty && _imageCutSize!.width == _paintImage!.width &&
        _imageCutSize!.height.toInt() == _paintImage!.height.toInt() && _imageCutOffset == Offset.zero) {
      widget.assetChanged(true);
      Navigator.of(context).pop();
      return;
    }

    double width =  _quarterTurns.abs().isOdd ? _imageCutSize!.height : _imageCutSize!.width;

    RenderRepaintBoundary? boundary = _repaintKey.currentContext?.findRenderObject()
    as RenderRepaintBoundary?;
    if (boundary == null) {
      if (kDebugMode) {
        print('error at get image with no bundary !!!!');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _showSaveTips = true;
      });
    }
    final image = await boundary.toImage( pixelRatio: width / boundary.size.width);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if(byteData == null){
      if (mounted) {
        setState(() {
          _showSaveTips = false;
        });
        AssetToast.show('保存失败!', context,
            gravity: AssetToast.CENTER,
            backgroundRadius: 8);
      }

      return;
    }

    final fileInfo = await AssetPicker.rawDataToJpgFile(
        getUrlMd5(widget.asset.identifier),
        Platform.isIOS ? byteData.buffer.asUint8List() : byteData.buffer.asInt32List(),
        image.width,
        image.height,
        thumbWidth: 300,
        thumbHeight: 300,
        quality: 70);
    if (mounted) {
      setState(() {
        _showSaveTips = false;
      });
    }
    if (fileInfo == null) {
      if(mounted){
        AssetToast.show('保存失败!', context, gravity: AssetToast.CENTER, backgroundRadius: 8);
      }
      return;
    }

    final editInfo = Map.of(fileInfo);
    List<_TextCutModel> cutTextList = [];

    for (final txtModel in _textList) {
      cutTextList.add(_TextCutModel(
          txtModel.textInfo,
          txtModel.pixelDensity,
          txtModel.scale,
          txtModel.rotate,
          txtModel.offset,
          txtModel.showOperationFrame,
          shouldClip: txtModel.shouldClip));
    }
    editInfo['txt'] = cutTextList;
    editInfo['mosaics'] = _mosaics;
    editInfo['mosaicsPoints'] = _mosaicsPoints;
    if(_mosaics.isNotEmpty && _mosaicScale != null){
      editInfo['mosaicScale'] = _mosaicScale;
    }
    editInfo['lines'] = _lines;
    editInfo['quarterTurns'] = _quarterTurns;
    editInfo['cut'] = {'offset': _imageCutOffset,'size': _imageCutSize };
    widget.asset.editInfo = editInfo;
    widget.assetChanged(false);
    if(mounted){
      Navigator.of(context).pop();
    }

  }

  @override
  void initState() {
    super.initState();
    _indexData = ValueNotifier('1');
    _photoController = PhotoViewController()..outputStateStream.listen(listener);
    getImageData();
  }

  @override
  Widget build(BuildContext context) {
    Widget mainWidget;
    if (_paintImage == null || (widget.asset.editInfo != null && (_mosaics.isNotEmpty || _mosaicsPoints.isNotEmpty) && _imageRGBBytes == null)) {
      mainWidget = Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(child: widget.asset.editInfo != null && widget.asset.editInfo!['path'] != null ? AssetOriginalImage(
                asset: widget.asset,
              fit: BoxFit.contain,
            ) :
            Builder(
              builder: (_) {
                final queryData = MediaQuery.of(context);
                final picWidth = queryData.devicePixelRatio * queryData.size.width * 0.2;
                return AssetThumbImage(asset: widget.asset, width: picWidth.toInt(),
                  boxFit: BoxFit.contain,backgroundColor: Colors.transparent,);
              },
            )),
            Center(
              child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                      color: const Color(0x77FFFFFF),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // CupertinoActivityIndicator(),
                      Padding(
                        padding: EdgeInsets.only(top: 5),
                      ),
                      Text(
                        '加载中',style: TextStyle(fontSize: 14,color: CupertinoColors.darkBackgroundGray),
                      )
                    ],
                  )),
            )
          ],
        ),
      );
    } else {
      final queryData = MediaQuery.of(context);
      final photoSize = Size(queryData.size.width, queryData.size.height);
      double xPadding = 0;
      double yPadding = 0;

      final absQuarterTurns = _quarterTurns.abs();

      double width =  absQuarterTurns.isOdd ? _imageCutSize!.height : _imageCutSize!.width;
      double height = absQuarterTurns.isOdd ? _imageCutSize!.width : _imageCutSize!.height;

      double ration1 = width / height;
      double ration2 = photoSize.width / photoSize.height;

      double imageMaxScale = 3.5;
      double totalPixel = width * height;
      if (totalPixel < 100000) {
        imageMaxScale = 1.0;
      } else {
        imageMaxScale = max(1, min(3.5, totalPixel / 120000));
      }

      if (ration1 > ration2) {
        yPadding = (photoSize.height - photoSize.width / ration1) * 0.5;
      } else {
        xPadding = (photoSize.width - photoSize.height * ration1) * 0.5;
      }

      final repaintSize = Size(photoSize.width-xPadding * 2,photoSize.height - yPadding * 2);

      final imagePixelDensity = repaintSize.width == 0 ? 1.0 : width / repaintSize.width;

      mainWidget = Stack(
        children: <Widget>[
          Positioned.fill(
              child: ClipRect(
                child: PhotoView.customChild(
                  data: _indexData,
                  childSize: photoSize,
                  customSize: photoSize,
                  minScale: PhotoViewComputedScale.contained * 1.0,
                  maxScale: PhotoViewComputedScale.contained * imageMaxScale,
                  initialScale: PhotoViewComputedScale.contained,
                  // heroAttributes:
                  //     const PhotoViewHeroAttributes(tag: "pic_mosaic"),
                  controller: _photoController,
                  child: _TextSpanGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (detail) {
                      bool onTapText = false;
                      for (final txtModel in _textList.reversed) {
                        final box = txtModel.key.currentContext?.findRenderObject() as RenderBox?;
                        if (box != null) {
                          if (box.hasSize) {
                            var localPosition = box.globalToLocal(detail.globalPosition);
                            if (box.paintBounds.contains(localPosition)) {
                              final tapIndex = _textList.indexOf(txtModel);
                              onTapText = true;
                              showOperationFrame(tapIndex, txtModel);
                              break;
                            }
                          }
                        }
                      }
                      if (!onTapText && mounted) {
                        setState(() {
                          _showBackButton = !_showBackButton;
                          _showOptionBar = _showBackButton;
                        });
                      }
                    },
                    shouldPan: (event) {
                      if (event is PointerDownEvent) {
                        for (final txtModel in _textList.reversed) {
                          final box = txtModel.key.currentContext?.findRenderObject() as RenderBox?;
                          if (box != null) {
                            if (box.hasSize) {
                              var localPosition = box.globalToLocal(event.position);
                              if (box.paintBounds.contains(localPosition)) {
                                return true;
                              }
                            }
                          }
                        }
                      }
                      return false;
                    },
                    onPanDown: (detail) {
                      _textBeginMove = false;
                      for (final txtModel in _textList.reversed) {
                        final box = txtModel.key.currentContext?.findRenderObject()
                        as RenderBox?;
                        if (box != null) {
                          if (box.hasSize) {
                            var localPosition = box.globalToLocal(detail.globalPosition);
                            if (box.paintBounds.contains(localPosition)) {
                              txtModel.leftTop = detail.globalPosition;
                              _findNeedMoveIndex = _textList.indexOf(txtModel);
                              break;
                            }
                          }
                        }
                      }
                    },
                    onPanStart: _textList.isEmpty ? null : (detail)=>textPanStart(detail,imagePixelDensity),
                    onPanUpdate: (_textList.isEmpty) ? null : (detail)=>textPanUpdate(detail,imagePixelDensity),
                    onPanCancel: () => textPanCancel(photoSize, xPadding, yPadding,imagePixelDensity),
                    onPanEnd: (_) => textPanEnd(xPadding, yPadding),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(xPadding, yPadding, xPadding, yPadding),
                      child: Hero(
                        flightShuttleBuilder: (ar1, ar2, ar3, ar4, ar5) {
                          return _heroImage != null
                              ? RawImage(
                            image: _heroImage,
                            fit: BoxFit.contain,
                          ) : const SizedBox();
                        },
                        tag: 'cutImage',
                        child: RepaintBoundary(
                          key: _repaintKey,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              //图片
                              Positioned.fill(
                                  child: RotatedBox(
                                    quarterTurns: _quarterTurns,
                                    child: CustomPaint(
                                      painter: _CutImagePainter(
                                          _paintImage!,
                                          _imageCutOffset,
                                          Size(_imageCutSize!.width,_imageCutSize!.height)),
                                    ),
                                  )),
                              //马赛克以及涂鸦
                              Positioned.fill(child: RotatedBox(
                                quarterTurns: _quarterTurns,
                                child: StatefulBuilder(
                                  builder: (ctx, state) {
                                    final customPaintWidget = ClipRect(
                                      child: CustomPaint(
                                        painter: _ScrawlPainter(
                                            lines: _lines,
                                            mosaicList: _mosaicsPoints,
                                            mosaicColumns: _mosaicColumns,
                                            mosaicWidth: _mosaicWidthPx!.toDouble(),
                                            mosaicHeight: _mosaicHeightPx!.toDouble(),
                                            imageUnit: 1/imagePixelDensity,
                                            cutOffset: _imageCutOffset,
                                            imageRGBBytes: _imageRGBBytes),
                                      ),
                                    );
                                    return (_opIndex == -1 || (_opIndex == 1 && _imageRGBBytes == null))
                                      ? customPaintWidget
                                      : GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanStart: (details)=>mosaicPanStart(details,imagePixelDensity),
                                      onPanUpdate: (details) =>mosaicPanUpdate(details,ctx,state),
                                      onPanEnd: (details) => mosaicPanEnd(),
                                      onPanCancel: () {
                                        if (_opIndex == 0) {
                                          if (_lines.isNotEmpty && (_lines.last.points.isEmpty || _lines.last.points.length < 2)) {
                                            _lines.removeLast();
                                          }
                                        } else {
                                          if (_mosaics.isNotEmpty && (_mosaics.last.points.isEmpty || _mosaics.last.points.length < 2)) {
                                            _mosaics.removeLast();
                                          }
                                        }
                                      },
                                      child: customPaintWidget);
                                  },
                                ),
                              )),
                              //添加的文本
                              ..._textList
                                  .where((element) => element.shouldShow)
                                  .map((txtModel) {
                                int? txtColorType = txtModel.textInfo['colorType'];
                                int? txtColorIndex = txtModel.textInfo['colorIndex'];
                                final offset = (txtModel.offset - _imageCutOffset - Offset(_imageCutSize!.width*0.5,_imageCutSize!.height*0.5)) / imagePixelDensity;
                                final translationMatrix = Matrix4.translationValues(
                                    offset.dx , offset.dy , 0.0);
                                final angleMatrix = Matrix4.identity();
                                angleMatrix[0] = angleMatrix[5] = cos(txtModel.rotate);
                                angleMatrix[1] = sin(txtModel.rotate);
                                angleMatrix[4] = -sin(txtModel.rotate);

                                final txtScale = txtModel.scale * txtModel.pixelDensity / imagePixelDensity;

                                final scaleMatrix = Matrix4.identity();
                                scaleMatrix[0] = scaleMatrix[5] = txtScale;
                                final txtWidget = Transform(
                                    transform: translationMatrix * scaleMatrix * angleMatrix,
                                    alignment: Alignment.center,
                                    child: OverflowBox(
                                        maxHeight: double.maxFinite,
                                        maxWidth: photoSize.width - 32,
                                        child: AssetBGText(
                                          txtModel.textInfo['text'],
                                          key: txtModel.key,
                                          overflow: TextOverflow.clip,
                                          backgroundColor: txtModel.showOperationFrame ? Colors.cyan : txtColorType == 0
                                              ? null
                                              : _textColorList[txtColorIndex!].withAlpha(210),
                                          style: TextStyle(
                                            // backgroundColor:txtColorType == 0 ? null : textColorList[txtColorIndex].withAlpha(210),
                                              shadows: (txtColorType == 1 || txtColorIndex == 1)? null : <Shadow>[
                                                const Shadow(offset: Offset(0, 1.5),blurRadius: 2,color: Color.fromARGB(255, 75, 75, 75),
                                                ),
                                              ],
                                              color: txtColorType == 0
                                                  ? _textColorList[txtColorIndex!]
                                                  : txtColorIndex == 0 ? Colors.black : Colors.white,
                                              fontSize: textFontSize),
                                        )));
                                // print('_heroScale:$_heroScale');
                                return RotatedBox(quarterTurns: _quarterTurns,child: txtModel.shouldClip &&
                                    !txtModel.showOperationFrame
                                    ? ClipRect(
                                    child: Container(
                                      padding:
                                      const EdgeInsets.only(left: 31, right: 31),
                                      child: Visibility(
                                          visible: _currentMoveIndex != _textList.indexOf(txtModel),
                                          child: txtWidget),
                                    ))
                                    : Container(
                                  padding:
                                  const EdgeInsets.only(left: 31, right: 31),
                                  child: Visibility(
                                      visible: _currentMoveIndex != _textList.indexOf(txtModel),
                                      child: txtWidget),
                                ),);
                              }).toList(),

                              if (_textList.isNotEmpty && _currentMoveIndex != -1)
                                RotatedBox(
                                  quarterTurns: _quarterTurns,
                                  child: Builder(
                                    builder: (ctx) {
                                      final txtModel = _textList[_currentMoveIndex];
                                      int? txtColorType = txtModel.textInfo['colorType'];
                                      int? txtColorIndex = txtModel.textInfo['colorIndex'];
                                      final translationMatrix = Matrix4.translationValues(
                                          txtModel.offset.dx,
                                          txtModel.offset.dy,
                                          0.0);
                                      final angleMatrix = Matrix4.identity();
                                      angleMatrix[0] =
                                      angleMatrix[5] = cos(txtModel.rotate);
                                      angleMatrix[1] = sin(txtModel.rotate);
                                      angleMatrix[4] = -sin(txtModel.rotate);

                                      final scaleMatrix = Matrix4.identity();
                                      scaleMatrix[0] = scaleMatrix[5] = txtModel.scale;

                                      final txtWidget = Container(
                                          transform: translationMatrix *
                                              scaleMatrix *
                                              angleMatrix,
                                          transformAlignment: Alignment.center,
                                          child: OverflowBox(
                                              maxHeight: double.maxFinite,
                                              maxWidth: photoSize.width - 32,
                                              child: AssetBGText(
                                                txtModel.textInfo['text'],
                                                key: _currentMoveKey,
                                                backgroundColor: txtColorType == 0
                                                    ? null
                                                    : _textColorList[txtColorIndex!]
                                                    .withAlpha(210),
                                                style: TextStyle(
                                                  // backgroundColor:txtColorType == 0 ? null : textColorList[txtColorIndex].withAlpha(210),
                                                    shadows: (txtColorType == 1 ||
                                                        txtColorIndex == 1)
                                                        ? null
                                                        : <Shadow>[
                                                      const Shadow(
                                                        offset: Offset(0, 1.5),
                                                        blurRadius: 2,
                                                        color: Color.fromARGB(
                                                            255, 75, 75, 75),
                                                      ),
                                                    ],
                                                    color: txtColorType == 0
                                                        ? _textColorList[
                                                    txtColorIndex!]
                                                        : txtColorIndex == 0
                                                        ? Colors.black
                                                        : Colors.white,
                                                    fontSize: textFontSize),
                                              )));
                                      return Container(
                                        padding: const EdgeInsets.only(left: 31, right: 31),
                                        child: txtWidget,
                                      );
                                    },
                                  ),
                                )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )),

          //文本旋转缩放
          if (_textList.isNotEmpty)
            Positioned.fill(
              child: Builder(
                builder: (ctx) {
                  _TextModel? opModel;
                  for (final txtModel in _textList) {
                    if (txtModel.showOperationFrame) {
                      opModel = txtModel;
                      break;
                    }
                  }
                  return opModel == null
                      ? const SizedBox()
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: ()=>modifyText(opModel),
                          onScaleStart: (detail) =>textScaleStart(detail, opModel!),
                          onScaleEnd: (detail) => textScaleEnd(detail, opModel!, xPadding, yPadding),
                          onScaleUpdate: (detail) => textScaleUpdate(detail, opModel!),
                          child: Center(child: _txtScaling ? null : ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: BackdropFilter(
                                      filter: ui.ImageFilter.blur(
                                          sigmaX: 2, sigmaY: 2),
                                      child: Container(
                                          color: Colors.black.withAlpha(100),
                                          // width: 180,
                                          // height: 80,
                                          padding: const EdgeInsets.only(left: 10,top: 5,bottom: 10,right: 5),
                                          child: Stack(children: [
                                            const Padding(
                                              padding: EdgeInsets.only(right: 25.0,top: 10),
                                              child: Text('点击编辑文本\n拖拽缩放旋转',style: TextStyle(fontSize: 20,color: Colors.white,),),
                                            ),
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: SizedBox(
                                                width: 25,
                                                height: 25,
                                                child:  CupertinoButton(
                                                  onPressed: () {
                                                    stopTimer();
                                                    if (!mounted) return;
                                                    setState(() {
                                                      opModel!.showOperationFrame = false;
                                                      _showOptionBar = true;
                                                    });
                                                  },
                                                  padding: EdgeInsets.zero,
                                                  child: const Icon(Icons.cancel_outlined,color: Colors.white,size: 25,),
                                                ),
                                              )
                                            )
                                          ]))))),
                        );
                },
              ),
            ),
          Positioned(bottom: 0,left: 0,right: 0,
            child: Visibility(
              visible: _showOptionBar,
              child: Stack(
                children: [
                  Positioned.fill(child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xB0000000), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0,right: 16),
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_opIndex == 0)
                            SizedBox(
                              height: 45,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  for (int i = 0; i < _textColorList.length; i++)
                                    GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          if (!mounted) return;
                                          if (_colorIndex != i) {
                                            setState(() {
                                              _colorIndex = i;
                                            });
                                          }
                                        },
                                        child: SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: Transform.scale(
                                              scale: _colorIndex == i ? 1.2 : 1,
                                              child: Center(
                                                  child: ClipOval(
                                                    child: Container(
                                                      height: 17,
                                                      width: 17,
                                                      color: Colors.white,
                                                      padding: const EdgeInsets.all(2),
                                                      child: ClipOval(
                                                        child: Container(
                                                          color: _textColorList[i],
                                                        ),
                                                      ),
                                                    ),
                                                  ))),
                                        )),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (!mounted) return;
                                      if (_lines.isNotEmpty) {
                                        setState(() {
                                          _lines.removeLast();
                                        });
                                      }
                                    },
                                    child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: Image.asset('images/pre_cancel.png',width: 30,height: 30, package: 'asset_picker',),
                                    ),
                                  )
                                ],
                              ),
                            )
                          else if (_opIndex == 1)
                            Container(
                              height: 45,
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (!mounted) return;
                                  if (_mosaics.isNotEmpty) {
                                    final item = _mosaics.last;
                                    int number = item.validPointNumber;
                                    _mosaics.removeLast();
                                    if (_mosaics.isEmpty) {
                                      if (_mosaicsPoints.isNotEmpty) {
                                        setState(() {
                                          _mosaicsPoints.clear();
                                        });
                                      }
                                    } else if (number > 0) {
                                      if (_mosaicsPoints.length >
                                          item.validPointNumber) {
                                        setState(() {
                                          _mosaicsPoints.removeRange(_mosaicsPoints.length -item.validPointNumber,_mosaicsPoints.length);
                                        });
                                      } else {
                                        setState(() {
                                          _mosaicsPoints.clear();
                                        });
                                        _mosaics.clear();
                                      }
                                    }
                                  }
                                },
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: Image.asset('images/pre_cancel.png',width: 30,height: 30,package: 'asset_picker',),
                                ),
                              ),
                            )
                          else
                            const SizedBox(
                              height: 45,
                            ),
                          SizedBox(
                            height: 60,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (mounted) {
                                      setState(() {
                                        _opIndex = _opIndex != 0 ? 0 : -1;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    padding: const EdgeInsets.all(5),
                                    child: Image.asset('images/scrawl.png',package: 'asset_picker',color: _opIndex == 0 ? Colors.green : Colors.white,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: ()=>addText(imagePixelDensity),
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      padding: const EdgeInsets.all(5),
                                      child: Image.asset('images/txt.png',package: 'asset_picker',),
                                    )),
                                GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: ()=>toCutImage(width,imagePixelDensity),
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      padding: const EdgeInsets.all(5),
                                      child: Image.asset(
                                        'images/cut.png',
                                        package: 'asset_picker',
                                      ),
                                    )),
                                GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (mounted) {
                                        if (_opIndex != 1) {
                                          //获取rgb数据
                                          getMosaicData();
                                        }
                                        setState(() {
                                          _opIndex = _opIndex != 1 ? 1 : -1;
                                        });
                                      }
                                    },
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      padding: const EdgeInsets.all(5),
                                      child: Image.asset('images/mosaic.png',
                                          package: 'asset_picker',
                                          color: _opIndex == 1
                                              ? Colors.green
                                              : Colors.white),
                                    )),
                                CupertinoButton(
                                  onPressed: saveImage,
                                  padding: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
                                  color: Colors.green,
                                  minSize: 25,
                                  borderRadius: BorderRadius.circular(5),
                                  child: const Text('完成',style: TextStyle(fontSize: 15, color: Colors.white),
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          if (_showRemoveBar)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                    child: Container(
                  width: 160,
                  height: 85,
                  key: _removeBarKey,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: _isPanInRemoveBtn
                          ? Colors.redAccent
                          : Colors.grey[850]!.withAlpha(180),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Icon(
                            _isPanInRemoveBtn ? Icons.delete_forever : Icons.delete,
                            color: Colors.white,
                            size: 25,
                          )),
                      Text(
                        _isPanInRemoveBtn ? '松手即可删除' : '拖动到此处删除',
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                      )
                    ],
                  ),
                )),
              ),
            ),
        ],
      );
    }

    final child = Stack(
      children: [
        Positioned.fill(
          child: mainWidget,
        ),
        if (_showBackButton)
          Positioned(
            left: 10,
            child: SafeArea(
                top: true,
                child: CupertinoButton(
                  color: Colors.black54,
                  onPressed: () => Navigator.of(context).pop(),
                  minSize: 35,
                  padding: const EdgeInsets.all(4),
                  child: Image.asset('images/md_cancel.png',width: 28,height: 28,package: 'asset_picker',),
                )),
          ),
        if (_showSaveTips)
          Positioned.fill(
              child: Container(
                color: Colors.black12,
                child: Center(
                  child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                          color: const Color(0x77FFFFFF),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CupertinoActivityIndicator(),
                          Padding(padding: EdgeInsets.only(top: 5),),
                          Text('保存中',style: TextStyle(fontSize: 14,color: CupertinoColors.darkBackgroundGray),
                          )
                        ],
                      )),
                ),
              )),
      ],
    );

    return widget.isCupertinoType ? CupertinoPageScaffold(resizeToAvoidBottomInset: false, child: child)
        :
    Scaffold(
      resizeToAvoidBottomInset: false,
      body: child,
    );
  }

  ///文本编辑状态消失定时器

  @override
  void dispose() {
    stopTimer();
    _paintImage?.dispose();
    _heroImage?.dispose();
    super.dispose();
  }
}

class _PhotoAddTextWidget extends StatefulWidget {
  final Map? textInfo; //修改

  const _PhotoAddTextWidget({this.textInfo});

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _PhotoAddTextState();
  }
}

class _PhotoAddTextState extends State<_PhotoAddTextWidget> {
  int? colorIndex = 0;

  int? _colorType = 0; // 0 文本颜色 1 背景颜色

  final TextEditingController _textController = TextEditingController();

  final FocusNode node = FocusNode();

  @override
  void initState() {

    if (widget.textInfo != null) {
      _textController.text = widget.textInfo!['text'];
      _colorType = widget.textInfo!['colorType'];
      colorIndex = widget.textInfo!['colorIndex'];
    }

    node.requestFocus();
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _textController.dispose();
    node.dispose();
    super.dispose();
  }

  void didComplete() {
    Map textInfo = {};
    if (_textController.text.isNotEmpty) {
      textInfo = {
        'text': _textController.text,
        'colorType': _colorType,
        'colorIndex': colorIndex
      };
    }
    Navigator.of(context).pop(textInfo);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: CupertinoButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  padding: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
                  minSize: 25,
                  borderRadius: BorderRadius.circular(5),
                  child: const Text('取消',style: TextStyle(fontSize: 15, color: Colors.white),),
                ),
              ),
              Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: CupertinoButton(
                    onPressed: didComplete,
                    padding: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
                    color: Colors.green,
                    minSize: 25,
                    borderRadius: BorderRadius.circular(5),
                    child:  const Text('完成',style: TextStyle(fontSize: 15, color: Colors.white),),
                  ))
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 25, right: 25, top: 25, bottom: 10),
              child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    node.requestFocus();
                  },
                  child: CupertinoTextField(
                    focusNode: node,
                    textAlignVertical: TextAlignVertical.center,
                    textInputAction: TextInputAction.done,
                    expands: true,
                    onSubmitted: (data) => didComplete(),
                    controller: _textController,
                    decoration: null,
                    maxLines: null,
                    style: TextStyle(
                        backgroundColor: _colorType == 0
                            ? null
                            : _textColorList[colorIndex!],
                        shadows: (_colorType == 1 || colorIndex == 1)
                            ? null
                            : <Shadow>[ const Shadow( offset: Offset(0, 1.5), blurRadius: 2,color: Color.fromARGB(255, 75, 75, 75),),],
                        color: _colorType == 0 ? _textColorList[colorIndex!] : colorIndex == 0 ? Colors.black : Colors.white,
                        fontSize: textFontSize),
                  )),
            ),
          ),
          Container(
            height: 45,
            padding: const EdgeInsets.only(bottom: 15, left: 15, right: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _colorType = (_colorType! + 1) % 2;
                      });
                    },
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Image.asset(
                        _colorType == 0
                            ? 'images/txt_emp.png'
                            : 'images/txt_fill.png',
                        width: 32,
                        height: 32,
                        package: 'asset_picker',
                      ),
                    )),
                for (int i = 0; i < _textColorList.length; i++)
                  GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!mounted) {
                          return;
                        }
                        if (colorIndex != i) {
                          setState(() {
                            colorIndex = i;
                          });
                        }
                      },
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Transform.scale(
                            scale: colorIndex == i ? 1.2 : 1,
                            child: Center(
                                child: ClipOval(
                                  child: Container(
                                    height: 17,
                                    width: 17,
                                    color: Colors.white,
                                    padding: const EdgeInsets.all(2),
                                    child: ClipOval(
                                      child: Container(
                                        color: _textColorList[i],
                                      ),
                                    ),
                                  ),
                                ))),
                      )),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _PhotoPopupRoute<T> extends PopupRoute<T> {
  final Widget child;
  final WidgetBuilder? build;
  final bool _barrierDismissible;
  final Color backgroundColor;

  _PhotoPopupRoute(
      {required this.child,
      this.build,
      this.backgroundColor = Colors.black38,
      bool barrierDismissible = false})
      : _barrierDismissible =
            barrierDismissible; //this.child , this.build 二选一，为了兼容代码

  @override
  Color get barrierColor => this.backgroundColor;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return child;
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 100);
}

const int _maskTimerDuration = 1; //1 秒

class _CutBoxDecoration extends BoxDecoration {
  const _CutBoxDecoration({
    Color? color,
    DecorationImage? image,
    Border? border,
    BorderRadius? borderRadius,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
    BlendMode? backgroundBlendMode,
    BoxShape shape = BoxShape.rectangle,
  })  : assert(
            backgroundBlendMode == null || color != null || gradient != null,
            "backgroundBlendMode applies to BoxDecoration's background color or "
            'gradient, but no color or gradient was provided.'),
        super(
            color: color,
            image: image,
            border: border,
            borderRadius: borderRadius,
            boxShadow: boxShadow,
            gradient: gradient,
            backgroundBlendMode: backgroundBlendMode,
            shape: shape);

  /// Creates a copy of this object but with the given fields replaced with the
  /// new values.
  @override
  _CutBoxDecoration copyWith({
    Color? color,
    DecorationImage? image,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
    BlendMode? backgroundBlendMode,
    BoxShape? shape,
  }) {
    return _CutBoxDecoration(
      color: color ?? this.color,
      image: image ?? this.image,
      border: border as Border? ?? this.border as Border?,
      borderRadius:
          borderRadius as BorderRadius? ?? this.borderRadius as BorderRadius?,
      boxShadow: boxShadow ?? this.boxShadow,
      gradient: gradient ?? this.gradient,
      backgroundBlendMode: backgroundBlendMode ?? this.backgroundBlendMode,
      shape: shape ?? this.shape,
    );
  }

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) {
    // TODO: implement hitTest

    return false;
  }
}

class _EdgePoint {
  //原始对称值（由于都是居中的，所以只保留两个值）
  Offset originOffset;

  double left;
  double right;
  double top;
  double bottom;

  _EdgePoint({
    this.left = 0,
    this.right = 0,
    this.top = 0,
    this.bottom = 0,
    this.originOffset = Offset.zero});

  void setPointFromLRTB(double dx, double dy) {
    left = dx;
    right = dx;
    top = dy;
    bottom = dy;
    originOffset = Offset(dx, dy);
  }

  bool get isNonZero =>
      left != 0.0 || right != 0.0 || top != 0.0 || bottom != 0.0;

  void addEdge(_EdgePoint edgePoint) {
    left += edgePoint.left;
    right += edgePoint.right;
    top += edgePoint.top;
    bottom += edgePoint.bottom;
    _removeNegative();
  }

  void _removeNegative() {
    if (left < 0) {
      left = 0;
    }
    if (right < 0) {
      right = 0;
    }
    if (top < 0) {
      top = 0;
    }
    if (bottom < 0) {
      bottom = 0;
    }
  }

  void reduceEdge(_EdgePoint edgePoint) {
    left -= edgePoint.left;
    right -= edgePoint.right;
    top -= edgePoint.top;
    bottom -= edgePoint.bottom;
    _removeNegative();
  }
}

class _CutImagePainter extends CustomPainter {
  final ui.Image image;
  final Offset? offset;
  final Size imageSize;
  final Paint imagePaint = Paint()..filterQuality = FilterQuality.low;

  _CutImagePainter(this.image, this.offset, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    FittedSizes fittedSizes = applyBoxFit(BoxFit.contain, imageSize, size);

    Rect inputRect = Alignment.center.inscribe(fittedSizes.source, offset! & imageSize);
// 获得一个绘制区域内，指定大小的，居中位置处的 Rect
    Rect outputRect = Alignment.center.inscribe(fittedSizes.destination, Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawImageRect(image, inputRect, outputRect, imagePaint);
  }

  @override
  bool shouldRepaint(covariant _CutImagePainter oldDelegate) {

    return oldDelegate.image != image || oldDelegate.offset != offset;
  }
}

class _CutScrawlPainter extends CustomPainter {
  late final Paint _linePaint;
  late final Paint _mosaicPaint;
  final double unitDx; //现单位像素密度      width/pixel
  final List<_LineModel>? lines;
  final _MosaicCutModel? cutMosaicList;

  _CutScrawlPainter(
      {required this.lines,
      required this.cutMosaicList,
      required this.unitDx}) {
    _linePaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _mosaicPaint = Paint()..strokeWidth = 1;
  }

  /// 通过imageRGBBytes和图片大小，控件大小，获取控件相应点的马赛克颜色
  /// point 控件坐标 Size 画布大小

  Color getPointColor(Offset point) {
    Color pointColor;
    int picX = point.dx ~/ cutMosaicList!.mosaicWidth!;
    int picY = point.dy ~/ cutMosaicList!.mosaicHeight!;
    int colorIndex = (picY * cutMosaicList!.mosaicColumns! + picX) * 4;

    assert(colorIndex + 3 < cutMosaicList!.imageRGBBytes!.length,
        'color index error');
    pointColor = Color.fromARGB(
        cutMosaicList!.imageRGBBytes![colorIndex + 3],
        cutMosaicList!.imageRGBBytes![colorIndex],
        cutMosaicList!.imageRGBBytes![colorIndex + 1],
        cutMosaicList!.imageRGBBytes![colorIndex + 2]);

    return pointColor;
  }

  @override
  void paint(Canvas canvas, Size size) {

    //画马赛克
    if (cutMosaicList != null && cutMosaicList!.imageRGBBytes != null && cutMosaicList!.imageRGBBytes!.length > 2) {
      for (final offset in cutMosaicList!.mosaicList!) {
        canvas.drawRect(
            Rect.fromLTWH(
                offset.dx * unitDx,
                offset.dy * unitDx,
                cutMosaicList!.mosaicWidth!* unitDx,
                cutMosaicList!.mosaicHeight!* unitDx),
            _mosaicPaint..color = getPointColor(offset));
      }
    }

    //画涂鸦
    if (lines != null && lines!.isNotEmpty) {
      for (int i = 0; i < lines!.length; i++) {
        List<Offset> curPoints = lines![i].points;
        if (curPoints.isEmpty) {
          continue;
        }
        _linePaint.color = lines![i].color;
        _linePaint.strokeWidth = lines![i].strokeWidth * unitDx * lines![i].density;
        Path path = Path();
        path.fillType = PathFillType.nonZero;

        path.moveTo(curPoints[0].dx * unitDx, curPoints[0].dy * unitDx);
        for (int i = 1; i < curPoints.length; i++) {
          path.lineTo(curPoints[i].dx * unitDx, curPoints[i].dy * unitDx);
        }
        canvas.drawPath(path, _linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_CutScrawlPainter other) {
    return true;
  }
}

class _CutPhotoView extends StatefulWidget {
  final ui.Image image;
  final Offset? imageTopLeft;
  final Size? imageCutSize;

  final ui.Image repaintImage;

  final int quarterTurns;

  final List<_LineModel>? lines;

  final List<_TextModel>? cutTextList;

  final _MosaicCutModel? cutMosaicList;

  const _CutPhotoView(
      {
        Key? key,
        required this.image,
        required this.quarterTurns,
        required this.repaintImage,
        this.imageTopLeft,
        this.imageCutSize,
        this.lines,
        this.cutTextList,
        this.cutMosaicList})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _CutPhotoViewState();
  }
}

class _CutPhotoViewState extends State<_CutPhotoView> with TickerProviderStateMixin {
  late Size photoSize;

  Size? _screenSize;

  double scale = 1.0; //缩放倍数
  late double scaleTemp; //记录开始缩放时的当前缩放倍数

  // double rotate = 0.0;  //旋转角度
  // double rotateTemp; //记录开始旋转时的当前旋转度数

  Offset? offset = Offset.zero; //偏移量
  late Offset offsetTemp; //开始拖动前的左上角坐标

  // int _imageRotate = 0;

  late int quarterTurns;

  Offset? preOffsetTemp;

  double minScale = 1.0;
  double maxScale = 3.0;

  static const double dynamicMinScale = 0.3;
  static const  double dynamicMaxScale = 3.5;

  Size? oriImageSize;
  double? _imageRatio; //图片本身宽高比
  double? _photoRatio; //图片可用最大空间宽高比

  late Offset _oriFramePoint; //初始边框边距，用于计算图片偏移量

  late Size imageSize;

  AnimationController? _positionAnimationController;
  late Animation<Offset> _positionAnimation;

  AnimationController? _scaleAnimationController;
  late Animation<double> _scaleAnimation;

  // AnimationController _rotateAnimationController;
  // Animation<double> _rotateAnimation;

  bool didPushed = false;

  late double _sideTempValue; //各边开始拖动前的值

  late Offset _cornerTempValue; //各个角开始拖动前的值

  final GlobalKey _frameKey = GlobalKey();
  final _edgePoint = _EdgePoint();
  bool shouldAnimated = false;

  bool maskShouldAnimated = true;

  late Rect _gridRect;

  bool _showMask = true; //是否显示蒙版

  Timer? _maskTimer;

  final GlobalKey _imageKey = GlobalKey();

  final GlobalKey _imageContainerKey = GlobalKey();

  ui.Image? heroImage;

  ///文本编辑状态消失定时器

  void stopTimer() {
    _maskTimer?.cancel();
    _maskTimer = null;
  }

  void startTimer() {
    stopTimer();
    assert(_maskTimer == null);
    _maskTimer = Timer(const Duration(seconds: _maskTimerDuration), () {
      _maskTimer = null;
      if (!_showMask) {
        setState(() {
          _showMask = true;
        });
      }
    });
  }

  void initParam(Size contentSize,EdgeInsets safeSize){
    if (widget.imageCutSize == Size(widget.image.width.toDouble(),widget.image.height.toDouble())) {
      //原始大小不需要调整
      _edgePoint.setPointFromLRTB(_oriFramePoint.dx, _oriFramePoint.dy);
      _gridRect = Rect.fromLTWH(_edgePoint.left + 14,_edgePoint.top + safeSize.top + 14,oriImageSize!.width + 4,oriImageSize!.height + 4);
    }
    else {
      setParam(contentSize, safeSize, widget.imageCutSize!, widget.imageTopLeft!);
    }
  }

  void setParam(Size contentSize,EdgeInsets safeSize,Size imageCutSize,Offset imageTopLeft){

    final absQuarterTurns = (quarterTurns%4).abs();
    final cutImageRatio = absQuarterTurns.isOdd ? imageCutSize.height / imageCutSize.width  :  imageCutSize.width / imageCutSize.height;
    Size cutImageSize;
    if (cutImageRatio > _photoRatio!) {
      cutImageSize = Size(imageSize.width, imageSize.width / cutImageRatio);
    } else {
      cutImageSize = Size(imageSize.height * cutImageRatio, imageSize.height);
    }


    final cutImageOffset = Offset((imageSize.width - cutImageSize.width) * 0.5, (imageSize.height - cutImageSize.height) * 0.5);

    _edgePoint.setPointFromLRTB(cutImageOffset.dx, cutImageOffset.dy);
    final cutDensity = cutImageSize.width / (absQuarterTurns.isOdd ? imageCutSize.height : imageCutSize.width);
    scale = cutDensity * (absQuarterTurns.isOdd ? widget.image.height : widget.image.width) / oriImageSize!.width;

    final cutOriDx = cutImageOffset.dx - _oriFramePoint.dx;
    final cutOriDy = cutImageOffset.dy - _oriFramePoint.dy;
    final scaleOffset = oriImageSize! * (scale - 1) * 0.5;

    if (_imageRatio != _photoRatio) {
      if (_imageRatio! > _photoRatio!) {
        if (_imageRatio! > cutImageRatio) {
          minScale = (imageSize.height - _edgePoint.top * 2) / oriImageSize!.height;
        }
      } else {
        if (_imageRatio! < cutImageRatio) {
          minScale = (imageSize.width - _edgePoint.left * 2) / oriImageSize!.width;
        }
      }
    }

    if(absQuarterTurns == 0){
      offset = Offset(
        cutOriDx - imageTopLeft.dx * cutDensity + scaleOffset.width,
        cutOriDy - imageTopLeft.dy * cutDensity + scaleOffset.height,
      );
    }else if(absQuarterTurns == 1){  // pi/2
      offset = Offset(
        cutOriDx - max(0.0, widget.image.height - imageTopLeft.dy - imageCutSize.height) * cutDensity + scaleOffset.width,
        cutOriDy - imageTopLeft.dx * cutDensity + scaleOffset.height,
      );
    }else if(absQuarterTurns == 2){  // pi
      offset = Offset(
        cutOriDx - max(0.0, widget.image.width - imageTopLeft.dx - imageCutSize.width) * cutDensity + scaleOffset.width,
        cutOriDy - max(0.0, widget.image.height - imageTopLeft.dy - imageCutSize.height) * cutDensity + scaleOffset.height,
      );
    }else{    // 3pi/2
      offset = Offset(
        cutOriDx - imageTopLeft.dy * cutDensity + scaleOffset.width,
        cutOriDy - max(0.0, widget.image.width - imageTopLeft.dx - imageCutSize.width) * cutDensity + scaleOffset.height,
      );
    }
    _gridRect = Rect.fromLTWH(
        _edgePoint.left + 14,
        _edgePoint.top + safeSize.top + 14,
        cutImageSize.width + 4,
        cutImageSize.height + 4);
  }

  void updateParam(Size contentSize,EdgeInsets safeSize,Size oriImageSize,Offset oriFramePoint,int preQuarterTurns){

    final scaleSize = oriImageSize * scale;
    final Size maxOffset = oriImageSize * (scale - 1) * 0.5 - offset! as Size;

    Rect rect = Rect.fromLTWH(-maxOffset.width,
        -maxOffset.height,scaleSize.width, scaleSize.height);

    Rect rect1 = Rect.fromLTWH(
        _edgePoint.left - oriFramePoint.dx,
        _edgePoint.top - oriFramePoint.dy,
        _gridRect.width - 4,
        _gridRect.height - 4);

    final absQuarterTurns = (preQuarterTurns%4).abs();

    double ratio = (absQuarterTurns.isOdd ? widget.image.height : widget.image.width ) / scaleSize.width;

    int left;
    int width;
    int top;
    int height;

    if(absQuarterTurns == 0){
      left = max(0, ((rect1.topLeft.dx - rect.topLeft.dx) * ratio).toInt());
      width = (rect1.width * ratio).toInt();
      top = max(0, ((rect1.topLeft.dy - rect.topLeft.dy) * ratio).toInt());
      height = (rect1.height * ratio).toInt();
    }else if(absQuarterTurns == 1){  // pi/2
      height = (rect1.width * ratio).toInt();
      top = max<int>(0,widget.image.height - max<int>(0, ((rect1.topLeft.dx - rect.topLeft.dx) * ratio).toInt()) - height);

      width = (rect1.height * ratio).toInt();
      left = max(0, ((rect1.topLeft.dy - rect.topLeft.dy) * ratio).toInt());
    }else if(absQuarterTurns == 2){  // pi
      width = (rect1.width * ratio).toInt();
      height = (rect1.height * ratio).toInt();
      left = max<int>(0,widget.image.width - max<int>(0, ((rect1.topLeft.dx - rect.topLeft.dx) * ratio).toInt()) - width);
      top = max<int>(0,widget.image.height - max<int>(0, ((rect1.topLeft.dy - rect.topLeft.dy) * ratio).toInt()) - height);

    }else{    // 3pi/2
      height = (rect1.width * ratio).toInt();
      top = max<int>(0, ((rect1.topLeft.dx - rect.topLeft.dx) * ratio).toInt());

      width = (rect1.height * ratio).toInt();
      left = max<int>(0,widget.image.width - max<int>(0, ((rect1.topLeft.dy - rect.topLeft.dy) * ratio).toInt()) - width);
    }

    int dix = width + left - widget.image.width;
    if (dix > 0) {
      if (kDebugMode) {
        print('width error:$dix');
      }
      width -= dix;
    }
    dix = height + top - widget.image.height;
    if (dix > 0) {
      if (kDebugMode) {
        print('height error:$dix');
      }
      height -= dix;
    }
    setParam(contentSize, safeSize, Size(width.toDouble(), height.toDouble()), Offset(left.toDouble(), top.toDouble()));
  }


  void updatePosition(int preQuarterTurns){

    final queryData = MediaQuery.of(context);

    final contentSize = queryData.size;
    final safeSize = queryData.padding;

    final preOriSize = oriImageSize;

    final priOriFramePoint = _oriFramePoint;

    final absQuarterTurns = (quarterTurns%4).abs();

    _imageRatio = absQuarterTurns.isOdd ?  widget.image.height / widget.image.width : widget.image.width / widget.image.height;

    _photoRatio = imageSize.width / imageSize.height;

    if (_imageRatio! > _photoRatio!) {
      oriImageSize = Size(imageSize.width, imageSize.width / _imageRatio!);
    } else {
      oriImageSize = Size(imageSize.height * _imageRatio!, imageSize.height);
    }

    _oriFramePoint = Offset((imageSize.width - oriImageSize!.width) * 0.5,
        (imageSize.height - oriImageSize!.height) * 0.5);

    updateParam(contentSize, safeSize,preOriSize!,priOriFramePoint,preQuarterTurns);
  }

  void initPhotoPosition(EdgeInsets safeSize) {

    final contentSize = MediaQuery.of(context).size;

    if (oriImageSize == null || _screenSize != contentSize) {

      final preOriSize = oriImageSize;

      final priOriFramePoint = oriImageSize == null ? null : _oriFramePoint;

      photoSize = Size(contentSize.width, contentSize.height - safeSize.bottom - 61);
      imageSize = Size(photoSize.width - 32, photoSize.height - safeSize.top - 32);

      final absQuarterTurns = (quarterTurns%4).abs();

      _imageRatio = absQuarterTurns.isOdd ?  widget.image.height / widget.image.width : widget.image.width / widget.image.height;

      _photoRatio = imageSize.width / imageSize.height;

      if (_imageRatio! > _photoRatio!) {
        oriImageSize = Size(imageSize.width, imageSize.width / _imageRatio!);
      } else {
        oriImageSize = Size(imageSize.height * _imageRatio!, imageSize.height);
      }

      _oriFramePoint = Offset((imageSize.width - oriImageSize!.width) * 0.5,
          (imageSize.height - oriImageSize!.height) * 0.5);
      if(_screenSize == null){
        initParam(contentSize, safeSize);
      }else{
        updateParam(contentSize, safeSize,preOriSize!,priOriFramePoint!,quarterTurns);
      }
      _screenSize = contentSize;
    }
  }

  void animatePosition(Offset? from, Offset? to) {
    _positionAnimation = Tween<Offset>(begin: from, end: to)
        .animate(_positionAnimationController!);
    _positionAnimationController!
      ..value = 0.0
      ..fling(velocity: 0.4);
  }
  void animateScale(double from, double to) {
    _scaleAnimation = Tween<double>(
      begin: from,
      end: to,
    ).animate(_scaleAnimationController!);
    _scaleAnimationController!
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  //处理图片层拖动缩放手势

  void imageScaleStart(ScaleStartDetails detail) {
    scaleTemp = scale;
    offsetTemp = detail.focalPoint;
    preOffsetTemp = offset;
    _positionAnimationController!.stop();
    _scaleAnimationController!.stop();
    stopTimer();
    setState(() {
      _showMask = false;
    });
  }

  void imageScaleUpdate(ScaleUpdateDetails detail) {
    setState(() {
      scale = scaleTemp * detail.scale;
      //判定最小缩放倍数
      if (scale < dynamicMinScale) {
        scale = dynamicMinScale;
      } else if (scale > dynamicMaxScale) {
        scale = dynamicMaxScale;
      }
      final delta = detail.focalPoint - offsetTemp;
      Offset localOffset = preOffsetTemp!;
      localOffset += delta;
      preOffsetTemp = localOffset;

      final maxOffset = oriImageSize! * (scale - 1) * 0.5 +
          Offset(_edgePoint.left - _oriFramePoint.dx,
              _edgePoint.top - _oriFramePoint.dy);

      final dx = preOffsetTemp!.dx.abs() - maxOffset.width.abs();

      final dy = preOffsetTemp!.dy.abs() - maxOffset.height.abs();

      offset = preOffsetTemp;

      if (dx > 0) {
        if (preOffsetTemp!.dx < 0) {
          offset = Offset(-maxOffset.width.abs() - pow(dx, 0.7), offset!.dy);
        } else {
          offset = Offset(maxOffset.width.abs() + pow(dx, 0.7), offset!.dy);
        }
      }

      if (dy > 0) {
        if (preOffsetTemp!.dy < 0) {
          offset = Offset(offset!.dx, -maxOffset.height.abs() - pow(dy, 0.7));
        } else {
          offset = Offset(offset!.dx, maxOffset.height.abs() + pow(dy, 0.7));
        }
      }
      offsetTemp = detail.focalPoint;
    });
  }

  void imageScaleEnd(ScaleEndDetails detail) {
    startTimer();

    bool scaleChanged = false;

    bool noScale = scaleTemp / scale == 1.0;

    final preScale = scale;

    if (scale < minScale) {
      scale = minScale;
      scaleChanged = true;
    }

    if (scale > maxScale) {
      scale = maxScale;
      scaleChanged = true;
    }

    final Offset? preOffset = offset;

    final double magnitude = detail.velocity.pixelsPerSecond.distance;

    // animate velocity only if there is no scale change and a significant magnitude
    if (noScale && magnitude >= 400.0) {
      final Offset direction = detail.velocity.pixelsPerSecond / magnitude;
      var localOffset = offset!;
      localOffset += direction * 100.0;
      offset = localOffset;
    }

    final maxOffset = oriImageSize! * (scale - 1) * 0.5 +
        Offset(_edgePoint.left - _oriFramePoint.dx,
            _edgePoint.top - _oriFramePoint.dy);

    final dx = offset!.dx.abs() - maxOffset.width.abs();

    final dy = offset!.dy.abs() - maxOffset.height.abs();

    if (dx > 0) {
      if (offset!.dx < 0) {
        offset = Offset(-maxOffset.width.abs(), offset!.dy);
      } else {
        offset = Offset(maxOffset.width.abs(), offset!.dy);
      }
    }

    if (dy > 0) {
      if (offset!.dy < 0) {
        offset = Offset(offset!.dx, -maxOffset.height.abs());
      } else {
        offset = Offset(offset!.dx, maxOffset.height.abs());
      }
    }
    if (offset != preOffset) {
      animatePosition(preOffset, offset);
    }

    if (scaleChanged) {
      animateScale(preScale, scale);
    }
  }

  //旋转
  void rotateImage(bool clockwise){
    setState(() {
      maskShouldAnimated = false;
      final preQuarterTurns = quarterTurns;
      quarterTurns = (quarterTurns + (clockwise ? 1 : -1)) % 4;
      updatePosition(preQuarterTurns);
    });
  }

  //处理四角事件  type -- 0 lt 1 lb 2 rt 3 rb

  void handleCornerPoint(int type, Offset offset) {
    final safeTop = MediaQuery.of(context).padding.top;
    final renderSize = Size(
        photoSize.width - 20 - _edgePoint.left - _edgePoint.right,
        photoSize.height - 20 - safeTop - _edgePoint.top - _edgePoint.bottom);
    // final renderSize = _frameKey.currentContext?.size;

    _EdgePoint edgePointOffset = _EdgePoint();
    if (type == 0) {
      Offset pointOffset = offset - _cornerTempValue;
      final Size size = renderSize - pointOffset as Size;

      edgePointOffset.left = pointOffset.dx;
      edgePointOffset.top = pointOffset.dy;

      if (size.width < 60) {
        edgePointOffset.left -= 60 - size.width;
      }
      if (size.height < 60) {
        edgePointOffset.top -= 60 - size.height;
      }
    } else if (type == 1) {
      Offset pointOffset = offset - _cornerTempValue;
      final Size size =
          renderSize - Offset(pointOffset.dx, -pointOffset.dy) as Size;
      edgePointOffset.left = pointOffset.dx;
      edgePointOffset.bottom = -pointOffset.dy;

      if (size.width < 60) {
        edgePointOffset.left -= 60 - size.width;
      }
      if (size.height < 60) {
        edgePointOffset.bottom -= 60 - size.height;
      }
    } else if (type == 2) {
      Offset pointOffset = _cornerTempValue - offset;
      final Size size =
          renderSize - Offset(pointOffset.dx, -pointOffset.dy) as Size;

      edgePointOffset.right = pointOffset.dx;
      edgePointOffset.top = -pointOffset.dy;

      if (size.width < 60) {
        edgePointOffset.right -= 60 - size.width;
      }
      if (size.height < 60) {
        edgePointOffset.top -= 60 - size.height;
      }
    } else if (type == 3) {
      Offset pointOffset = _cornerTempValue - offset;
      final Size size =
          renderSize - Offset(pointOffset.dx, pointOffset.dy) as Size;
      edgePointOffset.right = pointOffset.dx;
      edgePointOffset.bottom = pointOffset.dy;

      if (size.width < 60) {
        edgePointOffset.right -= 60 - size.width;
      }
      if (size.height < 60) {
        edgePointOffset.bottom -= 60 - size.height;
      }
    }

    if (edgePointOffset.isNonZero) {
      setState(() {
        _edgePoint.addEdge(edgePointOffset);
      });
    }
    _cornerTempValue = offset;
  }

  void handleCornerPanDown(int type, DragDownDetails detail) {
    _cornerTempValue = detail.globalPosition;
  }

  void handleCornerPanStart(int type, DragStartDetails detail) {
    shouldAnimated = false;
    handleCornerPoint(type, detail.globalPosition);
    stopTimer();
    setState(() {
      _showMask = false;
    });
  }

  void handleCornerPanUpdate(int type, DragUpdateDetails detail) {
    handleCornerPoint(type, detail.globalPosition);
  }

  void handleCornerPanEnd(int type, DragEndDetails detail) {
    shouldAnimated = true;
    handleTransition();
  }

  void handleCornerPanCancel(int type) {
    shouldAnimated = true;
    handleTransition();
  }

  //处理四边事件 type -- 0:l 1:t 2:r 3:b

  void handleEdgePoint(int type, Offset offset) {
    double dis = 0.0;
    if (type == 0) {
      dis = offset.dx - _sideTempValue;
    } else if (type == 1) {
      dis = offset.dy - _sideTempValue;
    } else if (type == 2) {
      dis = _sideTempValue - offset.dx;
    } else if (type == 3) {
      dis = _sideTempValue - offset.dy;
    }

    // final renderSize = _frameKey.currentContext?.size;
    final safeTop = MediaQuery.of(context).padding.top;
    final renderSize = Size(
        photoSize.width - 20 - _edgePoint.left - _edgePoint.right,
        photoSize.height - 20 - safeTop - _edgePoint.top - _edgePoint.bottom);
    setState(() {
      if (type == 0) {
        // double dx = offset.dx - _sideTempValue;
        _edgePoint.left += dis;
        if (_edgePoint.left < 0) {
          _edgePoint.left = 0;
        } else {
          double width = renderSize.width - dis;
          if (width < 60) {
            _edgePoint.left -= 60 - width;
          }
        }
      } else if (type == 1) {
        // double dy = offset.dy - _sideTempValue;
        _edgePoint.top += dis;
        if (_edgePoint.top < 0) {
          _edgePoint.top = 0;
        } else {
          double height = renderSize.height - dis;
          if (height < 60) {
            _edgePoint.top -= 60 - height;
          }
        }
      } else if (type == 2) {
        // double dx =  _sideTempValue - offset.dx;

        double width = renderSize.width - dis;
        if (width < 60) {
          _edgePoint.right += renderSize.width - 60;
        } else {
          _edgePoint.right += dis;
          if (_edgePoint.right < 0) {
            _edgePoint.right = 0;
          }
        }
      } else if (type == 3) {
        // double dy = _sideTempValue - offset.dy;
        double height = renderSize.height - dis;
        if (height < 60) {
          _edgePoint.bottom += renderSize.height - 60;
        } else {
          _edgePoint.bottom += dis;
          if (_edgePoint.bottom < 0) {
            _edgePoint.bottom = 0;
          }
        }
      }
    });
    _sideTempValue = (type == 0 || type == 2) ? offset.dx : offset.dy;
  }

  void handleSidePanDown(int type, DragDownDetails detail) {
    _sideTempValue = (type == 0 || type == 2)
        ? detail.globalPosition.dx
        : detail.globalPosition.dy;
  }

  void handleSidePanStart(int type, DragStartDetails detail) {
    shouldAnimated = false;
    handleEdgePoint(type, detail.globalPosition);
    stopTimer();
    setState(() {
      _showMask = false;
    });
  }

  void handleSidePanUpdate(int type, DragUpdateDetails detail) {
    handleEdgePoint(type, detail.globalPosition);
  }

  void handleSidePanEnd(int type, DragEndDetails detail) {
    shouldAnimated = true;
    handleTransition();
  }

  void handleSidePanCancel(int type) {
    shouldAnimated = true;
    handleTransition();
  }

  //处理选择框变化后的移动缩放
  void handleTransition() {
    startTimer();
    final safeTop = MediaQuery.of(context).padding.top;
    final renderSize = Size(
        photoSize.width - 20 - _edgePoint.left - _edgePoint.right,
        photoSize.height - 20 - safeTop - _edgePoint.top - _edgePoint.bottom);
    // final renderSize = _frameKey.currentContext?.size;
    final preOffset = _edgePoint.originOffset;

    //调整图像
    double imageScale = 1;
    double translateX = 0;
    double translateY = 0;

    double preLeft = _edgePoint.left;
    double preRight = _edgePoint.right;
    double preTop = _edgePoint.top;
    double preBottom = _edgePoint.bottom;

    bool widthChanged = preOffset.dx != preLeft || preOffset.dx != preRight;
    bool heightChanged = preOffset.dy != preTop || preOffset.dy != preBottom;

    if (!widthChanged && !heightChanged) return;

    double edgeRatio = (renderSize.width - 12) / (renderSize.height - 12);
    resetEdgePoint(edgeRatio);

    if (widthChanged && heightChanged) {
      //宽高变化 需要缩放
      final translateInfo =
          calculateScaleAndTranslate(preLeft, preRight, preTop, safeTop);
      imageScale = translateInfo[0];
      translateX = translateInfo[1];
      translateY = translateInfo[2];
    } else if (widthChanged) {
      if (preOffset.dx == 0) {
        final translateInfo =
            calculateScaleAndTranslate(preLeft, preRight, preTop, safeTop);
        imageScale = translateInfo[0];
        translateX = translateInfo[1];
        translateY = translateInfo[2];
      } else {
        bool isFromRight = preLeft == preOffset.dx;

        //判定是否超过图片显示范围
        final scaleSize = oriImageSize! * scale;
        final Size maxOffset =
            oriImageSize! * (scale - 1) * 0.5 - offset! as Size;

        Rect rect = Rect.fromLTWH(-maxOffset.width, -maxOffset.height,
            scaleSize.width, scaleSize.height);

        final tapPoint = Offset(
            (isFromRight ? renderSize.width - 12 + preLeft : preLeft) -
                _oriFramePoint.dx,
            0);

        if (rect.contains(tapPoint)) {
          translateX = preLeft == preOffset.dx
              ? _edgePoint.left - preOffset.dx
              : preOffset.dx - _edgePoint.left;
        } else {
          //超过需要缩放

          //计算图片上下超过的总高度，用于移动
          double totalOffset = rect.width - renderSize.width + 12;

          if (isFromRight) {
            if (totalOffset > 0) {
              //不需要缩放，只移动
              translateX =
                  preRight - _edgePoint.right + tapPoint.dx - rect.right;
            } else {
              final totalDx = preLeft + preRight - totalOffset;
              imageScale = (imageSize.width - _edgePoint.left * 2) /
                  (imageSize.width - totalDx);
              //计算缩放后左边偏移量
              final rightScaleDy =
                  (oriImageSize! * (scale * (imageScale - 1))).width * 0.5;
              final rectLeftOffset =
                  max(0, preLeft - _oriFramePoint.dx - rect.left);
              translateX =
                  preRight - _edgePoint.right + rightScaleDy + rectLeftOffset;
            }
          } else {
            if (totalOffset > 0) {
              //不需要缩放，只移动
              translateX = _edgePoint.left - preLeft + tapPoint.dx - rect.left;
            } else {
              final totalDx = preLeft + preRight - totalOffset;
              imageScale = (imageSize.width - _edgePoint.left * 2) /
                  (imageSize.width - totalDx);
              //计算缩放后右边偏移量
              final leftScaleDy =
                  (oriImageSize! * (scale * (imageScale - 1))).width * 0.5;
              final rectRightOffset = max(
                  0,
                  rect.right -
                      (preLeft - _oriFramePoint.dx + renderSize.width - 12));
              translateX =
                  _edgePoint.left - preLeft - leftScaleDy - rectRightOffset;
            }
          }
        }
      }
    } else if (heightChanged) {
      if (preOffset.dy == 0) {
        final translateInfo =
            calculateScaleAndTranslate(preLeft, preRight, preTop, safeTop);
        imageScale = translateInfo[0];
        translateX = translateInfo[1];
        translateY = translateInfo[2];
      } else {
        bool isFromBottom = preTop == preOffset.dy;

        //判定是否超过图片显示范围

        final scaleSize = oriImageSize! * scale;
        final Size maxOffset =
            oriImageSize! * (scale - 1) * 0.5 - offset! as Size;

        Rect rect = Rect.fromLTWH(-maxOffset.width, -maxOffset.height,
            scaleSize.width, scaleSize.height);

        final tapPoint = Offset(
            0,
            (isFromBottom ? renderSize.height - 12 + preTop : preTop) -
                _oriFramePoint.dy);

        if (rect.contains(tapPoint)) {
          translateY = isFromBottom
              ? _edgePoint.top - preOffset.dy
              : preOffset.dy - _edgePoint.top;
        } else {
          //超过需要缩放

          //计算图片上下超过的总高度，用于移动
          double totalOffset = rect.height - renderSize.height + 12;
          if (isFromBottom) {
            if (totalOffset > 0) {
              //不需要缩放，只移动
              translateY =
                  preBottom - _edgePoint.bottom + tapPoint.dy - rect.bottom;
            } else {
              final totalDy = preTop + preBottom - totalOffset;
              imageScale = (imageSize.height - _edgePoint.top * 2) /
                  (imageSize.height - totalDy);
              //计算缩放后底部偏移量
              final bottomScaleDy =
                  (oriImageSize! * (scale * (imageScale - 1))).height * 0.5;
              final rectTopOffset =
                  max(0, preTop - _oriFramePoint.dy - rect.top);
              translateY =
                  preBottom - _edgePoint.bottom + bottomScaleDy + rectTopOffset;
            }
          } else {
            if (totalOffset > 0) {
              //不需要缩放，只移动
              translateY = _edgePoint.top - preTop + tapPoint.dy - rect.top;
            } else {
              final totalDy = preTop + preBottom - totalOffset;
              imageScale = (imageSize.height - _edgePoint.top * 2) /
                  (imageSize.height - totalDy);
              //计算缩放后顶部偏移量
              final topScaleDy =
                  (oriImageSize! * (scale * (imageScale - 1))).height * 0.5;
              final rectBottomOffset = max(
                  0,
                  rect.bottom -
                      (preTop - _oriFramePoint.dy + renderSize.height - 12));
              translateY =
                  _edgePoint.top - preTop - topScaleDy - rectBottomOffset;
            }
          }
        }
      }
    }

    if (imageScale != 1) {
      animateScale(scale, scale * imageScale);
    }
    if (translateX != 0 || translateY != 0) {
      animatePosition(offset, offset! + Offset(translateX, translateY));
    }

    if (_imageRatio != _photoRatio) {
      if (_imageRatio! >= _photoRatio!) {
        minScale = 1;
        if (_imageRatio! > edgeRatio) {
          minScale =
              (imageSize.height - _edgePoint.top * 2) / oriImageSize!.height;
        }
      } else {
        minScale = 1;
        if (_imageRatio! < edgeRatio) {
          minScale =
              (imageSize.width - _edgePoint.left * 2) / oriImageSize!.width;
        }
      }
    }
  }

  //处理缩放逻辑
  List<double> calculateScaleAndTranslate(double preLeft,double preRight,double preTop,double safeTop,) {
    final imageScale = (imageSize.width - _edgePoint.left * 2) /
        (imageSize.width - preLeft - preRight);
    double translateX = 0;
    double translateY = 0;

    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      var localPosition = box.globalToLocal(Offset(preLeft + 16, preTop + safeTop + 16));
      final global = MatrixUtils.transformPoint(getImageNextScaleMatrix(box, scale * imageScale,box.parent!.parent!.parent!.parent!.parent!.parent as RenderObject?),localPosition);
      translateX = _edgePoint.left - global.dx + 16;
      translateY = _edgePoint.top - global.dy + safeTop + 16;
    }
    return [imageScale, translateX, translateY];
  }

  ///当边框变化引起图片缩放获取缩放后的变换矩阵

  Matrix4 getImageNextScaleMatrix(RenderBox box, double nextScale, RenderObject? ancestor) {
    bool hasAncestor = ancestor != null;
    if (!hasAncestor) {
      // final AbstractNode? rootNode = box.owner!.rootNode;
      final  rootNode = box.owner!.rootNode;
      if (rootNode is RenderObject) ancestor = rootNode;
    }
    final List<RenderObject?> renderers = <RenderObject?>[];
    for (RenderObject? renderer = box; renderer != ancestor; renderer = renderer?.parent) {
      assert(renderer != null); // Failed to find ancestor in parent chain.
      renderers.add(renderer);
    }
    if (hasAncestor) {
      renderers.add(ancestor);
    }

    final Matrix4 transform = Matrix4.identity();
    for (int index = renderers.length - 1; index > 0; index -= 1) {
      if (index == 3) {
        RenderTransform renderTransform = renderers[index] as RenderTransform;

        final matrix = Matrix4.identity()
          ..translate(offset!.dx, offset!.dy)
          ..scale(nextScale);

        Matrix4 effectiveTransform;
        final Alignment? resolvedAlignment =
            renderTransform.alignment?.resolve(renderTransform.textDirection);
        if (renderTransform.origin == null && resolvedAlignment == null) {
          effectiveTransform = matrix;
        } else {
          final Matrix4 result = Matrix4.identity();
          if (renderTransform.origin != null) {
            result.translate(renderTransform.origin!.dx, renderTransform.origin!.dy);
          }
          late Offset translation;
          if (resolvedAlignment != null) {
            translation = resolvedAlignment.alongSize(renderTransform.size);
            result.translate(translation.dx, translation.dy);
          }
          result.multiply(matrix);
          if (resolvedAlignment != null) {
            result.translate(-translation.dx, -translation.dy);
          }
          if (renderTransform.origin != null) {
            result.translate(-renderTransform.origin!.dx, -renderTransform.origin!.dy);
          }
          effectiveTransform = result;
        }
        transform.multiply(effectiveTransform);
      } else {
        renderers[index]!.applyPaintTransform(renderers[index - 1]!, transform);
      }
    }
    return transform;
  }

  void resetEdgePoint(double ration) {
    double xPadding = 0;
    double yPadding = 0;
    double ration2 = imageSize.width / (imageSize.height);

    if (ration > ration2) {
      yPadding = (imageSize.height - imageSize.width / ration) * 0.5;
    } else {
      xPadding = (imageSize.width - imageSize.height * ration) * 0.5;
    }
    _edgePoint.setPointFromLRTB(xPadding, yPadding);
    _gridRect = Rect.fromLTWH(
        xPadding + 14,
        _edgePoint.top + MediaQuery.of(context).padding.top + 14,
        imageSize.width - (xPadding - 2) * 2,
        imageSize.height - (yPadding - 2) * 2);
  }

  ///完成裁剪

  void didCompleteCut() async {
    final renderSize = _frameKey.currentContext?.size;
    if (renderSize != null && !renderSize.isEmpty) {
      final scaleSize = oriImageSize! * scale;
      final Size maxOffset = oriImageSize! * (scale - 1) * 0.5 - offset! as Size;
      Rect rect = Rect.fromLTWH(-maxOffset.width, -maxOffset.height,
          scaleSize.width, scaleSize.height);

      Rect rect1 = Rect.fromLTWH(
          _edgePoint.left - _oriFramePoint.dx,
          _edgePoint.top - _oriFramePoint.dy,
          renderSize.width - 12,
          renderSize.height - 12);

      final absQuarterTurns = (quarterTurns%4).abs();

      double ratio = (absQuarterTurns.isOdd ? widget.image.height : widget.image.width ) / scaleSize.width;

      int left;
      int width;
      int top;
      int height;

      if(absQuarterTurns == 0){
        width = (rect1.width * ratio).ceil();
        left = max(0, ((rect1.topLeft.dx - rect.topLeft.dx) * ratio).round());
        top = max(0, ((rect1.topLeft.dy - rect.topLeft.dy) * ratio).round());
        height = (rect1.height * ratio).ceil();
      }else if(absQuarterTurns == 1){  // pi/2
        height = (rect1.width * ratio).ceil();
        top = max<int>(0,widget.image.height - max<int>(0, ((rect1.topLeft.dx - rect.topLeft.dx) * ratio).round()) - height);

        width = (rect1.height * ratio).ceil();
        left = max(0, ((rect1.topLeft.dy - rect.topLeft.dy) * ratio).round());
      }else if(absQuarterTurns == 2){  // pi
        width = (rect1.width * ratio).ceil();
        height = (rect1.height * ratio).ceil();
        left = max<int>(0,widget.image.width - max<int>(0, ((rect1.topLeft.dx - rect.topLeft.dx) * ratio).round()) - width);
        top = max<int>(0,widget.image.height - max<int>(0, ((rect1.topLeft.dy - rect.topLeft.dy) * ratio).round()) - height);

      }else{    // 3pi/2
        height = (rect1.width * ratio).ceil();
        top = max<int>(0, ((rect1.topLeft.dx - rect.topLeft.dx) * ratio).round());

        width = (rect1.height * ratio).ceil();
        left = max<int>(0,widget.image.width - max<int>(0, ((rect1.topLeft.dy - rect.topLeft.dy) * ratio).round()) - width);
      }

      if(width >= widget.image.width){
        width = widget.image.width;
        left = 0;
      }

      if(height >= widget.image.height){
        height = widget.image.height;
        top = 0;
      }

      int dix = width + left - widget.image.width;
      if (dix > 0) {
        if (kDebugMode) {
          print('width error:$dix');
        }
        width -= dix;
      }
      dix = height + top - widget.image.height;
      if (dix > 0) {
        if (kDebugMode) {
          print('height error:$dix');
        }
        height -= dix;
      }
      if (widget.quarterTurns != quarterTurns || widget.imageTopLeft!.dx != left ||
          widget.imageTopLeft!.dy != top ||
          widget.imageCutSize!.width != width ||
          widget.imageCutSize!.height != height) {
        final boundary = _imageContainerKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null && boundary.hasSize) {
          //截取图像
          // ignore: invalid_use_of_protected_member
          final OffsetLayer offsetLayer = boundary.layer as OffsetLayer;
          final offsetImage = await offsetLayer.toImage( Offset(_edgePoint.left, _edgePoint.top) & rect1.size, pixelRatio: width / rect1.width);
          heroImage?.dispose();
          heroImage = offsetImage;
        }
        if(mounted){
          Navigator.of(context).pop({
            if(heroImage != null)  'hero': heroImage!.clone(),
            'quarterTurns':quarterTurns,
            'rect': Rect.fromLTWH(left.toDouble(), top.toDouble(),
                width.toDouble(), height.toDouble())
          });
        }

      } else {
        Navigator.of(context).pop();
      }
    } else {
      if (kDebugMode) {
        print('crop image error!');
      }
      Navigator.of(context).pop();
    }
  }

  void resetImage(){
    setState(() {
      maskShouldAnimated = false;
      offset = Offset.zero;
      minScale = 1.0;
      scale = 1.0;
      quarterTurns = 0;
      _imageRatio = widget.image.width / widget.image.height;

      if (_imageRatio! > _photoRatio!) {
        oriImageSize = Size(imageSize.width, imageSize.width / _imageRatio!);
      } else {
        oriImageSize = Size(imageSize.height * _imageRatio!, imageSize.height);
      }

      _oriFramePoint = Offset((imageSize.width - oriImageSize!.width) * 0.5,
          (imageSize.height - oriImageSize!.height) * 0.5);

      _edgePoint.setPointFromLRTB(_oriFramePoint.dx, _oriFramePoint.dy);
      _gridRect = Rect.fromLTWH(
          _edgePoint.left + 14,
          _edgePoint.top + MediaQuery.of(context).padding.top + 14,
          oriImageSize!.width + 4,
          oriImageSize!.height + 4);
    });
  }

  @override
  void initState() {

    quarterTurns = widget.quarterTurns;

    _positionAnimationController = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {
          offset = _positionAnimation.value;
        });
      });
    heroImage?.dispose();

    heroImage = widget.repaintImage.clone();
    _scaleAnimationController = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {
          scale = _scaleAnimation.value;
        });
      });

    super.initState();
  }

  @override
  void didChangeDependencies() {

    var route = ModalRoute.of(context);
    if (route != null && !didPushed) {
      void handler(status) {
        if (status == AnimationStatus.completed) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            if (mounted) {
              setState(() {
                didPushed = true;
              });
            }
          });
        } else if (status == AnimationStatus.reverse) {
          route.animation!.removeStatusListener(handler);
          if (mounted) {
            setState(() {
              didPushed = false;
            });
          }
        }
      }

      route.animation!.addStatusListener(handler);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final safeSize = MediaQuery.of(context).padding;
    initPhotoPosition(safeSize);
    final matrix = Matrix4.identity()
      ..translate(offset!.dx, offset!.dy)
      ..scale(scale);
    final oriImageOffset = ((imageSize - oriImageSize!) as Offset) * 0.5;

    final absQuarterTurns = quarterTurns.abs();
    final density = oriImageSize!.width / (absQuarterTurns.isOdd ? widget.image.height :widget.image.width);

    return Stack(
      alignment: AlignmentDirectional.bottomEnd,
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: photoSize.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (detail) {
                    imageScaleStart(detail);
                  },
                  onScaleUpdate: (detail) {
                    imageScaleUpdate(detail);
                  },
                  onScaleEnd: (detail) {
                    imageScaleEnd(detail);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16).copyWith(top: MediaQuery.of(context).padding.top + 16),
                    child: didPushed ? RepaintBoundary(
                            key: _imageContainerKey,
                            child: Transform(
                                transform: matrix,
                                alignment: Alignment.center,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: RotatedBox(
                                        quarterTurns: quarterTurns,
                                        child: RawImage(
                                          key: _imageKey,
                                          fit: BoxFit.contain,
                                          image: widget.image,
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                        left: oriImageOffset.dx,
                                        right: oriImageOffset.dx,
                                        top: oriImageOffset.dy,
                                        bottom: oriImageOffset.dy,
                                        child: RotatedBox(
                                          quarterTurns: quarterTurns,
                                          child: CustomPaint(
                                            painter: _CutScrawlPainter(
                                                lines: widget.lines,
                                                cutMosaicList: widget.cutMosaicList,
                                                unitDx: density
                                            ),
                                          ),
                                        )),
                                    Positioned.fill(
                                      left: oriImageOffset.dx,
                                      right: oriImageOffset.dx,
                                      top: oriImageOffset.dy,
                                      bottom: oriImageOffset.dy,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          ...widget.cutTextList!.map((txtModel) {
                                            int? txtColorType = txtModel.textInfo['colorType'];
                                            int? txtColorIndex = txtModel.textInfo['colorIndex'];

                                            final angleMatrix = Matrix4.identity();
                                            angleMatrix[0] = angleMatrix[5] = cos(txtModel.rotate);
                                            angleMatrix[1] = sin(txtModel.rotate);
                                            angleMatrix[4] = -sin(txtModel.rotate);

                                            final scaleMatrix = Matrix4.identity();
                                            scaleMatrix[0] = scaleMatrix[5] = txtModel.scale * txtModel.pixelDensity * density;
                                            final offset = (txtModel.offset - Offset(widget.image.width*0.5,widget.image.height*0.5)) * density;
                                            final translationMatrix = Matrix4.translationValues(
                                                offset.dx , offset.dy , 0.0);
                                            return ClipRect(
                                              child: RotatedBox(
                                                quarterTurns: quarterTurns,
                                                child: Transform(
                                                    transform: translationMatrix * scaleMatrix * angleMatrix,
                                                    alignment: Alignment.center,
                                                    child: OverflowBox(
                                                        maxHeight: double.maxFinite,
                                                        child: AssetBGText(
                                                          txtModel.textInfo['text'],
                                                          overflow:TextOverflow.clip,
                                                          backgroundColor: txtModel.showOperationFrame ? Colors.cyan : txtColorType == 0 ? null :
                                                          _textColorList[ txtColorIndex!].withAlpha(210),
                                                          style: TextStyle(
                                                              shadows: (txtColorType == 1 || txtColorIndex == 1) ? null
                                                                  : <Shadow>[ const Shadow( offset:Offset(0,1.5), blurRadius:2,color: Color.fromARGB(255,75,75,75),),],
                                                              color: txtColorType == 0 ? _textColorList[txtColorIndex!]: txtColorIndex == 0 ? Colors.black : Colors.white,
                                                              fontSize:textFontSize),
                                                        ))),
                                              ),
                                            );
                                          })
                                        ],
                                      ),
                                    ),

                                  ],
                                )),
                          )
                        : Hero(
                            tag: 'cutImage',
                            child: RawImage(
                              image: heroImage,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),
              ),

              //边框线
              if (didPushed)
                Positioned.fill(
                  left: 10,
                  right: 10,
                  top: safeSize.top + 10,
                  bottom: 10,
                  child: AnimatedContainer(
                      duration: Duration(milliseconds: shouldAnimated ? 100 : 0),
                      onEnd: ()=>shouldAnimated = false,
                      margin: EdgeInsets.only(
                          left: _edgePoint.left,
                          right: _edgePoint.right,
                          top: _edgePoint.top,
                          bottom: _edgePoint.bottom),
                      child: Stack(
                        key: _frameKey,
                        children: [
                          //画边框线
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: Stack(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      for (int i = 0; i < 4; i++)
                                        const VerticalDivider(width: 1, color: Colors.white),
                                    ],
                                  ),
                                  Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      for (int i = 0; i < 4; i++)
                                        const Divider(height: 1, color: Colors.white),
                                    ],
                                  ),
                                ],
                              )),

                          //画四角线及事件 LT  LB  RT  RB
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: Stack(
                              children: [
                                //画边框虚线
                                Positioned.fill(
                                    child: Container(
                                  decoration: _CutBoxDecoration(
                                      border: Border.all(
                                          color: Colors.black.withOpacity(0.4),
                                          width: 2)),
                                )),
                                Positioned(
                                    top: 0,
                                    left: 0,
                                    width: 20,
                                    height: 20,
                                    child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanDown: (detail) {
                                          handleCornerPanDown(0, detail);
                                        },
                                        onPanStart: (detail) {
                                          handleCornerPanStart(0, detail);
                                        },
                                        onPanUpdate: (detail) {
                                          handleCornerPanUpdate(0, detail);
                                        },
                                        onPanEnd: (detail) {
                                          handleCornerPanEnd(0, detail);
                                        },
                                        onPanCancel: () {
                                          handleCornerPanCancel(0);
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only( right: 4, bottom: 4),
                                          decoration: const BoxDecoration(
                                              border: Border(
                                                  left: BorderSide(
                                                      width: 2,
                                                      color: Colors.white),
                                                  top: BorderSide(
                                                      width: 2,
                                                      color: Colors.white))),
                                        ))),
                                Positioned(
                                    bottom: 0,
                                    left: 0,
                                    width: 20,
                                    height: 20,
                                    child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanDown: (detail) {
                                          handleCornerPanDown(1, detail);
                                        },
                                        onPanStart: (detail) {
                                          handleCornerPanStart(1, detail);
                                        },
                                        onPanUpdate: (detail) {
                                          handleCornerPanUpdate(1, detail);
                                        },
                                        onPanEnd: (detail) {
                                          handleCornerPanEnd(1, detail);
                                        },
                                        onPanCancel: () {
                                          handleCornerPanCancel(1);
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 4, top: 4),
                                          decoration: const BoxDecoration(
                                              border: Border(
                                                  left: BorderSide(
                                                      width: 2,
                                                      color: Colors.white),
                                                  bottom: BorderSide(
                                                      width: 2,
                                                      color: Colors.white))),
                                        ))),
                                Positioned(
                                    top: 0,
                                    right: 0,
                                    width: 20,
                                    height: 20,
                                    child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanDown: (detail) {
                                          handleCornerPanDown(2, detail);
                                        },
                                        onPanStart: (detail) {
                                          handleCornerPanStart(2, detail);
                                        },
                                        onPanUpdate: (detail) {
                                          handleCornerPanUpdate(2, detail);
                                        },
                                        onPanEnd: (detail) {
                                          handleCornerPanEnd(2, detail);
                                        },
                                        onPanCancel: () {
                                          handleCornerPanCancel(2);
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                              left: 4, bottom: 4),
                                          decoration: const BoxDecoration(
                                              border: Border(
                                                  right: BorderSide(
                                                      width: 2,
                                                      color: Colors.white),
                                                  top: BorderSide(
                                                      width: 2,
                                                      color: Colors.white))),
                                        ))),
                                Positioned(
                                    right: 0,
                                    bottom: 0,
                                    width: 20,
                                    height: 20,
                                    child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanDown: (detail) {
                                          handleCornerPanDown(3, detail);
                                        },
                                        onPanStart: (detail) {
                                          handleCornerPanStart(3, detail);
                                        },
                                        onPanUpdate: (detail) {
                                          handleCornerPanUpdate(3, detail);
                                        },
                                        onPanEnd: (detail) {
                                          handleCornerPanEnd(3, detail);
                                        },
                                        onPanCancel: () {
                                          handleCornerPanCancel(3);
                                        },
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(left: 4, top: 4),
                                          decoration: const BoxDecoration(
                                              border: Border(
                                                  right: BorderSide(
                                                      width: 2,
                                                      color: Colors.white),
                                                  bottom: BorderSide(
                                                      width: 2,
                                                      color: Colors.white))),
                                        ))),
                              ],
                            ),
                          ),

                          //四边事件响应 LTRB
                          Positioned(
                            left: 0,
                            top: 20,
                            bottom: 20,
                            child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanDown: (detail) {
                                  handleSidePanDown(0, detail);
                                },
                                onPanStart: (detail) {
                                  handleSidePanStart(0, detail);
                                },
                                onPanUpdate: (detail) {
                                  handleSidePanUpdate(0, detail);
                                },
                                onPanEnd: (detail) {
                                  handleSidePanEnd(0, detail);
                                },
                                onPanCancel: () {
                                  handleSidePanCancel(0);
                                },
                                child: const SizedBox(
                                  height: double.infinity,
                                  width: 20,
                                )),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            top: 0,
                            child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanDown: (detail) {
                                  handleSidePanDown(1, detail);
                                },
                                onPanStart: (detail) {
                                  handleSidePanStart(1, detail);
                                },
                                onPanUpdate: (detail) {
                                  handleSidePanUpdate(1, detail);
                                },
                                onPanEnd: (detail) {
                                  handleSidePanEnd(1, detail);
                                },
                                onPanCancel: () {
                                  handleSidePanCancel(1);
                                },
                                child: const SizedBox(
                                  width: double.infinity,
                                  height: 20,
                                )),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 20,
                            top: 20,
                            child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanDown: (detail) {
                                  handleSidePanDown(2, detail);
                                },
                                onPanStart: (detail) {
                                  handleSidePanStart(2, detail);
                                },
                                onPanUpdate: (detail) {
                                  handleSidePanUpdate(2, detail);
                                },
                                onPanEnd: (detail) {
                                  handleSidePanEnd(2, detail);
                                },
                                onPanCancel: () {
                                  handleSidePanCancel(2);
                                },
                                child: const SizedBox(
                                  height: double.infinity,
                                  width: 20,
                                )),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 0,
                            child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanDown: (detail) {
                                  handleSidePanDown(3, detail);
                                },
                                onPanStart: (detail) {
                                  handleSidePanStart(3, detail);
                                },
                                onPanUpdate: (detail) {
                                  handleSidePanUpdate(3, detail);
                                },
                                onPanEnd: (detail) {
                                  handleSidePanEnd(3, detail);
                                },
                                onPanCancel: () {
                                  handleSidePanCancel(3);
                                },
                                child: const SizedBox(
                                  width: double.infinity,
                                  height: 20,
                                )),
                          ),
                        ],
                      )),
                ),
            ],
          ),
        ),
        //蒙版
        if (_showMask)
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.8),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                      child: Container(
                    decoration: const _CutBoxDecoration(
                      /// 任何颜色均可
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  )),
                  Positioned(
                    left: _gridRect.left,
                    top: _gridRect.top,
                    child: AnimatedContainer(
                      transformAlignment: Alignment.center,
                      duration: Duration(milliseconds: maskShouldAnimated ? 100 : 0),
                      onEnd: ()=>maskShouldAnimated = true,
                      decoration: const _CutBoxDecoration(
                        color: Colors.white,
                        backgroundBlendMode: BlendMode.src,
                      ),
                      width: _gridRect.width,
                      height: _gridRect.height,
                    ),
                  )
                ],
              ),
            ),
          ),
        if (didPushed)
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Divider( height: 1,thickness: 1,color: Colors.grey,),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  height: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                          minSize: 40,
                          padding: EdgeInsets.zero,
                          child: const Icon(
                            Icons.close,
                            size: 30,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          }),
                      CupertinoButton(
                          minSize: 40,
                          padding: EdgeInsets.zero,
                          child: const Icon(
                            Icons.rotate_90_degrees_ccw_rounded,
                            size: 30,
                            color: Colors.white,
                          ),
                          onPressed: () => rotateImage(false)),
                      CupertinoButton(
                          minSize: 40,
                          padding: EdgeInsets.zero,
                          disabledColor: Colors.grey,
                          onPressed: resetImage,
                          child: const Text('还原',style:TextStyle(fontSize: 18, color: Colors.white))),
                      CupertinoButton(
                          minSize: 40,
                          padding: EdgeInsets.zero,
                          child: const Icon(
                            Icons.rotate_90_degrees_cw_outlined,
                            size: 30,
                            color: Colors.white,
                          ),
                          onPressed: () => rotateImage(true)),
                      CupertinoButton(
                          minSize: 40,
                          padding: EdgeInsets.zero,
                          onPressed: didCompleteCut,
                          child: const Icon(
                            Icons.check,
                            size: 30,
                            color: Colors.white,
                          ))
                    ],
                  ),
                ),
              )
            ],
          )
      ],
    );
  }

  @override
  void dispose() {
    _positionAnimationController!.dispose();
    _scaleAnimationController!.dispose();
    heroImage?.dispose();
    // _rotateAnimationController.dispose();
    stopTimer();
    super.dispose();
  }
}
