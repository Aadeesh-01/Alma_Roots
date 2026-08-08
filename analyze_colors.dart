import 'dart:io';

void main() {
  var dir = Directory('lib/screen');
  var files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  print('File | Hardcoded (Colors.*) | Theme Violations (AppColors.*) | Complexity');
  print('---|---|---|---');
  
  Map<String, Map<String, int>> stats = {};

  for (var file in files) {
    var content = file.readAsStringSync();
    
    int colorsCount = RegExp(r'Colors\.[a-zA-Z0-9_]+').allMatches(content).length;
    int appColorsCount = RegExp(r'AppColors\.[a-zA-Z0-9_]+').allMatches(content).length;
    
    if (colorsCount > 0 || appColorsCount > 0) {
      String complexity = 'Low';
      int total = colorsCount + appColorsCount;
      if (total > 20) complexity = 'High';
      else if (total > 10) complexity = 'Medium';
      
      print('${file.path} | $colorsCount | $appColorsCount | $complexity');
    }
  }
}
