void main() {
  List<String> generateSearchKeywords(String text) {
    if (text.isEmpty) return [];
    
    final Set<String> keywords = {};
    final String lowercaseText = text.toLowerCase().trim();
    
    String currentPrefix = "";
    for (int i = 0; i < lowercaseText.length; i++) {
      currentPrefix += lowercaseText[i];
      keywords.add(currentPrefix);
    }
    
    final List<String> words = lowercaseText.split(RegExp(r'\s+'));
    for (String word in words) {
      if (word.isEmpty) continue;
      currentPrefix = "";
      for (int i = 0; i < word.length; i++) {
        currentPrefix += word[i];
        keywords.add(currentPrefix);
      }
    }
    
    return keywords.toList();
  }

  final name = "Aadeesh";
  final email = "aadeesh@example.com";
  final role = "student";

  final keywords = [
    ...generateSearchKeywords(name),
    ...generateSearchKeywords(email),
    ...generateSearchKeywords(role),
  ].toSet().toList();

  print(keywords);
}
