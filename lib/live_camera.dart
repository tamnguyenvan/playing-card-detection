import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'camera_view.dart';
import 'dart:math' as math;
import 'bounging_box.dart';

class LiveFeed extends StatefulWidget {
  final List<CameraDescription> cameras;
  LiveFeed(this.cameras);
  @override
  _LiveFeedState createState() => _LiveFeedState();
}

class _LiveFeedState extends State<LiveFeed> {
  Map<String, dynamic> _results = {};
  int _imageHeight = 0;
  int _imageWidth = 0;
  initCameras() async {}

  /* 
  The set recognitions function assigns the values of recognitions, imageHeight and width to the variables defined here as callback
  */
  setResults(results, imageHeight, imageWidth) {
    setState(() {
      print("=========== hw: $imageHeight $imageWidth");
      _results = results;
      _imageHeight = imageHeight;
      _imageWidth = imageWidth;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text("Playing Card Detection"),
      ),
      body: Stack(
        children: [
          CameraFeed(widget.cameras, setResults),
          BoundingBox(
            _results,
            math.max(_imageHeight, _imageWidth),
            math.min(_imageHeight, _imageWidth),
            screen.height,
            screen.width,
          ),
        ],
      ),
    );
  }
}
