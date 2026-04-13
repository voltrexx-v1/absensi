
import "dart:io";

void main() {
  var file = File("lib/views/karyawan_view.dart");
  var lines = file.readAsLinesSync();
  int depth = 0;
  for (int i = 0; i < lines.length; i++) {
    var line = lines[i];
    line = line.replaceAll(RegExp(r'"[^"]*"'), "");
    line = line.replaceAll(RegExp(r"'[^']*'"), "");
    
    for (int j = 0; j < line.length; j++) {
      if (line[j] == "{") depth++;
      else if (line[j] == "}") depth--;
    }
    if (depth == 0 && line.contains("}")) {
      print("Depth reached 0 at line ${i+1}: ${line.trim()}");
    }
  }
}

