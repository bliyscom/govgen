import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

class _MarkdownChunk {
  final String type;
  final String content;
  _MarkdownChunk(this.type, this.content);
}

List<_MarkdownChunk> parseMarkdownBlocks(String text) {
  List<_MarkdownChunk> chunks = [];
  final lines = text.split('\n');
  StringBuffer currentText = StringBuffer();
  StringBuffer currentTable = StringBuffer();
  bool inTable = false;
  bool inFormula = false;
  StringBuffer currentFormula = StringBuffer();
  
  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    if (line.trim() == '\$\$') {
       if (!inFormula) {
          if (currentText.isNotEmpty) {
             chunks.add(_MarkdownChunk('text', currentText.toString()));
             currentText.clear();
          }
          inFormula = true;
       } else {
          chunks.add(_MarkdownChunk('formula', currentFormula.toString()));
          currentFormula.clear();
          inFormula = false;
       }
       continue;
    }
    
    if (inFormula) {
       currentFormula.writeln(line);
       continue;
    }
    
    if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
       if (!inTable) {
          if (currentText.isNotEmpty) {
             chunks.add(_MarkdownChunk('text', currentText.toString()));
             currentText.clear();
          }
          inTable = true;
       }
       currentTable.writeln(line);
    } else {
       if (inTable) {
          chunks.add(_MarkdownChunk('table', currentTable.toString()));
          currentTable.clear();
          inTable = false;
       }
       currentText.writeln(line);
    }
  }
  
  if (inTable) chunks.add(_MarkdownChunk('table', currentTable.toString()));
  if (inFormula) chunks.add(_MarkdownChunk('formula', currentFormula.toString()));
  if (currentText.isNotEmpty) chunks.add(_MarkdownChunk('text', currentText.toString()));
  
  return chunks;
}

void main() {
  test('Markdown parsing test', () {
    final markdown = """
Here is a table:

| Col 1 | Col 2 |
|-------|-------|
| Val A | Val B |

Here is an equation:
\$\$
x = y^2 + 1
\$\$

Inline \$ e=mc^2 \$ equation!
""";

    final mdDocument = md.Document(encodeHtml: false, extensionSet: md.ExtensionSet.gitHubFlavored);
    final mdParser = MarkdownToDelta(markdownDocument: mdDocument);
    List<dynamic> combinedDelta = [];
    
    final chunks = parseMarkdownBlocks(markdown);
    for (var chunk in chunks) {
       if (chunk.type == 'text') {
           String txt = chunk.content;
           final delta = mdParser.convert(txt);
           final deltaJson = jsonDecode(jsonEncode(delta.toJson()));
           
           for (var op in deltaJson) {
              if (op['insert'] is String) {
                 String textOp = op['insert'];
                 final inlineMathPattern = RegExp(r'\$(.*?)\$');
                 int lastIndex = 0;
                 for (var match in inlineMathPattern.allMatches(textOp)) {
                    if (match.start > lastIndex) {
                       combinedDelta.add({"insert": textOp.substring(lastIndex, match.start), "attributes": op['attributes']});
                    }
                    combinedDelta.add({"insert": {"formula": match.group(1)!.trim()}});
                    lastIndex = match.end;
                 }
                 if (lastIndex < textOp.length) {
                     combinedDelta.add({"insert": textOp.substring(lastIndex), "attributes": op['attributes']});
                 }
              } else {
                 combinedDelta.add(op);
              }
           }
       } else if (chunk.type == 'formula') {
           combinedDelta.add({"insert": {"formula": chunk.content.trim()}});
           combinedDelta.add({"insert": "\n"});
       } else if (chunk.type == 'table') {
           final tableLines = chunk.content.trim().split('\n');
           for (int r = 0; r < tableLines.length; r++) {
               final line = tableLines[r].trim();
               if (line.contains('---')) continue;
               final cells = line.split('|');
               for (int c = 1; c < cells.length - 1; c++) {
                  combinedDelta.add({"insert": cells[c].trim()});
                  combinedDelta.add({"insert": "\n", "attributes": {"table": "row-$r"}});
               }
           }
       }
    }
    
    print("M2D_OUTPUT: ${jsonEncode(combinedDelta)}");
  });
}
