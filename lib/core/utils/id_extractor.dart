class IdExtractor {
  static String? extractId(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['id'];
    } catch (e) {
      return null;
    }
  }
}
