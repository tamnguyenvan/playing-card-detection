import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'live_camera.dart';

late List<CameraDescription> cameras;
late Directory tempDir;

Future<void> main() async {
  // initialize the cameras when the app starts
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();

  // running the app
  runApp(MaterialApp(
    home: MyApp(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData.light(),
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Playing Card Detection"),
      ),
      body: Container(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ButtonTheme(
                minWidth: 200,
                child: ElevatedButton(
                  child: Text("Start"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LiveFeed(cameras),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// import 'dart:async';
// import 'dart:io';
// import 'dart:isolate';
// import 'dart:typed_data';

// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_opencv_example/native_opencv.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:image/image.dart' as imglib;
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:image_size_getter/file_input.dart';
// import 'package:image_size_getter/image_size_getter.dart';

// const title = 'Native OpenCV Example';

// late Directory tempDir;

// String get tempPath => '${tempDir.path}/temp.jpg';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   getTemporaryDirectory().then((dir) => tempDir = dir);

//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: title,
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: MyHomePage(),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   final _picker = ImagePicker();

//   bool _isProcessed = false;
//   bool _isWorking = false;
//   bool isInitialized = false;

//   late Uint8List _image;
//   late List<Uint8List> rankImages;
//   late List<Size> rankImageSizes;
//   late List<Uint8List> suitImages;
//   late List<Size> suitImageSizes;

//   Future<void> initializeImages() async {
//     // Load rank and suit images
//     rankImages = [];
//     rankImageSizes = [];
//     suitImages = [];
//     suitImageSizes = [];
//     for (var i = 0; i < 13; i++) {
//       for (var j = 0; j < 2; j++) {
//         final filePath = "./assets/${i + 1}_$j.JPG";
//         final image = await rootBundle.load(filePath);
//         final buffer = image.buffer;
//         final img = imglib.decodeImage(buffer.asUint8List().toList());
//         final int width = img?.width ?? 0;
//         final int height = img?.height ?? 0;
//         rankImageSizes.add(Size(width, height));
//         rankImages.add(imageToByteUint8List(img!));
//       }
//     }

//     const SUITS = ["c", "d", "h", "s"];
//     for (var i = 0; i < 4; i++) {
//       for (var j = 0; j < 2; j++) {
//         final filePath = "assets/${SUITS[i]}_$j.JPG";

//         final image = await rootBundle.load(filePath);
//         final buffer = image.buffer;
//         final img = imglib.decodeImage(buffer.asUint8List().toList());
//         final int width = img?.width ?? 0;
//         final int height = img?.height ?? 0;
//         suitImageSizes.add(Size(width, height));
//         suitImages.add(imageToByteUint8List(img!));
//       }
//     }

//     setState(() {
//       isInitialized = true;
//     });
//   }

//   @override
//   void initState() {
//     super.initState();

//     initializeImages();
//   }

//   void showVersion() {
//     final scaffoldMessenger = ScaffoldMessenger.of(context);
//     final snackbar = SnackBar(
//       content: Text('OpenCV version: ${opencvVersion()}'),
//     );

//     scaffoldMessenger
//       ..removeCurrentSnackBar(reason: SnackBarClosedReason.dismiss)
//       ..showSnackBar(snackbar);
//   }

//   Future<String?> pickAnImage() async {
//     if (Platform.isIOS || Platform.isAndroid) {
//       return _picker
//           .pickImage(
//             source: ImageSource.gallery,
//             imageQuality: 100,
//           )
//           .then((v) => v?.path);
//     } else {
//       return FilePicker.platform
//           .pickFiles(
//             dialogTitle: 'Pick an image',
//             type: FileType.image,
//             allowMultiple: false,
//           )
//           .then((v) => v?.files.first.path);
//     }
//   }

//   Future<void> takeImageAndProcess() async {
//     final imagePath = await pickAnImage();

//     if (imagePath == null) {
//       return;
//     }

//     setState(() {
//       _isWorking = true;
//     });
//     final imageBytes = File(imagePath).readAsBytesSync();

//     // final image = await rootBundle.load(imagePath);
//     // final buffer = image.buffer;
//     final img = imglib.decodeImage(imageBytes.toList());
//     final int width = img?.width ?? 0;
//     final int height = img?.height ?? 0;

//     final inputSize = Size(width, height);
//     final args = ProcessImageArguments(
//       imageToByteUint8List(img!),
//       inputSize,
//       rankImages,
//       rankImageSizes,
//       suitImages,
//       suitImageSizes,
//     );
//     processImage(args).then((image) {
//       setState(() {
//         _isProcessed = true;
//         print(image);
//         _image =
//             Uint8List.fromList(imglib.encodeJpg(imglib.Image.rgb(400, 400)));
//         _isWorking = false;
//       });
//     });

//     // // Creating a port for communication with isolate and arguments for entry point
//     // final port = ReceivePort();
//     // final args = ProcessImageArguments(imagePath, tempPath);

//     // // Spawning an isolate
//     // Isolate.spawn<ProcessImageArguments>(
//     //   processImage,
//     //   args,
//     //   onError: port.sendPort,
//     //   onExit: port.sendPort,
//     // );

//     // // Making a variable to store a subscription in
//     // late StreamSubscription sub;

//     // // Listening for messages on port
//     // sub = port.listen((_) async {
//     //   // Cancel a subscription after message received called
//     //   await sub.cancel();

//     //   setState(() {
//     //     _isProcessed = true;
//     //     _isWorking = false;
//     //   });
//     // });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(title)),
//       body: Stack(
//         children: <Widget>[
//           Center(
//             child: ListView(
//               shrinkWrap: true,
//               children: <Widget>[
//                 if (_isProcessed && !_isWorking)
//                   ConstrainedBox(
//                     constraints: BoxConstraints(maxWidth: 3000, maxHeight: 700),
//                     child: Image.memory(
//                       _image,
//                       alignment: Alignment.center,
//                     ),
//                   ),
//                 Column(
//                   children: [
//                     ElevatedButton(
//                       child: Text('Show version'),
//                       onPressed: showVersion,
//                     ),
//                     ElevatedButton(
//                       child: Text('Process photo'),
//                       onPressed: takeImageAndProcess,
//                     ),
//                   ],
//                 )
//               ],
//             ),
//           ),
//           if (_isWorking)
//             Positioned.fill(
//               child: Container(
//                 color: Colors.black.withOpacity(.7),
//                 child: Center(
//                   child: CircularProgressIndicator(),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// Uint8List imageToByteUint8List(imglib.Image image) {
//   var convertedBytes = Uint8List(image.height * image.width * 3);
//   var buffer = Uint8List.view(convertedBytes.buffer);
//   int pixelIndex = 0;
//   try {
//     for (var i = 0; i < image.height; i++) {
//       for (var j = 0; j < image.width; j++) {
//         var pixel = image.getPixel(j, i);
//         buffer[pixelIndex++] = imglib.getRed(pixel);
//         buffer[pixelIndex++] = imglib.getGreen(pixel);
//         buffer[pixelIndex++] = imglib.getBlue(pixel);
//       }
//     }
//   } catch (e) {
//     print(e.toString());
//   }
//   return convertedBytes.buffer.asUint8List();
// }
