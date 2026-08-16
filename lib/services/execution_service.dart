import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:python_ffi/python_ffi.dart';
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
  // Singleton-like: initialize Python once
  static PythonFfi? _python;
  static bool _initialized = false;

  Future<void> _ensurePython() async {
    if (_initialized) return;
    _python = PythonFfi.instance;
    await _python!.initialize();
    _initialized = true;
  }

  /// Execute Python code locally using python_ffi.
  /// If [fileName] is provided, it will be written to temp dir and executed.
  Future<ExecutionResult> executePython(String code, {String? fileName}) async {
    await _ensurePython();

    final tempDir = await getTemporaryDirectory();
    final execDir = Directory('${tempDir.path}/code_exec');
    if (!await execDir.exists()) {
      await execDir.create(recursive: true);
    }

    File? file;
    if (fileName != null && fileName.isNotEmpty) {
      file = File('${execDir.path}/$fileName');
      await file.writeAsString(code);
    } else {
      file = File('${execDir.path}/__temp__.py');
      await file.writeAsString(code);
    }

    try {
      final result = await _python!.executeFile(file.path);
      return ExecutionResult(
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      );
    } catch (e) {
      return ExecutionResult(
        stdout: '',
        stderr: 'Python execution error: $e',
        exitCode: -1,
      );
    }
  }

  /// Execute shell command (bash/sh) using Android's native shell.
  Future<ExecutionResult> executeShell(String command) async {
    try {
      final result = await Process.run(
        '/system/bin/sh',
        ['-c', command],
        workingDirectory: await _getExecutionDirectory(),
      );
      return ExecutionResult(
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
        exitCode: result.exitCode,
      );
    } catch (e) {
      return ExecutionResult(
        stdout: '',
        stderr: 'Shell execution error: $e',
        exitCode: -1,
      );
    }
  }

  Future<String> _getExecutionDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final execDir = Directory('${tempDir.path}/code_exec');
    if (!await execDir.exists()) {
      await execDir.create(recursive: true);
    }
    return execDir.path;
  }

  /// Unified executor: based on code block type.
  Future<ExecutionResult> execute(CodeBlock block) async {
    if (block.isPython) {
      return executePython(block.content, fileName: block.fileName);
    } else if (block.isShell) {
      return executeShell(block.content);
    } else {
      // fallback: treat as Python
      return executePython(block.content);
    }
  }
}
