// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data';
//
// import 'package:flutter/material.dart';
// import 'package:google_ml_kit/google_ml_kit.dart';
// import 'package:image_searcher_ai/data/classes.dart';
// import 'package:photo_manager/photo_manager.dart';
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'serif'),
//       home: MyHomePage(title: 'Smart Gallery'),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   MyHomePage({Key? key, required this.title}) : super(key: key);
//
//   final String title;
//
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   bool permitted = false;
//   late SmartGallery smartGallery;
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     requestPermission();
//     super.initState();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.title),
//         actions: [
//           IconButton(
//               onPressed: () {
//                 print(smartGallery.labels.length);
//                 print(smartGallery.images.length);
//                 for (final labels in smartGallery.labels) {
//                   for (final label in labels) {
//                     print(label.label);
//                   }
//                 }
//               },
//               icon: Icon(Icons.inbox_sharp))
//         ],
//       ),
//       body: !permitted ? buildRequestFunction() : buildFutureBuilderForImages(),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _fetchImages,
//         child: Icon(Icons.add),
//       ), // This trailing comma makes auto-formatting nicer for build methods.
//     );
//   }
//
//   Center buildRequestFunction() {
//     return Center(
//       child: Column(
//         children: [
//           IconButton(onPressed: requestPermission,
//               icon: Icon(Icons.image_not_supported_rounded, size: 100,)),
//           Text("Press to request permission"),
//         ],
//       ),
//     );
//   }
//
//   FutureBuilder<SmartGallery> buildFutureBuilderForImages() {
//     return FutureBuilder(
//       // Initialize FlutterFire:
//       future: _fetchImages(),
//       builder: (context, snapshot) {
//         // Check for errors
//         if (snapshot.hasError) {
//           return Text('${snapshot.error} reallyww?');
//         }
//
//         // Once complete, show your application
//         if (snapshot.connectionState == ConnectionState.done) {
//           SmartGallery data = snapshot.data as SmartGallery;
//           return buildGrid(assets: data.images, Labels: data.labels);
//         }
//
//         // Otherwise, show something whilst waiting for initialization to complete
//         return Center(child: CircularProgressIndicator());
//       },
//     );
//   }
//
//   GridView buildGrid({required List<AssetEntity> assets,
//     required List<List<ImageLabel>> Labels}) {
//     return GridView.builder(
//         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//         ),
//         itemCount: assets.length,
//         itemBuilder: (_, index) {
//           return AssetThumbnail(
//               asset: assets[index], imageLabels: Labels[index]);
//         });
//   }
//
//   void requestPermission() async {
//     setState(() async {
//       permitted = await PhotoManager.requestPermission();
//     });
//   }
//
//   Future<SmartGallery> _fetchImages() async {
//     final albums = await PhotoManager.getAssetPathList(
//         onlyAll: true, type: RequestType.image);
//     final recentAlbum = albums.first;
//     // Now that we got the album, fetch all the assets it contains
//     var assets = await recentAlbum.getAssetListPaged(0, 20);
//     var galleryLabels = await processTheAssets(assets);
//     var completer = new Completer<SmartGallery>();
//     smartGallery = new SmartGallery(images: assets, labels: galleryLabels);
//     return smartGallery;
//   }
//
//   Future<List<List<ImageLabel>>> processTheAssets(
//       List<AssetEntity> recentAssets) async {
//     List<List<ImageLabel>> galleryLabels = [];
//     int counter = 0;
//     for (final asset in recentAssets) {
//       print('title is ${asset.title}');
//       final imagLabel = await processImage(asset: asset);
//       galleryLabels.add(imagLabel);
//       counter++;
//     }
//     return galleryLabels;
//   }
//
//   Future<List<ImageLabel>> processImage({required AssetEntity asset}) async {
//     return asset.file.then((value) async {
//       late List<ImageLabel> processImage;
//       final inputImage = InputImage.fromFile(value!);
//       ImageLabeler imageLabeler = GoogleMlKit.vision.imageLabeler();
//       processImage = await imageLabeler
//           .processImage(inputImage)
//           .catchError((error, stackTrace) {
//         print("outer: $error");
//       });
//
//       return processImage;
//     });
//   }
// }
//
// class AssetThumbnail extends StatelessWidget {
//   const AssetThumbnail(
//       {Key? key, required this.asset, required this.imageLabels})
//       : super(key: key);
//
//   final AssetEntity asset;
//   final List<ImageLabel> imageLabels;
//
//   @override
//   Widget build(BuildContext context) {
//     // We're using a FutureBuilder since thumbData is a future
//     return FutureBuilder<Uint8List?>(
//       future: asset.thumbData,
//       builder: (_, snapshot) {
//         final bytes = snapshot.data;
//         // If we have no data, display a spinner
//         if (bytes == null) return CircularProgressIndicator();
//
//         // If there's data, display it as an image
//         return InkWell(
//           onTap: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) =>
//                     ImageScreen(
//                       imageFile: asset.file,
//                       imgLabels: imageLabels,
//                     ),
//               ),
//             );
//           },
//           child: Stack(
//             children: [
//               // Wrap the image in a Positioned.fill to fill the space
//               Positioned.fill(
//                 child: Image.memory(bytes, fit: BoxFit.cover),
//               ),
//               // Display a Play icon if the asset is a video
//               Positioned.fill(
//                 child: Text(
//                   ' ${imageLabels.isEmpty ? 'no labels' : imageLabels.first
//                       .label}',
//                   style: TextStyle(
//                       color: Colors.white,
//                       backgroundColor: Colors.black45,
//                       fontSize: 18),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   getHighestConfidance(List<ImageLabel> galleryLabel) {}
// }
//
// class ImageScreen extends StatelessWidget {
//   ImageScreen({
//     Key? key,
//     required this.imageFile,
//     required this.imgLabels,
//   }) : super(key: key);
//
//   final Future<File?> imageFile;
//   List<ImageLabel> imgLabels;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//           Container(
//               color: Colors.black,
//               alignment: Alignment.center,
//               child: FutureBuilder<File?>(
//                 future: imageFile,
//                 builder: (_, snapshot) {
//                   final file = snapshot.data;
//                   if (file == null) return Text("Error Loading Image");
//                   return Image.file(file);
//                 },
//               )),
//           FutureBuilder<List<ImageLabel>>(
//             future: processImage(file: imageFile),
//             builder: (_, snapshot) {
//               imgLabels = snapshot.data!;
//               if (imgLabels == null) return Text("Error Loading Image");
//               return buildList();
//             },
//           ),
//         ],
//       ),
//     );
//   }
//
//   SizedBox buildList() {
//     return SizedBox.expand(
//       child: DraggableScrollableSheet(
//         initialChildSize: 0.25,
//         builder: (BuildContext context, ScrollController scrollController) {
//           return Container(
//             color: Colors.black26,
//             child: ListView.builder(
//               controller: scrollController,
//               itemCount: imgLabels.length,
//               itemBuilder: (BuildContext context, int index) {
//                 return ListTile(
//                   title: Text(
//                     ' ${imgLabels[index].label}  ${(imgLabels[index]
//                         .confidence * 100).truncate()}%',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontFamily: 'serif',
//                       fontSize: 16,
//                     ),
//                   ),
//                 );
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Future<List<ImageLabel>> processImage({required Future<File?> file}) async {
//     return file.then((value) async {
//       final inputImage = InputImage.fromFile(value!);
//       ImageLabeler imageLabeler = GoogleMlKit.vision.imageLabeler();
//       return await imageLabeler.processImage(inputImage);
//     });
//   }
// }
//





