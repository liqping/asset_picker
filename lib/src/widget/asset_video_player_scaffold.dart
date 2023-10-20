
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:asset_picker/asset_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class AssetVideoPlayerScaffold extends StatefulWidget {
  const AssetVideoPlayerScaffold({super.key, this.videoPath,this.fileId,this
      .isAudio = false,required this.isCupertinoType});
  final String? videoPath;
  final bool? isAudio;

  // final AssetOrientType orientType;

  final int? fileId;

  final bool isCupertinoType;

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return __MainWidget();
  }
}

class __MainWidget extends State<AssetVideoPlayerScaffold>
    with SingleTickerProviderStateMixin {
  bool screenFull = false;

  Timer? _timer;

  // bool showFullscreenBtn = false;

  int? _currentDurationMilliseconds;   //当前已经播放的时间
  int? _totalDurationMilliseconds;  //视频总时间

  bool showPlayIcon = false;  //是否显示播放按钮，当播放完成后显示

  double _timeWidth = 10;
  late bool _prePayerPause;  //拖动之前是否暂停状态

  bool isShowBuffer = false;

  bool _isShowControlBar = false;


//  AnimationController _oriController;
//  Animation<double> _animation;

  VideoPlayerController? _controller;

  static String convertSecondsToHMS(int seconds)
  {

    if(seconds <= 0)
    {
      return '0:00';
    }

    String formatString = '';
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int sec = seconds % 60;
    if(hours > 0)
    {

      formatString += hours > 9 ? '$hours:' : '0$hours:';
    }

    formatString += minutes > 9 ? '$minutes:' : '0$minutes:';

    formatString += sec > 9 ? '$sec' : '0$sec';
    return formatString;
  }

  void setVideoFileController(dynamic videoPath)
  {
    if(videoPath is File){
      _controller = VideoPlayerController.file(videoPath);
    }
    else{
      _controller = VideoPlayerController.contentUri(videoPath);
    }
    _controller!.initialize().then((_) {
        if(!mounted) {
          return;
        }
        // if (!widget.isAudio! && ((MediaQuery.of(context).orientation == Orientation.portrait && _controller!.value.aspectRatio > 1) || (MediaQuery.of(context).orientation == Orientation.landscape && _controller!.value.aspectRatio < 1))) {
        //   showFullscreenBtn = true;
        // }

        final textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: convertSecondsToHMS(_controller!.value.duration.inSeconds),
            style: const TextStyle
              (fontSize:
            12,color: Colors
                .white),
          ),
        );
        textPainter.layout();
        startTimer();
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {
          _isShowControlBar = true;
          _timeWidth = textPainter.width + 5;
          _totalDurationMilliseconds = _controller!.value.duration.inMilliseconds;
          _currentDurationMilliseconds = 0;
          _controller!.play();
        });
      });
  }

  void setControllerListener()
  {
    _controller!.addListener(() async {
      if (_controller!.value.hasError) {
        AssetToast.show('播放失败:${_controller!.value.errorDescription}', context);
        if (kDebugMode) {
          print('player error:${_controller!.value.errorDescription}');
        }
      }
//      if(_controller.value.isBuffering)
//        {
//          print('bufferingxxx');
//        }
      isShowBuffer = _controller!.value.isBuffering;
//      print('isShowBuffer:$isShowBuffer');

      Duration? duration = await _controller!.position;
      if(_controller!.value.isInitialized && duration! >= _controller!.value
          .duration && !_controller!.value.isPlaying)
      {
        showPlayIcon = true;

      }
      else if(_controller!.value.isPlaying || !showPlayIcon ||
          _currentDurationMilliseconds != 0)
      {
        showPlayIcon = false;
      }

      if(mounted) {

        setState(() {
          if(showPlayIcon)
          {
            if(_currentDurationMilliseconds != 0) {
              _currentDurationMilliseconds = 0;
              _controller!.seekTo(const Duration(milliseconds: 0));
              _controller!.pause();
            }
          }
          else {
            if(_controller!.value.isInitialized)
            {
              if (duration! > _controller!.value
                  .duration) {
                _currentDurationMilliseconds = _controller!.value
                    .duration.inMilliseconds;
              }
              else {
                _currentDurationMilliseconds = duration.inMilliseconds;
              }
            }
          }
        });

      }
    });
  }

  @override
  void initState() {
    super.initState();
    // AutoOrientation.portraitUpMode();

    if(Platform.isIOS){
      if(widget.videoPath != null){
        setVideoFileController(File(widget.videoPath!));
        setControllerListener();
      }

    }
    else{
      AssetPicker.getFileExternalContentUri().then((value) {
        if(value != null){
          setVideoFileController(Uri.parse('$value/${widget.fileId}'));
          setControllerListener();
          if(mounted){
            setState(() {

            });
          }
        }
      });
    }

  }

  void startTimer()
  {
    cancelTimer();
    const period = Duration(seconds: 6);
    _timer = Timer.periodic(period, (timer)
    {
      if(_isShowControlBar)
      {
        setState(() {
          _isShowControlBar = false;
        });
      }
      cancelTimer();
    });
  }


  void cancelTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = SafeArea(
      top: false,
      bottom: false,
      child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: ()
          {
            if(_totalDurationMilliseconds != null) {
              if(!_isShowControlBar)
              {
                startTimer();
              }
              setState(() {
                _isShowControlBar = !_isShowControlBar;
              });
            }
          },
          child: OrientationBuilder(
            builder: (context,orientation) {
              bool showFullscreenBtn = !widget.isAudio! && ((MediaQuery.of(context).orientation == Orientation.portrait && _controller != null && _controller!.value.isInitialized &&  _controller!.value.aspectRatio > 1) || (MediaQuery.of(context).orientation == Orientation.landscape && _controller!.value.aspectRatio < 1));
              // if () {
              //   showFullscreenBtn = true;
              // }
              return Stack(
                children: <Widget>[
                  Center(
                      child: _controller != null && _controller!.value.isInitialized
                          ?  AspectRatio(
                        aspectRatio: widget.isAudio! ? 1 : _controller!.value
                            .aspectRatio,
                        child: VideoPlayer(_controller!),
//                      ))
                      ) : const CupertinoActivityIndicator(
                        radius: 20,
                      )
                  ),
                  Offstage(offstage: !widget.isAudio! ||  _controller == null ||
                      !_controller!.value.isInitialized,child: Center(
                    child: Image.asset('images/music_bg.png',package: 'asset_picker',),
                  ),),
                  Visibility(
                      visible: showPlayIcon,
                      child: Center(
                        child: GestureDetector(
                          onTap: ()
                          {
                            setState(() {
                              showPlayIcon = false;
                              if(_controller !=null && _controller!.value.isInitialized &&
                                  !_controller!.value
                                      .isPlaying)
                              {
                                _currentDurationMilliseconds = 0;
                                _controller!.seekTo(const Duration(milliseconds: 0));
                                _controller!.play();
                              }
                            });
                          },
                          child: const Icon(Icons.play_circle_outline,color: Colors.white,size:
                          70,),
                        ),
                      )
                  ),
                  Visibility(
                      visible: isShowBuffer,
                      child: const Center(
                        child:
                        CupertinoActivityIndicator(
                          radius: 20,
                        ),
                      )
                  ),
                  SafeArea(
                      top: true,
                      bottom: true,
                      child: Column(
                        children: <Widget>[
                          Container(
                              height: 44,
                              margin: const EdgeInsets.only(top: 16,right: 16,left: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      color: const Color(0x2F000000),
                                      minSize: 35,
                                      onPressed: () {


                                        if (_controller != null &&
                                            _controller!.value.isPlaying) {
                                          _controller!.pause();
                                        }

                                        Navigator.of(context).pop();
                                      },
                                      child:
                                      const Icon(Icons.close,color: Colors.white,size: 35,)
                                  ),
                                  Expanded(
                                      flex: 1,
                                      child: Container(
                                        alignment: Alignment.centerRight,
                                        child: Offstage(
                                          offstage: !screenFull && !showFullscreenBtn,
                                          child: CupertinoButton(
                                            padding: const EdgeInsets.only(
                                                left: 10, right: 10, bottom: 2),
                                            minSize: 35,
                                            onPressed: () async{
                                              if(screenFull){
                                                await SystemChrome.setPreferredOrientations([]);
                                              }else{
                                                if(orientation == Orientation.landscape) {
                                                  await SystemChrome.setPreferredOrientations([
                                                    DeviceOrientation.portraitDown
                                                  ]);
                                                }else{
                                                  await SystemChrome.setPreferredOrientations([
                                                    DeviceOrientation.landscapeLeft
                                                  ]);
                                                }
                                              }
                                              setState(() {
                                                screenFull = !screenFull;
                                              });
                                            },
                                            child: Icon(
                                              !screenFull ? Icons.fullscreen : Icons.fullscreen_exit,
                                              color: const Color(0xE3FFFFFF),size: 35,
                                            ),
                                          ),
                                        ),
                                      )),
                                ],
                              )),
                          Expanded(flex: 1,child: Container(),),
                          Visibility(
                            visible: _totalDurationMilliseconds != null && _isShowControlBar,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.black12,Colors.black26 ,Colors
                                        .black12]),

                              ),
                              height: 45,margin:
                            const EdgeInsets.only(bottom: 35),child: Row(
                              children: <Widget>[
                                GestureDetector(
                                    onTap: ()
                                    {

                                      if(_controller !=null && _controller!.value
                                          .isInitialized)
                                      {
                                        if(_controller!.value.isPlaying)
                                        {
                                          _controller!.pause();
                                        }
                                        else
                                        {
                                          if(_currentDurationMilliseconds! >=
                                              _controller!.value.duration.inMilliseconds)
                                          {
                                            _controller!.seekTo(const Duration(milliseconds: 0));
                                            _currentDurationMilliseconds = 0;
                                            showPlayIcon = false;

                                          }
                                          _controller!.play();
                                        }
                                      }
                                    },
                                    child: SizedBox(
                                      width: 40,
                                      child: Center(child:Icon(
                                        _controller !=null &&_controller!.value.isInitialized
                                            && _controller!
                                            .value.isPlaying ? Icons.pause
                                            :Icons
                                            .play_arrow,
                                        color: Colors.white,
                                        size: 32,
                                      )),
                                    )),
                                SizedBox(
                                  width: _timeWidth,
                                  child: Text(_currentDurationMilliseconds == null ? ''
                                      :convertSecondsToHMS
                                    (_currentDurationMilliseconds!~/1000),
                                    style:
                                    const TextStyle(fontSize:12,color: Colors.white),
                                  ),
                                )
                                ,
                                Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child:
                                      Slider(
                                        value: _totalDurationMilliseconds == null ||
                                            _totalDurationMilliseconds == 0 ||
                                            _currentDurationMilliseconds == null ? 0 :
                                        max(0,min(1,
                                            _currentDurationMilliseconds!/_totalDurationMilliseconds!)),
                                        min: 0,
                                        max: 1,
                                        activeColor: Colors.white,
                                        inactiveColor: Colors.grey,
                                        onChanged: (value) {
                                          if(_controller !=null && _controller!.value
                                              .isInitialized &&
                                              _totalDurationMilliseconds != null &&
                                              _totalDurationMilliseconds != 0)
                                          {
                                            _controller!.seekTo(Duration(milliseconds:
                                            (_totalDurationMilliseconds! * value).toInt()));

                                          }

                                          if(_prePayerPause && _controller !=null &&
                                              !_controller!.value
                                                  .isPlaying)
                                          {
                                            _controller!.play();
                                          }
                                        },
                                        onChangeStart: (value)
                                        {
                                          if(_controller!.value.isInitialized)
                                          {
                                            cancelTimer();
                                            _prePayerPause  = !_controller!.value
                                                .isPlaying;

                                          }
                                        },
                                        onChangeEnd: (value)
                                        {
                                          if(_controller!.value.isInitialized)
                                          {
                                            startTimer();
                                            if(_prePayerPause)
                                            {
                                              _controller!.pause();
                                            }

                                          }
                                        },
                                      ),
                                    )),
                                SizedBox(
                                  width: _timeWidth,
                                  child: Text(_totalDurationMilliseconds == null ||
                                      _currentDurationMilliseconds == null ? ''
                                      :convertSecondsToHMS
                                    ((_totalDurationMilliseconds! -
                                      _currentDurationMilliseconds!)~/1000),
                                    style: const TextStyle(fontSize: 12,color: Colors
                                        .white),
                                  ),)
                                ,
                                const Padding(padding: EdgeInsets.only(right: 10),)
                              ],
                            )
                              ,),
                          )


                        ],
                      ))
                ],
              );
            }
          )),
    );
    return Material(child: widget.isCupertinoType ?
    CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: child,
    ) : Scaffold(
      backgroundColor: Colors.black,
      body: child,
    ),);
  }

  @override
  void dispose() {
    cancelTimer();
    super.dispose();
    if(_controller != null)
    {
      _controller!.dispose();
    }
    SystemChrome.setPreferredOrientations([]);
  }
}