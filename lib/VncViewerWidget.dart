import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libvncviewer_flutter/libvncviewer_flutter.dart';
import 'dart:io';

class VncViewerWidget extends StatefulWidget {
  String hostName;
  String password;
  int port;

  VncViewerWidget(this.hostName, this.port, this.password);

  @override
  State<StatefulWidget> createState() => _VncViewerWidgetState();
}

class _VncViewerWidgetState extends State<VncViewerWidget>
    with WidgetsBindingObserver {
  static const EventChannel _channel =
      const EventChannel('libvncviewer_flutter_eventchannel');

  StreamSubscription? _streamSubscription;

  StreamController<int> _streamController = StreamController();

  final _libvncviewerFlutterPlugin = LibvncviewerFlutter();

  int _imageWidth = 0;

  int _imageHeight = 0;

  double _width = 0;

  double _height = 0;

  int _clientId = 0;

  int _textureId = -1;

  double _scale = 1.0;

  int _buttonMask = 0;

  GlobalKey _vncViewKey = new GlobalKey();

  bool _showAppBar = false;

  Timer? _timer;

  int _x = 0;
  int _y = 0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      _clientId = await _libvncviewerFlutterPlugin.initVncClient(
              widget.hostName, widget.port, widget.password) ??
          0;
      if (_clientId != 0) {
        _streamSubscription = _channel
            .receiveBroadcastStream({"clientId": _clientId}).listen(
                (dynamic event) {
          // var data = jsonDecode(message);
          Map data = event;
          String flag = data["flag"];
          if (flag == "imageResize") {
            _imageWidth = data["width"];
            _imageHeight = data["height"];
            _textureId = data["textureId"];
            _streamController.add(1);
          }
          if (flag == "onReady") {
            print("start vnc client");
            _libvncviewerFlutterPlugin.startVncClient(_clientId);
          }
          if (flag == "onError") {
            String errMsg = data["msg"];
            showCupertinoModalPopup<void>(
              context: context,
              builder: (BuildContext context) {
                return CupertinoAlertDialog(
                  title: const Text('错误提示'),
                  content: Text(errMsg),
                  actions: <CupertinoDialogAction>[
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text('关闭'),
                    ),
                  ],
                );
              },
            );
          }
        }, onError: (dynamic error) {
          print('Received error: ${error.message}');
        }, cancelOnError: true);
      }
    });
  }

  @override
  void didChangeMetrics() {
    // 当窗口变化时调用
    super.didChangeMetrics();
    print('Window metrics changed');

    if (Platform.isMacOS || Platform.isLinux) {
      Future.delayed(Duration(milliseconds: 500), () {
        _streamController.add(1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(preferredSize: Size.zero, child: AppBar()),
      body: StreamBuilder<int>(
          initialData: _textureId,
          stream: _streamController.stream,
          builder: (context, async) {
            double ratio = MediaQuery.of(context).devicePixelRatio;
            _width = MediaQuery.of(context).size.width;
            _height = MediaQuery.of(context).size.height;

            Widget appBar = Container();
            Widget content = Container();
            if (_showAppBar) {
              appBar = Container(
                  width: MediaQuery.of(context).size.width,
                  height: 50,
                  child: PreferredSize(
                      preferredSize: Size.fromHeight(50),
                      child: AppBar(
                        automaticallyImplyLeading: false,
                        iconTheme: const IconThemeData(
                          color: Colors.white, // 设置返回箭头颜色为白色
                        ),
                        leading: IconButton(
                          enableFeedback: true,
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        backgroundColor: Color.fromARGB(60, 0, 0, 0),
                        toolbarTextStyle: TextStyle(color: Colors.white),
                        actions: [
                          IconButton(
                              icon: const Icon(Icons.fullscreen),
                              onPressed: () {
                                double w = MediaQuery.of(context).size.width;
                                double h = MediaQuery.of(context).size.height;
                                if (w < h) {
                                  SystemChrome.setPreferredOrientations([
                                    DeviceOrientation.landscapeLeft,
                                    DeviceOrientation.landscapeRight
                                  ]);
                                } else {
                                  SystemChrome.setPreferredOrientations([
                                    DeviceOrientation.portraitUp,
                                    DeviceOrientation.portraitDown
                                  ]);
                                }
                                _streamController.add(1);
                              })
                        ],
                      )));
            }
            if (async.data == -1) {
              content = GestureDetector(
                onTap: () {
                  if (_showAppBar) {
                    return;
                  }
                  _showAppBar = !_showAppBar;
                  _streamController.add(-1);
                  if (_timer != null) {
                    _timer!.cancel();
                  }
                  _timer = Timer.periodic(Duration(seconds: 3), (timer) {
                    _timer!.cancel();
                    _showAppBar = !_showAppBar;
                    _streamController.add(-1);
                  });
                },
                child: Container(
                    // width: MediaQuery.of(context).size.width,
                    // height: MediaQuery.of(context).size.height,
                    color: Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        CupertinoActivityIndicator(
                          radius: 15,
                        ),
                        SizedBox(height: 10),
                        Text('正在连接'),
                      ],
                    )),
              );
            } else {
              if (_imageWidth > 0 && _width < _height) {
                _scale = _width / _imageWidth;
                _height = _imageHeight * _scale;
              } else {
                _scale = _height / _imageHeight;
                _width = _imageWidth * _scale;
              }

              content = Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                color: Colors.white,
                child: GestureDetector(
                    onTap: () {
                      _showAppBar = !_showAppBar;
                      _streamController.add(1);
                      // if (_showAppBar) {
                      //   Future.delayed(Duration(seconds: 2), () {
                      //     _showAppBar = false;
                      //     setState(() {});
                      //   });
                      // }
                    },
                    child: InteractiveViewer(
                      scaleEnabled: true,
                      child: Center(
                        child: Container(
                          width: _width,
                          height: _height,
                          color: Colors.red,
                          child: GestureDetector(
                            // behavior: HitTestBehavior.opaque,
                            onTapDown: (details) {
                              _buttonMask = 0x01;
                              var localPosition = details.localPosition;
                              _x = (localPosition.dx / _scale).toInt();
                              _y = (localPosition.dy / _scale).toInt();
                              _libvncviewerFlutterPlugin.sendPointer(
                                  _clientId, _x, _y, _buttonMask);
                            },
                            onTapUp: (details) {
                              _buttonMask &= 0xfe;
                              var localPosition = details.localPosition;
                              _x = (localPosition.dx / _scale).toInt();
                              _y = (localPosition.dy / _scale).toInt();
                              _libvncviewerFlutterPlugin.sendPointer(
                                  _clientId, _x, _y, _buttonMask);
                            },
                            onPanUpdate: (DragUpdateDetails details) {
                              var localPosition = details.localPosition;
                              _x = (localPosition.dx / _scale).toInt();
                              _y = (localPosition.dy / _scale).toInt();
                              _libvncviewerFlutterPlugin.sendPointer(
                                  _clientId, _x, _y, _buttonMask);
                            },
                            onLongPress: () {
                              _buttonMask |= 0x04;
                              _libvncviewerFlutterPlugin.sendPointer(
                                  _clientId, _x, _y, _buttonMask);
                            },
                            onLongPressCancel: () {
                              _buttonMask &= 0xfb;
                              _libvncviewerFlutterPlugin.sendPointer(
                                  _clientId, _x, _y, _buttonMask);
                            },
                            child: Texture(
                              textureId: _textureId,
                              key: _vncViewKey,
                              filterQuality: FilterQuality.none,
                            ),
                          ),
                        ),
                      ),
                    )),
              );
            }

            return Stack(
              children: [
                Positioned(
                    top: 0, left: 0, right: 0, bottom: 0, child: content),
                Positioned(top: 0, left: 0, child: appBar)
              ],
            );
          }),
    );
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    _streamSubscription!.cancel();
    _libvncviewerFlutterPlugin.closeVncClient(_clientId);
    WidgetsBinding.instance?.removeObserver(this);
  }
}
