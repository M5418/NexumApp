abstract class TranslateRepository {
  Future<List<String>> translateTexts(List<String> texts, String targetLanguage);
  Future<String> translateText(String text, String targetLanguage);
}
