import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
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
      theme: ThemeData(
        primarySwatch: Colors.brown,
        accentColor: Colors.deepOrangeAccent,
        fontFamily: 'serif',
      ),
      home: MyHomePage(title: 'الألبوم الذكي'),
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
  late StreamController<String> streamControllerString;
  int processedImages = 0;
  int totalImages = 0;
  bool isDoneFetching = false;
  final _onDeviceTranslator = GoogleMlKit.nlp.onDeviceTranslator(
      sourceLanguage: TranslateLanguage.ENGLISH,
      targetLanguage: TranslateLanguage.ARABIC);

  late ImagePicker _imagePicker;

  @override
  void initState() {
    // TODO: implement initState
    requestPermission();
    computeImage();
    searchController = new TextEditingController();
    streamController = new StreamController<SmartGallery>();
    streamController.stream.listen((smart) {
      smartGallery.add(smart);
      smartGalleryCopy.add(smart);
      setState(() {
        processedImages++;
      });
    }).onDone(() {
      print("on done is called");
      setState(() {

      });
    });
    _imagePicker = ImagePicker();
    super.initState();
  }

  @override
  void dispose() {
    streamController.close();
    streamControllerString.close();
    _onDeviceTranslator.close();
    searchController.dispose();
    super.dispose();
  }

  Future _getImage() async {
    final pickedFile =
        await _imagePicker?.getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      var imageActualFile = File(pickedFile.path);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExtractText(
            imageActualFile: imageActualFile,
          ),
        ),
      );
    } else {
      print('No image selected.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [IconButton(onPressed: () {computeImage();}, icon: Icon(Icons.inbox_sharp))],
      ),
      body: isDoneFetching
          ? buildMainBody()
          : Text('we are processing $processedImages / $totalImages'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _getImage();
        },
        icon: Icon(Icons.image),
        label: Text('إستخرج أي نص من صورة'),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Column buildMainBody() {
    return Column(
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
              filled: true,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    clearSearch();
                  });
                },
                icon: Icon(Icons.close),
              ),
              prefixIcon: Icon(Icons.image_search_rounded),
              hintText: "إبحث في الصور",
              hintTextDirection: TextDirection.rtl,
              hintStyle: new TextStyle(color: Colors.grey)),
          textDirection: TextDirection.rtl,
          controller: searchController,
        ),
        Expanded(child: buildGrid(smartGallery: smartGallery)),
      ],
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

  Widget buildGrid({required List<SmartGallery> smartGallery}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: smartGallery.length,
          itemBuilder: (_, index) {
            return AssetThumbnail(
              asset: smartGallery[index].images,
              imageLabels: smartGallery[index].labels,
              imageBytes: smartGallery[index].imageByte,
              translated: smartGallery[index].translatedLabels,
            );
          }),
    );
  }

  void requestPermission() async {
    setState(() async {
      permitted = await PhotoManager.requestPermission();
    });
  }

  computeImage() async {
    await compute(_fetchImages(), 2);
  }

  _fetchImages() async {
    await TranslatorHelper().checkModels();
    final albums = await PhotoManager.getAssetPathList(
        onlyAll: true, hasAll: true, type: RequestType.image);
    final recentAlbum = albums.first;
    totalImages = recentAlbum.assetCount;
    var assets =
        await recentAlbum.getAssetListRange(start: 0, end: 10);
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
    setState(() {
      isDoneFetching = true;
    });
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
    return Card(
      elevation: 2,
      child: InkWell(
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExtractText(
                imageActualFile: imageActualFile,
              ),
            ),
          );
        },
        label: Text('إستخراج النص من الصورة'),
        icon: Icon(Icons.text_fields_rounded),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: imageActualFile != null
                ? Image.file(imageActualFile!)
                : FutureBuilder<File?>(
                    // Initialize FlutterFire:
                    future: imageFile,
                    builder: (context, snapshot) {
                      // Check for errors
                      if (snapshot.hasError) {
                        return Text('${snapshot.error}');
                      }

                      // Once complete, show your application
                      if (snapshot.connectionState == ConnectionState.done) {
                        imageActualFile = snapshot.data;
                        return Image.file(imageActualFile!);
                      }

                      // Otherwise, show something whilst waiting for initialization to complete
                      return Center(child: CircularProgressIndicator());
                    },
                  ),
          ),
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

class ExtractText extends StatelessWidget {
  final File? imageActualFile;

  ExtractText({Key? key, this.imageActualFile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إستخراج النص من الصور'),
      ),
      body: FutureBuilder(
        // Initialize FlutterFire:
        future: recogniseText(imageActualFile),
        builder: (context, snapshot) {
          // Check for errors
          if (snapshot.hasError) {
            return Text('${snapshot.error}');
          }
          if (snapshot.connectionState == ConnectionState.done) {
            List<TextBlock> extractedTexts = snapshot.data as List<TextBlock>;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                    elevation: 4,
                    color: Colors.black,
                    child: Image.file(
                      imageActualFile!,
                      height: 300,
                    )),
                extractedTexts.isEmpty
                    ? Expanded(child: emptyView())
                    : Expanded(child: buildListView(extractedTexts)),
              ],
            );
          }

          // Otherwise, show something whilst waiting for initialization to complete
          return CircularProgressIndicator();
        },
      ),
    );
  }

  ListView buildListView(List<TextBlock> extractedTexts) {
    return ListView.builder(
        itemCount: extractedTexts.length,
        itemBuilder: (context, index) {
          return Column(
            children: [
              ListTile(
                title: Text(
                  ' ${extractedTexts[index].text}',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.copy,
                    color: Colors.blue,
                  ),
                  onPressed: () {
                    _copyToClipboard(context, extractedTexts[index].text);
                  },
                ),
              ),
              Divider(),
            ],
          );
        });
  }

  Future<List<TextBlock>> recogniseText(File? imageActualFile) async {
    TextDetector textDetector = GoogleMlKit.vision.textDetector();
    InputImage inputImage = InputImage.fromFile(imageActualFile!);
    final recognisedText = await textDetector.processImage(inputImage);
    return recognisedText.blocks
        .where((element) => !element.recognizedLanguages.contains("und"))
        .toList();
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ النص'),
      ),
    );
  }

  Widget emptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.format_color_text,
            color: Colors.blue,
            size: 100,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("لا يوجد نص تم التعرف عليه في الصورة"),
          ),
        ],
      ),
    );
  }
}
