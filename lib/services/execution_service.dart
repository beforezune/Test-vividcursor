import 'dart:convert';
import 'package:http/http.dart' as http;

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
  static const String _apiUrl = 'https://emkc.org/api/v2/piston/execute';

  Future<ExecutionResult> execute({
    required String code,
    required String language,
  }) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'language': language,
        'version': '*',
        'files': [
          {'content': code}
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final run = data['run'];
      return ExecutionResult(
        stdout: run['stdout'] ?? '',
        stderr: run['stderr'] ?? '',
        exitCode: run['code'] ?? 0,
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
