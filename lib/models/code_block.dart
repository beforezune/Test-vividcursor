class CodeBlock {
  final String language;   // 'python', 'bash', 'sh', 'javascript', etc.
  final String content;    // the actual code
  final String? fileName;  // optional file name to save

  CodeBlock({
    required this.language,
    required this.content,
    this.fileName,
  });

  bool get isPython => language == 'python' || language == 'py';
  bool get isShell => language == 'bash' || language == 'sh' || language == 'shell';

  @override
  String toString() =>
      'CodeBlock(language: $language, fileName: $fileName, content: ${content.substring(0, min(content.length, 30))}...)';
}

int min(int a, int b) => a < b ? a : b;
