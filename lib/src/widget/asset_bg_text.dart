
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class _Rect {
  double top;
  double left;
  double right;
  double bottom;

  _Rect(this.left,this.top,this.right,this.bottom);

  Rect toRect() => Rect.fromLTRB(left, top, right, bottom);

  @override
  String toString() => '_Rect.fromLTRB(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, ${right.toStringAsFixed(1)}, ${bottom.toStringAsFixed(1)})';

}

class AssetBGText extends Text
{
  const AssetBGText(String data, {
    this.backgroundColor,
    Key? key,
    TextStyle? style,
    StrutStyle? strutStyle,
    TextAlign? textAlign,
    TextDirection? textDirection,
    Locale? locale,
    bool? softWrap,
    TextOverflow? overflow,
    double? textScaleFactor,
    int? maxLines,
    String? semanticsLabel,
    TextWidthBasis? textWidthBasis,
    TextHeightBehavior? textHeightBehavior,}) :
        bgTextSpan = null, super(
          data,
          key: key,
          style: style,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior
      );

  const AssetBGText.rich(
      InlineSpan this.bgTextSpan, {
        this.backgroundColor,
        Key? key,
        TextStyle? style,
        StrutStyle? strutStyle,
        TextAlign? textAlign,
        TextDirection? textDirection,
        Locale? locale,
        bool? softWrap,
        TextOverflow? overflow,
        double? textScaleFactor,
        int? maxLines,
        String? semanticsLabel,
        TextWidthBasis? textWidthBasis,
        TextHeightBehavior? textHeightBehavior,
      }) :  super('',key: key,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaleFactor: textScaleFactor,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior);

  @override
  Widget build(BuildContext context) {

    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle? effectiveTextStyle = style;
    if (style == null || style!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(style);
    }
    if (MediaQuery.boldTextOf(context)) {
      effectiveTextStyle = effectiveTextStyle!.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    Widget result = AssetBGRichText(
      backgroundColor: backgroundColor,
      textAlign: textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start,
      textDirection: textDirection, // RichText uses Directionality.of to obtain a default if this is null.
      locale: locale, // RichText uses Localizations.localeOf to obtain a default if this is null
      softWrap: softWrap ?? defaultTextStyle.softWrap,
      overflow: overflow ?? TextOverflow.visible,
      textScaleFactor: textScaleFactor ?? MediaQuery.textScaleFactorOf(context),
      maxLines: maxLines ?? defaultTextStyle.maxLines,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis ?? defaultTextStyle.textWidthBasis,
      textHeightBehavior: textHeightBehavior ?? defaultTextStyle.textHeightBehavior ?? DefaultTextHeightBehavior.maybeOf(context),
      text: TextSpan(
        style: effectiveTextStyle,
        text: data,
        children: (bgTextSpan != null ? <InlineSpan?>[bgTextSpan] : null) as List<InlineSpan>?,
      ),
    );
    if (semanticsLabel != null) {
      result = Semantics(
        textDirection: textDirection,
        label: semanticsLabel,
        child: ExcludeSemantics(
          child: result,
        ),
      );
    }
    return result;
  }


  final InlineSpan? bgTextSpan;


  final Color? backgroundColor;


}

class AssetBGRichText extends RichText{
  AssetBGRichText({
    this.backgroundColor,
    Key? key,
    required InlineSpan text,
    required TextAlign textAlign,
    TextDirection? textDirection,
    bool softWrap = true,
    required TextOverflow overflow,
    required double textScaleFactor,
    int? maxLines,
    Locale? locale,
    StrutStyle? strutStyle,
    required TextWidthBasis textWidthBasis,
    TextHeightBehavior? textHeightBehavior,
  }) :
        super(
          key: key,
          text: text,
          textAlign: textAlign,
          textDirection: textDirection,
          softWrap: softWrap,
          overflow: overflow,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines,
          locale: locale,
          strutStyle: strutStyle,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior
      );

  @override
  AssetBGRenderParagraph createRenderObject(BuildContext context) {
    assert(textDirection != null || debugCheckHasDirectionality(context));
    return AssetBGRenderParagraph(text,
      backgroundColor: backgroundColor,
      textAlign: textAlign,
      textDirection: textDirection ?? Directionality.of(context),
      softWrap: softWrap,
      overflow: overflow,
      textScaleFactor: textScaleFactor,
      maxLines: maxLines,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      locale: locale ?? Localizations.maybeLocaleOf(context),
    );
  }
  final Color? backgroundColor;

  @override
  void updateRenderObject(BuildContext context, covariant AssetBGRenderParagraph renderObject) {
    renderObject.backgroundColor = backgroundColor;
    super.updateRenderObject(context, renderObject);
  }

}

class AssetBGRenderParagraph extends RenderParagraph{

  final Paint bgPaint = Paint()..style = PaintingStyle.fill;

  AssetBGRenderParagraph(InlineSpan text, {
    this.backgroundColor,
    TextAlign textAlign = TextAlign.start,
    required TextDirection textDirection,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.visible,
    double textScaleFactor = 1.0,
    int? maxLines,
    Locale? locale,
    StrutStyle? strutStyle,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    TextHeightBehavior? textHeightBehavior,
    List<RenderBox>? children,
  }) : assert(text.debugAssertIsValid()),
        assert(maxLines == null || maxLines > 0),
        super(
          text,
          textAlign: textAlign,
          textDirection: textDirection,
          softWrap: softWrap,
          overflow: overflow,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines,
          locale: locale,
          strutStyle: strutStyle,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          children: children
      );

  @override
  void paint(PaintingContext context, Offset offset) {
    // TODO: implement paint
    if(backgroundColor != null){
      final boxes = getBoxesForSelection(TextSelection(
        baseOffset: 0,
        extentOffset: (text as TextSpan).text!.length,
      ));
      bgPaint.color = backgroundColor!;
      List<_Rect> linesBox = [];
      for(final box in boxes){
        if(linesBox.isEmpty){
          linesBox.add(_Rect(box.left, box.top,box.right, box.bottom));
        }
        else{
          final last = linesBox.last;
          if(box.bottom - last.bottom >= (last.bottom - last.top) * 0.7){  //新的一行
            linesBox.add(_Rect(box.left, box.top,box.right, box.bottom));
          }
          else{
            if(box.bottom > last.bottom){
              last.top = box.top;
              last.bottom = box.bottom;
            }
            last.right = box.right;
          }
        }
      }
      int len = linesBox.length;

      const radius = Radius.circular(8);

      Path path = Path();


      for(int i = 0;i<len;i++){

        final line = linesBox[i];
        Rect rect = line.toRect().translate(offset.dx, offset.dy);
        rect = Rect.fromCenter(center: rect.center,width: rect.width + 10,height: rect.height + 1);

        RRect rRect;

        if(i == 0){
          if(len == 1) {
            rRect = RRect.fromRectAndRadius(rect, radius);
          }
          else{
            bool showBottomRight =  linesBox[1].right < line.right;
            rRect = RRect.fromRectAndCorners(rect, topLeft: radius,topRight: radius,bottomRight: showBottomRight ? radius :Radius.zero,);
          }
        }
        else{
          bool showTopRight = linesBox[i-1].right <= line.right + 3 ;

          bool showBottomRight = i == len-1 ? true : linesBox[i+1].right < line.right;
          rRect = RRect.fromRectAndCorners(rect,
              bottomLeft: i == len-1 ? radius :Radius.zero,
              bottomRight: showBottomRight ? radius :Radius.zero,
              topRight: showTopRight ? radius:Radius.zero);
        }
        path.addRRect(rRect);
      }
      context.canvas.drawPath(path, bgPaint);
    }

    super.paint(context, offset);

  }

  Color? backgroundColor;
}

