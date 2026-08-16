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
  static PythonFfi? _python;
  static bool _initialized = false;

  Future<void> _ensurePython() async {
    if (_initialized) return;
    _python = PythonFfi.instance;
    await _python!.initialize();
    _initialized = true;
  }

  /// Execute Python code locally using python_ffi.
  Future<ExecutionResult> executePython(String code) async {
    await _ensurePython();

    try {
      // Correct method is 'execute'
      final result = await _python!.execute(code);
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

  /// Unified executor: based on code block type.
  Future<ExecutionResult> execute(CodeBlock block) async {
    if (block.isPython) {
      return executePython(block.content);
    } else if (block.isShell) {
      return executeShell(block.content);
    } else {
      // fallback: treat as Python
      return executePython(block.content);
    }
  }
}
