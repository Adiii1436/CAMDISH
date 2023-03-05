import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

List<dynamic> icons = [
  [1.0, const Icon(Icons.exposure_plus_1)],
  [2.0, const Icon(Icons.exposure_plus_2)],
  [-1.0, const Icon(Icons.exposure_minus_1)],
  [-2.0, const Icon(Icons.exposure_minus_2)],
  [0.0, const Icon(Icons.exposure_zero)]
];
List<dynamic> resolutions = [
  [ResolutionPreset.high, 'High'],
  [ResolutionPreset.ultraHigh, 'Ultra High'],
  [ResolutionPreset.max, 'Max'],
  [ResolutionPreset.low, 'Low'],
  [ResolutionPreset.medium, 'Medium']
];
