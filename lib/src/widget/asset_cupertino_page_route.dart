// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


typedef AssetRouteWidgetBuilder = Widget Function(BuildContext context,AssetCupertinoPageRoute route);

class AssetCupertinoPageRoute<T> extends CupertinoPageRoute<T>  {
  /// Creates a page route for use in an iOS designed app.
  ///
  /// The [builder], [maintainState], and [fullscreenDialog] arguments must not
  /// be null.
  ///
  AssetCupertinoPageRoute({
    required this.widgetBuilder,
    String? title,
    required this.context,
    // this.route,
    this.beginSlider = true,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) :
        super(builder: (ctx)=>const SizedBox(),title: title, settings: settings,
          maintainState: maintainState,
          fullscreenDialog: fullscreenDialog) {
    assert(opaque);
  }

  final AssetRouteWidgetBuilder widgetBuilder;

  @override
  Widget buildContent(BuildContext context) {

    return widgetBuilder(context,this);
  }


  final bool beginSlider;

  final BuildContext context;

  bool _pushed = false;
  bool cancel = false;



  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {

    Semantics semantics =  super.buildPage(context, animation, secondaryAnimation) as Semantics;
    final queryData = MediaQuery.of(this.context);
    return MediaQuery(
        data:MediaQuery.of(context).copyWith(devicePixelRatio: queryData.devicePixelRatio,textScaleFactor: queryData.textScaleFactor,platformBrightness: queryData.platformBrightness),
        child: Material(child: semantics));
  }

  @override
  TickerFuture didPush() {
    final future = super.didPush();
    future.then((value) => _pushed = true);
    return future;
  }


  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {

    if (cancel ||  (!_pushed && beginSlider == false && animation.status == AnimationStatus.forward)) {

      final bool linearTransition =  CupertinoRouteTransitionMixin.isPopGestureInProgress(this);
      return CupertinoFullscreenDialogTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition:linearTransition,
        child: child,
      );
    }
    return super.buildTransitions(context, animation, secondaryAnimation, child);
  }

}


