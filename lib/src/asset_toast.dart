import 'package:flutter/material.dart';

class AssetToast {
  static const int LENGTH_SHORT = 1;
  static const int LENGTH_LONG = 2;
  static const int BOTTOM = 0;
  static const int CENTER = 1;
  static const int TOP = 2;

  static void show(String? msg, BuildContext context,
      {int duration = 1,
      int gravity = 0,
      Color backgroundColor = const Color(0xAA000000),
      Color textColor = Colors.white,
      double backgroundRadius = 20,
      Border? border}) {
    _ToastView.dismiss();
    _ToastView.createView(
        msg, context, duration, gravity, backgroundColor, textColor, backgroundRadius, border);
  }
}

class _ToastView {
  static final _ToastView _singleton = _ToastView._internal();

  factory _ToastView() {
    return _singleton;
  }

  _ToastView._internal();

  static OverlayState? overlayState;
  static OverlayEntry? _overlayEntry;
  static bool _isVisible = false;

  static void createView(String? msg, BuildContext context, int duration, int gravity,
      Color background, Color textColor, double backgroundRadius, Border? border) async {
    overlayState = Overlay.of(context);

    Paint paint = Paint();
    paint.strokeCap = StrokeCap.square;
    paint.color = background;

    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) => _ToastWidget(
          widget: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Container(
                alignment: Alignment.center,
                width: MediaQuery.of(context).size.width,
                child: Container(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(backgroundRadius),
                    border: border,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child:
                      Text(msg!, softWrap: true, style: TextStyle(fontSize: 15, color: textColor)),
                )),
          ),
          gravity: gravity),
    );
    _isVisible = true;
    overlayState!.insert(_overlayEntry!);
    await Future.delayed(Duration(seconds:  duration));
    dismiss();
  }

  static dismiss() async {
    if (!_isVisible) {
      return;
    }
    _isVisible = false;
    _overlayEntry?.remove();
  }
}

class _ToastWidget extends StatelessWidget {
  const _ToastWidget({
    Key? key,
    required this.widget,
    required this.gravity,
  }) : super(key: key);

  final Widget widget;
  final int gravity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
        top: gravity == 2 ? 50 : null,
        bottom: gravity == 0 ? 50 : null,
        child: Material(
          color: Colors.transparent,
          child: widget,
        ));
  }
}
