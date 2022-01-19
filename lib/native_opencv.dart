import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:image/image.dart' as imglib;

class Results extends ffi.Struct {
  external ffi.Pointer<ffi.Double> bboxes;
  external ffi.Pointer<ffi.Uint32> ranks;
  external ffi.Pointer<ffi.Uint32> suits;

  @ffi.Int64()
  external int len;
}

// C function signatures
typedef _CVersionFunc = ffi.Pointer<Utf8> Function();
typedef _CProcessImageFunc = Results Function(
  ffi.Int32,
  ffi.Int32,
  ffi.Int32,
  ffi.Pointer<ffi.Uint8>,
  ffi.Pointer<ffi.Uint32>,
  ffi.Pointer<ffi.Uint32>,
  ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
  ffi.Pointer<ffi.Uint32>,
  ffi.Pointer<ffi.Uint32>,
  ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
);
typedef _FreeStructNative = ffi.Void Function(Results rs);
typedef _CConvertYUV420ToRGB = ffi.Pointer<ffi.Uint32> Function(
  ffi.Pointer<ffi.Uint8>,
  ffi.Pointer<ffi.Uint8>,
  ffi.Pointer<ffi.Uint8>,
  ffi.Int32,
  ffi.Int32,
  ffi.Int32,
  ffi.Int32,
);

// Dart function signatures
typedef _VersionFunc = ffi.Pointer<Utf8> Function();
typedef _ProcessImageFunc = Results Function(
  int,
  int,
  int,
  ffi.Pointer<ffi.Uint8>,
  ffi.Pointer<ffi.Uint32>,
  ffi.Pointer<ffi.Uint32>,
  ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
  ffi.Pointer<ffi.Uint32>,
  ffi.Pointer<ffi.Uint32>,
  ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
);

typedef _FreeStruct = void Function(Results rs);

typedef _ConvertYUV420ToRGB = ffi.Pointer<ffi.Uint32> Function(
  ffi.Pointer<ffi.Uint8>,
  ffi.Pointer<ffi.Uint8>,
  ffi.Pointer<ffi.Uint8>,
  int,
  int,
  int,
  int,
);

// Getting a library that holds needed symbols
ffi.DynamicLibrary _openDynamicLibrary() {
  if (Platform.isAndroid) {
    return ffi.DynamicLibrary.open('libnative_opencv.so');
  } else if (Platform.isWindows) {
    return ffi.DynamicLibrary.open("native_opencv_windows_plugin.dll");
  }

  return ffi.DynamicLibrary.process();
}

ffi.DynamicLibrary _lib = _openDynamicLibrary();

// Looking for the functions
final _VersionFunc _version =
    _lib.lookup<ffi.NativeFunction<_CVersionFunc>>('version').asFunction();
final _ProcessImageFunc _processImage = _lib
    .lookup<ffi.NativeFunction<_CProcessImageFunc>>('process_image')
    .asFunction();

final _FreeStruct _freeStruct = _lib
    .lookup<ffi.NativeFunction<_FreeStructNative>>('free_struct')
    .asFunction();

final _ConvertYUV420ToRGB _convertYUV420ToRGBCore = _lib
    .lookup<ffi.NativeFunction<_CConvertYUV420ToRGB>>('convert_yuv420_to_rgb')
    .asFunction();

String opencvVersion() {
  return _version().toDartString();
}

ffi.Pointer<ffi.Uint32> convertYUV420ToRGB(
  ffi.Pointer<ffi.Uint8> p0,
  ffi.Pointer<ffi.Uint8> p1,
  ffi.Pointer<ffi.Uint8> p2,
  int bytesPerRow,
  int bytesPerPixel,
  int width,
  int height,
) {
  return _convertYUV420ToRGBCore(
      p0, p1, p2, bytesPerRow, bytesPerPixel, width, height);
}

Future<Map<String, dynamic>> processImage(ProcessImageArguments args) async {
  var rankImageHeightsUint32 = Uint32List(args.rankImageSizes.length);
  var rankImageWidthsUint32 = Uint32List(args.rankImageSizes.length);
  for (var i = 0; i < args.rankImageSizes.length; i++) {
    rankImageHeightsUint32[i] = args.rankImageSizes[i].height;
    rankImageWidthsUint32[i] = args.rankImageSizes[i].width;
  }

  var suitImageHeightsUint32 = Uint32List(args.suitImageSizes.length);
  var suitImageWidthsUint32 = Uint32List(args.suitImageSizes.length);
  for (var i = 0; i < args.suitImageSizes.length; i++) {
    suitImageHeightsUint32[i] = args.suitImageSizes[i].height;
    suitImageWidthsUint32[i] = args.suitImageSizes[i].width;
  }

  final inputImagePt = toUint8Pointer(args.inputImage);
  final rankImageHeightsPt = toUint32Pointer(rankImageHeightsUint32);
  final rankImageWidthsPt = toUint32Pointer(rankImageWidthsUint32);
  final rankImagesPt = toArrayOfPointers(args.rankImages);
  final suitImageHeightsPt = toUint32Pointer(suitImageHeightsUint32);
  final suitImageWidthsPt = toUint32Pointer(suitImageWidthsUint32);
  final suitImagesPt = toArrayOfPointers(args.suitImages);

  // Process
  final outputData = _processImage(
    args.inputImage.length,
    args.inputImageSize.height,
    args.inputImageSize.width,
    inputImagePt,
    rankImageHeightsPt,
    rankImageWidthsPt,
    rankImagesPt,
    suitImageHeightsPt,
    suitImageWidthsPt,
    suitImagesPt,
  );

  final nums = outputData.len;
  List<List<double>> bboxes = [];
  var ranks = Uint32List(0);
  var suits = Uint32List(0);
  var len = 0;
  if (nums > 0) {
    len = nums;
    final rawBboxesList =
        Float64List.fromList(outputData.bboxes.asTypedList(4 * nums));
    ranks = Uint32List.fromList(outputData.ranks.asTypedList(nums));
    suits = Uint32List.fromList(outputData.suits.asTypedList(nums));
    var index = 0;
    for (var i = 0; i < nums; i++) {
      List<double> bbox = [];
      for (var j = 0; j < 4; j++) {
        bbox.add(rawBboxesList[index++].toDouble());
      }
      bboxes.add(bbox);
    }
  }

  // final outputImageList =
  //     Uint8List.fromList(outputBuffer.asTypedList(outputLen));

  // final viewImage = imglib.Image.fromBytes(
  //   args.inputImageSize.width,
  //   args.inputImageSize.height,
  //   outputImageList,
  // );
  // final retImage = Uint8List.fromList(imglib.encodeJpg(viewImage));
  // calloc.free(outputData.bboxes);
  // calloc.free(outputData.ranks);
  // calloc.free(outputData.suits);
  // _freeStruct(outputData);

  calloc.free(inputImagePt);
  calloc.free(rankImageHeightsPt);
  calloc.free(rankImageWidthsPt);
  calloc.free(suitImageHeightsPt);
  calloc.free(suitImageWidthsPt);

  for (var i = 0; i < args.rankImageSizes.length; i++) {
    calloc.free(rankImagesPt[i]);
  }
  calloc.free(rankImagesPt);
  for (var i = 0; i < args.suitImageSizes.length; i++) {
    calloc.free(suitImagesPt[i]);
  }
  calloc.free(suitImagesPt);

  var ret = {
    "bboxes": bboxes,
    "ranks": ranks,
    "suits": suits,
    "len": len,
  };
  return ret;
}

class ProcessImageArguments {
  final Uint8List inputImage;
  final Size inputImageSize;
  final List<Uint8List> rankImages;
  final List<Size> rankImageSizes;
  final List<Uint8List> suitImages;
  final List<Size> suitImageSizes;

  ProcessImageArguments(
    this.inputImage,
    this.inputImageSize,
    this.rankImages,
    this.rankImageSizes,
    this.suitImages,
    this.suitImageSizes,
  );
}

ffi.Pointer<Utf8> toUtf8Pointer(String inputs) {
  return inputs.toNativeUtf8();
}

ffi.Pointer<ffi.Uint8> toUint8Pointer(Uint8List inputs) {
  var outBuffer = calloc<ffi.Uint8>(inputs.length);
  outBuffer.asTypedList(inputs.length).setAll(0, inputs);
  return outBuffer;
}

ffi.Pointer<ffi.Uint32> toUint32Pointer(Uint32List inputs) {
  var outBuffer = calloc<ffi.Uint32>(inputs.length);
  outBuffer.asTypedList(inputs.length).setAll(0, inputs);
  return outBuffer;
}

ffi.Pointer<ffi.Pointer<ffi.Uint8>> toArrayOfPointers(List<Uint8List> inputs) {
  List<ffi.Pointer<ffi.Uint8>> uint8PointerList = [];
  for (var i = 0; i < inputs.length; i++) {
    uint8PointerList.add(toUint8Pointer(inputs[i]));
  }
  // inputs.map((e) => toUint8Pointer(e)).toList();

  final ffi.Pointer<ffi.Pointer<ffi.Uint8>> pointerPointer =
      calloc<ffi.Pointer<ffi.Uint8>>(inputs.length);

  // inputs.asMap().forEach((key, value) {
  //   pointerPointer[key] = uint8PointerList[key];
  // });
  for (var i = 0; i < inputs.length; i++) {
    pointerPointer[i] = uint8PointerList[i];
  }

  return pointerPointer;
}
