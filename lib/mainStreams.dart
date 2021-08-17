import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_searcher_ai/ai/aiHelper.dart';
import 'package:image_searcher_ai/data/classes.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'serif'),
      home: MyHomePage(title: 'Smart Gallery'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool permitted = false;
  late List<SmartGallery> smartGallery = [];
  late List<SmartGallery> smartGalleryCopy = [];
  late TextEditingController searchController;
  late StreamController<SmartGallery> streamController;
  final _onDeviceTranslator = GoogleMlKit.nlp.onDeviceTranslator(
      sourceLanguage: TranslateLanguage.ENGLISH,
      targetLanguage: TranslateLanguage.ARABIC);

  @override
  void initState() {
    // TODO: implement initState
    requestPermission();
    _fetchImages();
    searchController = new TextEditingController();
    streamController = new StreamController<SmartGallery>();
    streamController.stream.listen((smart) {
      setState(() {
        smartGallery.add(smart);
        smartGalleryCopy.add(smart);
      });
    }).onDone(() {
      print("done");
    });
    super.initState();
  }

  @override
  void dispose() {
    streamController.close();
    _onDeviceTranslator.close();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [IconButton(onPressed: () {}, icon: Icon(Icons.inbox_sharp))],
      ),
      body: Column(
        children: [
          TextField(
            onChanged: (text) {
              text = text.trim();
              if (text.isNotEmpty)
                search(text);
              else
                setState(() {
                  clearSearch();
                });
            },
            decoration: new InputDecoration(
                prefixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      clearSearch();
                    });
                  },
                  icon: Icon(Icons.close),
                ),
                hintText: "Search here..",
                hintStyle: new TextStyle(color: Colors.white)),
            controller: searchController,
          ),
          Expanded(child: buildGrid(smartGallery: smartGallery)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchImages,
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void clearSearch() {
    print('clearSearch');
    smartGallery = smartGalleryCopy;
    searchController.clear();
    print('original ${smartGallery.length}');
    print('copy ${smartGalleryCopy.length}');
  }

  Center buildRequestFunction() {
    return Center(
      child: Column(
        children: [
          IconButton(
              onPressed: requestPermission,
              icon: Icon(
                Icons.image_not_supported_rounded,
                size: 100,
              )),
          Text("Press to request permission"),
        ],
      ),
    );
  }

  GridView buildGrid({required List<SmartGallery> smartGallery}) {
    return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        itemCount: smartGallery.length,
        itemBuilder: (_, index) {
          return AssetThumbnail(
            asset: smartGallery[index].images,
            imageLabels: smartGallery[index].labels,
            imageBytes: smartGallery[index].imageByte,
            translated: smartGallery[index].translatedLabels,
          );
        });
  }

  void requestPermission() async {
    setState(() async {
      permitted = await PhotoManager.requestPermission();
    });
  }

  _fetchImages() async {
    await TranslatorHelper().checkModels();
    final albums = await PhotoManager.getAssetPathList(
        onlyAll: true, type: RequestType.image);
    final recentAlbum = albums.first;
    // Now that we got the album, fetch all the assets it contains
    var assets = await recentAlbum.getAssetListPaged(0, 10);
    await processTheAssets(assets);
  }

  processTheAssets(List<AssetEntity> recentAssets) async {
    for (final asset in recentAssets) {
      Uint8List? bytes = await asset.thumbData;
      final imgLabel = await processImage(asset: asset);
      final translate = await translateLabels(imgLabel);
      streamController.add(new SmartGallery(
          images: asset,
          labels: imgLabel,
          imageByte: bytes,
          translatedLabels: translate));
    }
  }

  Future<List<TranslatedImageLabel>> translateLabels(
      List<ImageLabel> imgLabel) async {
    List<TranslatedImageLabel> translation = [];
    for (final label in imgLabel) {
      final translate = await translateText(text: label.label);
      print('the translation for ${label.label} = $translate');
      translation.add(new TranslatedImageLabel(translate));
    }
    return translation;
  }

  Future<List<ImageLabel>> processImage({required AssetEntity asset}) async {
    return asset.file.then((value) async {
      late List<ImageLabel> processImage;
      final inputImage = InputImage.fromFile(value!);
      ImageLabeler imageLabeler = GoogleMlKit.vision.imageLabeler();
      processImage = await imageLabeler
          .processImage(inputImage)
          .catchError((error, stackTrace) {
        print("outer: $error");
      });

      return processImage;
    });
  }

  Future<String> translateText({required String text}) async {
    return await _onDeviceTranslator.translateText(text);
  }

  void search(String text) {
    var find = smartGallery.where((element) =>
        element.translatedLabels.first.translatedLabel.contains(text));
    for (final f in find) {
      print(f.translatedLabels.first.translatedLabel);
    }
    setState(() {
      smartGallery = find.toList();
      print(smartGallery.length);
    });
  }
}

class AssetThumbnail extends StatelessWidget {
  const AssetThumbnail(
      {Key? key,
      required this.asset,
      required this.imageLabels,
      required this.imageBytes,
      required this.translated})
      : super(key: key);

  final AssetEntity asset;
  final List<ImageLabel> imageLabels;
  final Uint8List? imageBytes;
  final List<TranslatedImageLabel> translated;

  @override
  Widget build(BuildContext context) {
    // We're using a FutureBuilder since thumbData is a future
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageScreen(
              imageFile: asset.file,
              imgLabels: imageLabels,
              translateLabel: translated,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          // Wrap the image in a Positioned.fill to fill the space
          Positioned.fill(
            child: Image.memory(imageBytes!, fit: BoxFit.cover),
          ),
          // Display a Play icon if the asset is a video
          Container(
            color: Colors.black26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  // ' ${imageLabels.isEmpty ? 'no labels' : imageLabels.first.label} | ${translated.first.translatedLabel} ',
                  ' ${translated.first.translatedLabel} ',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ImageScreen extends StatefulWidget {
  ImageScreen({
    Key? key,
    required this.imageFile,
    required this.imgLabels,
    required this.translateLabel,
  }) : super(key: key);

  Future<File?> imageFile;
  List<ImageLabel> imgLabels;
  List<TranslatedImageLabel> translateLabel;

  @override
  _ImageScreenState createState() =>
      _ImageScreenState(imageFile, imgLabels, translateLabel);
}

class _ImageScreenState extends State<ImageScreen> {
  File? imageActualFile;
  Future<File?> imageFile;
  List<ImageLabel> imgLabels;
  List<TranslatedImageLabel> translateLabel;

  _ImageScreenState(this.imageFile, this.imgLabels, this.translateLabel);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            print("presing");
            recogniseText();
          },
          label: Text('إستخراج النص')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: imageActualFile != null
                  ? Image.file(imageActualFile!)
                  : FutureBuilder<File?>(
                      future: imageFile,
                      builder: (_, snapshot) {
                        final file = snapshot.data;
                        if (file == null) return Text("Error Loading Image");
                        setState(() { imageActualFile = file;});
                        return CircularProgressIndicator();
                      },
                    )),
          buildList()
        ],
      ),
    );
  }

  SizedBox buildList() {
    return SizedBox.expand(
      child: DraggableScrollableSheet(
        initialChildSize: 0.25,
        builder: (BuildContext context, ScrollController scrollController) {
          return Container(
            color: Colors.black26,
            child: ListView.builder(
              controller: scrollController,
              itemCount: widget.imgLabels.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  subtitle: Text(
                    ' ${widget.imgLabels[index].label}  ${(widget.imgLabels[index].confidence * 100).truncate()}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  title: Text(
                    '${widget.translateLabel[index].translatedLabel}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  recogniseText() async {
    print("processting text");
    TextDetector textDetector = GoogleMlKit.vision.textDetector();
    InputImage inputImage = InputImage.fromFile(imageActualFile!);
    final recognisedText = await textDetector.processImage(inputImage);
    for (final textBlock in recognisedText.blocks) {
      if(!textBlock.recognizedLanguages.contains("un"))
      print(' text : ${  textBlock.text } ');

    }
  }

  Future<List<ImageLabel>> processImage({required Future<File?> file}) async {
    return file.then((value) async {
      final inputImage = InputImage.fromFile(value!);
      ImageLabeler imageLabeler = GoogleMlKit.vision.imageLabeler();
      return await imageLabeler.processImage(inputImage);
    });
  }

  void createImage() async {
    await imageFile.then((value) => imageActualFile = value);
  }
}
