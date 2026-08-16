import '../models/code_block.dart';

class CodeParser {
  /// Parses an AI response and extracts all code blocks.
  /// Supports formats like:
  /// ```python:app.py
  /// ...code...
  /// ```
  /// or
  /// ```bash
  /// pip install requests
  /// ```
  /// Also handles plain code without fences (if any).
  static List<CodeBlock> extractCodeBlocks(String text) {
    final blocks = <CodeBlock>[];
    final regex = RegExp(r'```([^\n]*)\n([\s\S]*?)```');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      String info = match.group(1)?.trim() ?? '';
      String content = match.group(2) ?? '';

      // Determine language and optional file name
      String language = 'python'; // default
      String? fileName;

      final parts = info.split(RegExp(r'\s+'));
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        language = parts[0].toLowerCase();
        // Check for file name in info like "python:app.py" or "python app.py"
        if (language.contains(':')) {
          final langAndFile = language.split(':');
          language = langAndFile[0];
          fileName = langAndFile.length > 1 ? langAndFile[1] : null;
        } else if (parts.length > 1) {
          // maybe 'python app.py' or 'python filename=app.py'
          final second = parts[1];
          if (second.startsWith('filename=')) {
            fileName = second.substring('filename='.length);
          } else if (second.endsWith('.py') || second.endsWith('.sh') || second.endsWith('.txt')) {
            fileName = second;
          }
        }
      }

      // Remove common prefix like 'python' if it's on first line of content
      // (Some models put language on separate line)
      if (content.startsWith(language + '\n')) {
        content = content.substring(language.length + 1);
      }

      blocks.add(CodeBlock(
        language: language,
        content: content.trim(),
        fileName: fileName,
      ));
    }

    // If no fenced code blocks found, try to extract first obvious Python code
    if (blocks.isEmpty) {
      final pythonMatch = RegExp(r'(?:^|\n)(import\s+[\s\S]+?)(?=\n\n|$)').firstMatch(text);
      if (pythonMatch != null) {
        blocks.add(CodeBlock(language: 'python', content: pythonMatch.group(1)!.trim()));
      }
    }

    return blocks;
  }
}
