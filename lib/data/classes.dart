


import 'dart:typed_data';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:photo_manager/photo_manager.dart';

class SmartGallery{
 late AssetEntity images;
 late List<ImageLabel> labels;
 late List<TranslatedImageLabel> translatedLabels;
 late Uint8List? imageByte;

 SmartGallery({required this.images,required this.labels, required this.imageByte , required this.translatedLabels });
}

class TranslatedImageLabel{
 final translatedLabel;
  TranslatedImageLabel(this.translatedLabel);
}


