import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileService {
  Future<Directory> _getAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${dir.path}/coder_files');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  Future<List<FileSystemEntity>> listFiles() async {
    final dir = await _getAppDir();
    final entities = dir.listSync();
    entities.sort((a, b) => a.path.compareTo(b.path));
    return entities;
  }

  Future<String> readFile(String fileName) async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  Future<void> writeFile(String fileName, String content) async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
  }

  Future<void> deleteFile(String fileName) async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
