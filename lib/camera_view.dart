import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'native_opencv.dart';
import 'package:image/image.dart' as imglib;
import 'package:flutter/services.dart' show rootBundle;
import 'package:ffi/ffi.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';

typedef void Callback(Map<String, dynamic> rs, int h, int w);

class CameraFeed extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Callback setResults;
  // The cameraFeed Class takes the cameras list and the setRecognitions
  // function as argument
  CameraFeed(this.cameras, this.setResults);

  @override
  _CameraFeedState createState() => new _CameraFeedState();
}

class _CameraFeedState extends State<CameraFeed> {
  late CameraController controller;
  late List<Uint8List> rankImages;
  late List<Size> rankImageSizes;
  late List<Uint8List> suitImages;
  late List<Size> suitImageSizes;
  bool isDetecting = false;
  bool isInitialized = false;
  int index = 0;

  @override
  void initState() {
    super.initState();

    // Initialize images
    initializeImages();

    if (widget.cameras.length < 1) {
      print('No Cameras Found.');
    } else {
      controller = new CameraController(
        widget.cameras[0],
        ResolutionPreset.low,
      );
      controller.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});

        controller.startImageStream((CameraImage image) {
          if (isInitialized) {
            // setState(() {
            //   isDetecting = true;
            // });
            final img = convertCameraImage(image);

            final inputSize = Size(image.width, image.height);
            final args = ProcessImageArguments(
              img,
              inputSize,
              rankImages,
              rankImageSizes,
              suitImages,
              suitImageSizes,
            );
            index++;
            if (index % 10 == 0) {
              processImage(args).then((results) {
                isDetecting = false;
                print("============== Results: $results");
                widget.setResults(results, image.height, image.width);
              });
              index = 0;
            }
          }
        });
      });
    }
  }

  Future<void> initializeImages() async {
    // Load rank and suit images
    rankImages = [];
    rankImageSizes = [];
    suitImages = [];
    suitImageSizes = [];
    for (var i = 0; i < 13; i++) {
      for (var j = 0; j < 2; j++) {
        final filePath = "./assets/${i + 1}_$j.JPG";
        final image = await rootBundle.load(filePath);
        final buffer = image.buffer;
        final img = imglib.decodeImage(buffer.asUint8List().toList());
        final int width = img?.width ?? 0;
        final int height = img?.height ?? 0;
        rankImageSizes.add(Size(width, height));
        rankImages.add(imageToByteUint8List(img!));
      }
    }

    const SUITS = ["c", "d", "h", "s"];
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 2; j++) {
        final filePath = "assets/${SUITS[i]}_$j.JPG";

        final image = await rootBundle.load(filePath);
        final buffer = image.buffer;
        final img = imglib.decodeImage(buffer.asUint8List().toList());
        final int width = img?.width ?? 0;
        final int height = img?.height ?? 0;
        suitImageSizes.add(Size(width, height));
        suitImages.add(imageToByteUint8List(img!));
      }
    }

    setState(() {
      isInitialized = true;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }

    var tmp = MediaQuery.of(context).size;
    var screenH = math.max(tmp.height, tmp.width);
    var screenW = math.min(tmp.height, tmp.width);
    tmp = controller.value.previewSize!;
    var previewH = math.max(tmp.height, tmp.width);
    var previewW = math.min(tmp.height, tmp.width);
    var screenRatio = screenH / screenW;
    var previewRatio = previewH / previewW;
    print("============== Screen ratio: $screenH $screenW");

    return OverflowBox(
      maxHeight: screenH,
      // screenRatio > previewRatio ? screenH : screenW / previewW * previewH,
      maxWidth: screenW,
      // screenRatio > previewRatio ? screenH / previewH * previewW : screenW,
      child: CameraPreview(controller),
      // child: _build(),
    );
  }
}

Uint8List convertCameraImage(CameraImage cameraImage) {
  var retImage = imglib.Image(cameraImage.width, cameraImage.height);
  if (cameraImage.format.group == ImageFormatGroup.yuv420) {
    retImage = convertYUV420ToImage(cameraImage);
  } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
    retImage = convertBGRA8888ToImage(cameraImage);
  }
  return imageToByteUint8List(retImage);
}

imglib.Image convertBGRA8888ToImage(CameraImage cameraImage) {
  imglib.Image img = imglib.Image.fromBytes(cameraImage.planes[0].width!,
      cameraImage.planes[0].height!, cameraImage.planes[0].bytes,
      format: imglib.Format.bgra);
  return img;
}

/// Converts a [CameraImage] in YUV420 format to [imageLib.Image] in RGB format
imglib.Image convertYUV420ToImage(CameraImage cameraImage) {
  final int width = cameraImage.width;
  final int height = cameraImage.height;

  final int pixelStride = cameraImage.planes[0].bytesPerRow;
  final int uvRowStride = cameraImage.planes[1].bytesPerRow;
  final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

  final image = imglib.Image(width, height);

  for (int y = 0; y < height; y++) {
    final yUvIndex = uvRowStride * (y / 2).floor();
    final yPixelIndex = y * pixelStride;
    for (int x = 0; x < width; x++) {
      final int uvIndex = uvPixelStride * (x / 2).floor() + yUvIndex;
      final int index = yPixelIndex + x;

      final yp = cameraImage.planes[0].bytes[index];
      final up = cameraImage.planes[1].bytes[uvIndex];
      final vp = cameraImage.planes[2].bytes[uvIndex];

      int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255).toInt();
      int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
          .round()
          .clamp(0, 255)
          .toInt();
      int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255).toInt();

      image.setPixelRgba(x, y, r, g, b);
    }
  }
  return image;
}

Uint8List imageToByteUint8List(imglib.Image image) {
  var convertedBytes = Uint8List(image.height * image.width * 3);
  var buffer = Uint8List.view(convertedBytes.buffer);
  int pixelIndex = 0;
  try {
    for (var i = 0; i < image.height; i++) {
      for (var j = 0; j < image.width; j++) {
        var pixel = image.getPixel(j, i);
        final r = imglib.getRed(pixel);
        final g = imglib.getGreen(pixel);
        final b = imglib.getBlue(pixel);
        buffer[pixelIndex++] = imglib.getRed(pixel);
        buffer[pixelIndex++] = imglib.getGreen(pixel);
        buffer[pixelIndex++] = imglib.getBlue(pixel);
      }
    }
  } catch (e) {
    print(e.toString());
  }
  return convertedBytes.buffer.asUint8List();
}
