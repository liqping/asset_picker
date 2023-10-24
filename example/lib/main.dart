import 'dart:io';
import 'dart:math';


import 'package:flutter_asset_picker/asset_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui show window;

import 'package:flutter/services.dart';

void main()
{
  runApp(const MyApp());
  // timeDilation = 5.0;
  SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(statusBarColor:Colors.transparent);
  SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return
         MaterialApp(
           theme: ThemeData(brightness: MediaQueryData.fromWindow(ui.window).platformBrightness),
          localizationsDelegates: [
            DefaultMaterialLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate
          ],
          home: const HomeWidget(),
        );
    //   CupertinoApp(
    //   title: 'Flutter Demo',
    //   home:HomeWidget(
    //   ),
    //   localizationsDelegates: [
    //     DefaultMaterialLocalizations.delegate,
    //     DefaultCupertinoLocalizations.delegate
    //   ],
    //   // theme: CupertinoThemeData(
    //   //   scaffoldBackgroundColor: Colors.red
    //   // ),
    //
    // );
  }
}


class HomeWidget extends StatefulWidget
{
  const HomeWidget({Key? key}) : super(key: key);
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _HomeWidget();
  }

}

class _HomeWidget extends State<HomeWidget> {

  final assets = <Asset>[];

  bool _scrollReverse = true;
  bool _dropDownBanner = true;
  bool _cupertionPage = false;


  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> getAllPhoto() async {
    await showAssetPickNavigationDialog(context: context,
        type: AssetPickerType.pictureAndVideo,
        dropDownBannerMode:_dropDownBanner,
        isCupertinoType: _cupertionPage,
        scrollReverse: _scrollReverse,
        photoDidSelectCallBack: (assets)
        {
          if(assets.isNotEmpty){
            setState(() {
              this.assets.addAll(assets);
            });
          }

        });
  }

  @override
  Widget build(BuildContext context) {

    return Material(
      child: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(middle: Text('asset picker sample')),
          child: SafeArea(
            child: Column(
              children: [
                Center(
                  child: CupertinoButton(
                      onPressed: getAllPhoto,
                      child: const Text('选择图片')
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('scrollReverse：'),
                          Switch(value: _scrollReverse, onChanged: (_)=>setState(() {
                            _scrollReverse = !_scrollReverse;
                          }))
                        ],),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('dropDownBanner：'),
                          Switch(value: _dropDownBanner, onChanged: (_)=>setState(() {
                            _dropDownBanner = !_dropDownBanner;
                          }))
                        ],),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('cupertionPage：'),
                          Switch(value: _cupertionPage, onChanged: (_)=>setState(() {
                            _cupertionPage = !_cupertionPage;
                          }))
                        ],),
                    ],),
                ),
                const Text('image list'),
                Expanded(child: GridView.builder(
                    itemCount: assets.length,
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                      mainAxisSpacing: 5,
                      crossAxisSpacing: 5
                    ),
                    itemBuilder: (ctx,index)=>LayoutBuilder(
                      builder: (context,sizeConstraint) {
                        return AssetThumbImage(asset: assets[index], width: (sizeConstraint.maxWidth * MediaQuery.of(context).devicePixelRatio).toInt());
                      }
                    )))
              ],
            ),
          )
      ),
    );
  }
}
