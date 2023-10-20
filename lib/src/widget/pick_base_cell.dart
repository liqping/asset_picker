
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PickBaseCell extends StatefulWidget
{
  final Color selectedColor;
  final Color highlightColor;
  final Color normalColor;
  final bool  selected;
  final Widget child;
  final GestureTapCallback? tapCallback;
  final GestureLongPressCallback? longPressCallback;
  final ValueChanged<bool>? onHighlightChanged;

  const PickBaseCell({super.key, required this.child,
    this.tapCallback,
    this.longPressCallback,this.normalColor = Colors.white, this.onHighlightChanged,
    this.selectedColor = Colors.white,
    this.highlightColor = const Color(0xFFEAEAEA),this.selected = false}
      );

  @override
  State<StatefulWidget> createState() => _PickBaseCell();


}

class _PickBaseCell extends State<PickBaseCell>
{

  bool isHiLight = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (TapDownDetails details)
      {
        if(!widget.selected)
        {
          setState(() {
            isHiLight = true;
            if(widget.onHighlightChanged != null)
            {
              widget.onHighlightChanged!(true);
            }
          });
        }

      },
      onTapCancel: ()
      {

        if(!widget.selected) {
          if(widget.onHighlightChanged != null)
          {
            widget.onHighlightChanged!(false);
          }
          setState(() {
            isHiLight = false;
          });
        }
        else
        {
          isHiLight = false;
        }
      },
      onTapUp: (TapUpDetails details)
      {

        if(!widget.selected) {
          if(widget.onHighlightChanged != null)
          {
            widget.onHighlightChanged!(false);
          }

          Future.delayed(const Duration(milliseconds: 50),(){
            setState(() {
              isHiLight = false;
            });
          });

        }
        else
        {
          isHiLight = false;
        }
      },
      onTap: widget.tapCallback,
      onLongPress: widget.longPressCallback,
      behavior: HitTestBehavior.opaque,
      child:Container(
          color: widget.selected ?
          CupertinoDynamicColor.withBrightness(color: widget.selectedColor, darkColor: Color(widget.selectedColor.value ^ 0x00FFFFFF)).resolveFrom(context)
              : isHiLight ?
          CupertinoDynamicColor.withBrightness(color: widget.highlightColor, darkColor: Color(widget.highlightColor.value ^ 0x00FFFFFF)).resolveFrom(context) :
          CupertinoDynamicColor.withBrightness(color: widget.normalColor, darkColor: Color(widget.normalColor.value ^ 0x00FFFFFF)).resolveFrom(context),
          child: widget.child),
    );
  }
}