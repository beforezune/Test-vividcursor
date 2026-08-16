import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/code_block.dart';

class ExecutionResult {
  final String stdout;
  final String stderr;
  final int exitCode;

  ExecutionResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  bool get isError => exitCode != 0 || stderr.isNotEmpty;
}

class ExecutionService {
  // JDoodle API - free tier available
  static const String _apiUrl = 'https://api.jdoodle.com/v1/execute';
  
  // You can get free credentials from https://www.jdoodle.com/execute-api/
  // For now using their test credentials (limited)
  static const String _clientId = '5513252f3652060d1c7b82ad2afbf34a';
  static const String _clientSecret = 'b273aeacf3648bf9008d27319dce6da555d1ad37a7234f44aa7d5b6c794b4866';

  /// Execute code via JDoodle API.
  Future<ExecutionResult> execute(CodeBlock block) async {
    // Map language to JDoodle format
    String language = 'python3';
    if (block.language == 'bash' || block.language == 'sh' || block.language == 'shell') {
      language = 'bash';
    } else if (block.language == 'javascript' || block.language == 'js') {
      language = 'nodejs';
    }

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'clientId': _clientId,
        'clientSecret': _clientSecret,
        'script': block.content,
        'language': language,
        'versionIndex': '0',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ExecutionResult(
        stdout: data['output'] ?? '',
        stderr: data['error'] ?? '',
        exitCode: data['statusCode'] == 200 ? 0 : 1,
      );
    } else {
      return ExecutionResult(
        stdout: '',
        stderr: 'Execution API error: ${response.statusCode}\n${response.body}',
        exitCode: -1,
      );
    }
  }
}
