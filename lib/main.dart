import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telesale_system_2025/version_app.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<String> loadPemFile() async {
  return await rootBundle.loadString('assets/uatcmsCA.pem');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  loadPemFile();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    // TODO: implement initState
    url = dotenv.get('API_URL', fallback: '');
    environment = dotenv.get('ENVIRONMENT', fallback: '');
    initPlatformState();
    _getAppVersion();
    requestMicrophonePermission();
    super.initState();
  }

  String? _version;

  void _getAppVersion() async {
    final version = await AppVersion.getVersion();

    setState(() {
      _version = version;
    });
  }

  String url = '';
  String environment = '';
  late WebViewController _controllerWeb;
  bool _isLoading = true;
  final List<StreamSubscription> _subscriptions = [];
  final _textController = TextEditingController();
  Future<bool> requestMicrophonePermission() async {
    PermissionStatus status = await Permission.microphone.request();

    if (status.isGranted) {
      print("Microphone permission granted!");
      return true;
    } else if (status.isDenied) {
      print("Microphone permission denied.");
      return false;
    } else if (status.isPermanentlyDenied) {
      print("Microphone permission permanently denied. Open settings.");
      openAppSettings(); // Mở cài đặt ứng dụng nếu bị từ chối vĩnh viễn

      return false;
    }
    return false;
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
      String url, WebviewPermissionKind kind, bool isUserInitiated) async {
    if (kind == WebviewPermissionKind.notifications ||
        kind == WebviewPermissionKind.microphone ||
        kind == WebviewPermissionKind.geoLocation ||
        kind == WebviewPermissionKind.clipboardRead) {
      return WebviewPermissionDecision.allow; // Tự động cho phép quyền micro
    }

    final decision = await showDialog<WebviewPermissionDecision>(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('WebView permission requested'),
        content: Text('WebView has requested permission \'$kind\''),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.deny),
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.allow),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.none;
  }

  final _controller = WebviewController();
  Future<void> initPlatformState() async {
    // Optionally initialize the webview environment using
    // a custom user data directory
    // and/or a custom browser executable directory
    // and/or custom chromium command line flags
    //await WebviewController.initializeEnvironment(
    //    additionalArguments: '--show-fps-counter');

    try {
      await _controller.initialize();
      _subscriptions.add(_controller.url.listen((url) {
        setState(() {
          _textController.text = url;
        });
      }));

      _subscriptions
          .add(_controller.containsFullScreenElementChanged.listen((flag) {
        debugPrint('Contains fullscreen element: $flag');
        windowManager.setFullScreen(flag);
      }));

      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.allow);
      // Xóa cache trước khi tải URL mới

      await _controller.loadUrl(url);

      if (!mounted) return;
      setState(() {});
    } on PlatformException catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: Text('Error'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Code: ${e.code}'),
                      Text('Message: ${e.message}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      child: Text('Continue'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  ],
                ));
      });
    }
  }

  Widget compositeView() {
    if (!_controller.value.isInitialized) {
      return const Text(
        'Not Initialized',
        style: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (environment == 'DEV')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${_textController.text}',
                        style: TextStyle(fontSize: 12, color: Colors.black),
                      ),
                    ),
                    // Expanded(
                    //   child: SizedBox(
                    //     height: 30,
                    //     child: TextField(
                    //       style: TextStyle(fontSize: 12, color: Colors.black),
                    //       enabled: false,
                    //       decoration: InputDecoration(
                    //         border: InputBorder.none,
                    //         hintText: 'URL',
                    //         //  contentPadding: EdgeInsets.all(10.0),
                    //       ),
                    //       textAlignVertical: TextAlignVertical.center,
                    //       controller: _textController,
                    //       onSubmitted: (val) {
                    //         _controller.loadUrl(val);
                    //       },
                    //     ),
                    //   ),
                    // ),
                    // Expanded(
                    //   child: TextField(

                    //     style: TextStyle(fontSize: 12, color: Colors.black),
                    //     enabled: false,
                    //     decoration: InputDecoration(

                    //       border: InputBorder.none,
                    //       hintText: 'URL',
                    //       //  contentPadding: EdgeInsets.all(10.0),
                    //     ),
                    //     textAlignVertical: TextAlignVertical.center,
                    //     controller: _textController,
                    //     onSubmitted: (val) {
                    //       _controller.loadUrl(val);
                    //     },
                    //   ),
                    // ),
                    IconButton(
                      icon: Icon(Icons.refresh),
                      tooltip: 'Refresh',
                      splashRadius: 10,
                      onPressed: () async {
                        _controller.reload();
                        await _controller.clearCache();
                      },
                    ),
                    // InkWell(
                    //     onTap: () {
                    //       _controller.reload();
                    //     },
                    //     child: Icon(Icons.refresh)),
                    IconButton(
                      icon: Icon(Icons.developer_mode),
                      tooltip: 'Open DevTools',
                      splashRadius: 20,
                      onPressed: () {
                        _controller.openDevTools();
                      },
                    )
                  ]),
            ),
          Expanded(
              child: Card(
                  color: Colors.transparent,
                  elevation: 0,
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: Stack(
                    children: [
                      Webview(
                        _controller,
                        permissionRequested: _onPermissionRequested,
                      ),
                      StreamBuilder<LoadingState>(
                          stream: _controller.loadingState,
                          builder: (context, snapshot) {
                            if (snapshot.hasData &&
                                snapshot.data == LoadingState.loading) {
                              return LinearProgressIndicator();
                            } else {
                              return SizedBox();
                            }
                          }),
                    ],
                  ))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Powered by MITEK',
                  style: TextStyle(
                      color: Color(
                        0xff076C79,
                      ),
                      fontSize: 10),
                ),
                Text(
                  'Version $_version',
                  style: TextStyle(color: Color(0xff076C79), fontSize: 10),
                ),
              ],
            ),
          )
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: compositeView(),
    );
  }
}
