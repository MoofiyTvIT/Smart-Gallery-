import 'package:google_ml_kit/google_ml_kit.dart';

class TranslatorHelper {
  static const String ORIGIN_LANGUAGE = TranslateLanguage.ENGLISH;
  static const String TO_LANGUAGE = TranslateLanguage.ARABIC;

  final _languageModelManager = GoogleMlKit.nlp.translateLanguageModelManager();

  checkModels() {
    _downloadModel(ORIGIN_LANGUAGE);
    _downloadModel(TO_LANGUAGE);
  }

  Future<void> _downloadModel(String language) async {
    bool downloaded = await _languageModelManager.isModelDownloaded(language);
    if (!downloaded) {
      var result = await _languageModelManager.downloadModel(language);
      print('Model downloaded: $result');
    }
  }
}
