import 'package:flutter/material.dart';
import 'dart:math' as math;

class LabelUtils {
  static const SUITS = ["unk", "c", "d", "h", "s"];
  static const RANKS = [
    "unk",
    "A",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
    "J",
    "Q",
    "K"
  ];
  static String mapSuit(int index) {
    if (index >= 0 && index < SUITS.length) {
      return SUITS[index];
    }
    return SUITS[0];
  }

  static String mapRank(int index) {
    if (index > 0 && index < RANKS.length) {
      return RANKS[index];
    }
    return "unk";
  }
}

class BoundingBox extends StatelessWidget {
  final Map<String, dynamic> results;
  final int previewH;
  final int previewW;
  final double screenH;
  final double screenW;

  BoundingBox(
    this.results,
    this.previewH,
    this.previewW,
    this.screenH,
    this.screenW,
  );

  @override
  Widget build(BuildContext context) {
    List<Widget> _renderBox() {
      if (results.length <= 0 || results["len"] == 0) {
        return [];
      }
      final bboxes = results["bboxes"];
      final ranks = results["ranks"];
      final suits = results["suits"];
      final len = results["len"];

      List<Widget> rets = [];
      for (var i = 0; i < len; i++) {
        var bbox = bboxes[i];
        var _x = bbox[0];
        var _y = bbox[1];
        var _w = bbox[2] - bbox[0];
        var _h = bbox[3] - bbox[1];

        var scaleW, scaleH, x, y, w, h;

        // if (screenH / screenW > previewH / previewW) {
        //   scaleW = screenH / previewH * previewW;
        //   scaleH = screenH;
        //   var difW = (scaleW - screenW) / scaleW;
        //   x = (_x - difW / 2) * scaleW;
        //   w = _w * scaleW;
        //   if (_x < difW / 2) w -= (difW / 2 - _x) * scaleW;
        //   y = _y * scaleH;
        //   h = _h * scaleH;
        // } else {
        //   scaleH = screenW / previewW * previewH;
        //   scaleW = screenW;
        //   var difH = (scaleH - screenH) / scaleH;
        //   x = _x * scaleW;
        //   w = _w * scaleW;
        //   y = (_y - difH / 2) * scaleH;
        //   h = _h * scaleH;
        //   if (_y < difH / 2) h -= (difH / 2 - _y) * scaleH;
        // }
        w = screenW * _h;
        h = w * _h / _w;
        y = screenH * _x;
        x = screenW - screenW * _y - w;
        print("=============== x, y, w, h: $x $y $w $h");
        print("=============== screen hw: $screenH $screenW");

        final p = Positioned(
          left: math.max(0, x),
          top: math.max(0, y),
          width: w,
          height: h,
          child: Container(
            padding: EdgeInsets.only(top: 5.0, left: 5.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: Color.fromRGBO(37, 213, 253, 1.0),
                width: 3.0,
              ),
            ),
            child: Text(
              // "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
              "${LabelUtils.mapRank(ranks[i])}${LabelUtils.mapSuit(suits[i])}",
              style: TextStyle(
                color: Color.fromRGBO(37, 213, 253, 1.0),
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

        rets.add(p);
      }
      return rets;
      // return results.map((re) {
      //   var _x = re["rect"]["x"];
      //   var _w = re["rect"]["w"];
      //   var _y = re["rect"]["y"];
      //   var _h = re["rect"]["h"];
      //   var scaleW, scaleH, x, y, w, h;

      //   if (screenH / screenW > previewH / previewW) {
      //     scaleW = screenH / previewH * previewW;
      //     scaleH = screenH;
      //     var difW = (scaleW - screenW) / scaleW;
      //     x = (_x - difW / 2) * scaleW;
      //     w = _w * scaleW;
      //     if (_x < difW / 2) w -= (difW / 2 - _x) * scaleW;
      //     y = _y * scaleH;
      //     h = _h * scaleH;
      //   } else {
      //     scaleH = screenW / previewW * previewH;
      //     scaleW = screenW;
      //     var difH = (scaleH - screenH) / scaleH;
      //     x = _x * scaleW;
      //     w = _w * scaleW;
      //     y = (_y - difH / 2) * scaleH;
      //     h = _h * scaleH;
      //     if (_y < difH / 2) h -= (difH / 2 - _y) * scaleH;
      //   }

      //   return Positioned(
      //     left: math.max(0, x),
      //     top: math.max(0, y),
      //     width: w,
      //     height: h,
      //     child: Container(
      //       padding: EdgeInsets.only(top: 5.0, left: 5.0),
      //       decoration: BoxDecoration(
      //         border: Border.all(
      //           color: Color.fromRGBO(37, 213, 253, 1.0),
      //           width: 3.0,
      //         ),
      //       ),
      //       child: Text(
      //         "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
      //         style: TextStyle(
      //           color: Color.fromRGBO(37, 213, 253, 1.0),
      //           fontSize: 14.0,
      //           fontWeight: FontWeight.bold,
      //         ),
      //       ),
      //     ),
      //   );
      // }).toList();
    }

    return Stack(
      children: _renderBox(),
    );
  }
}
