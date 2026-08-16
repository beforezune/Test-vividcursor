import 'package:flutter/material.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/languages/python.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'models.dart';
import 'services/file_service.dart';
import 'services/settings_service.dart';
import 'services/ai_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CursorDroid',
      theme: ThemeData.dark(),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // start with editor tab
  final FileService _fileService = FileService();
  final SettingsService _settingsService = SettingsService();
  final AIService _aiService = AIService();

  // Editor state
  CodeController? _codeController;
  String? _currentFileName;
  bool _isModified = false;

  // Chat state
  List<Message> _chatMessages = [];
  bool _includeFileContext = true;
  bool _isLoading = false;

  // Settings state
  List<AIProviderConfig> _providers = [];
  String? _activeProviderName;

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
      text: '# New Python file\n',
      language: python,
      theme: githubTheme,
    );
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final providers = await _settingsService.loadProviders();
    final active = await _settingsService.getActiveProviderName();
    setState(() {
      _providers = providers;
      _activeProviderName = active;
    });
  }

  Future<void> _openFile(String fileName) async {
    final content = await _fileService.readFile(fileName);
    setState(() {
      _currentFileName = fileName;
      _codeController?.text = content;
      _isModified = false;
      _currentIndex = 1; // switch to editor
    });
  }

  Future<void> _saveCurrentFile() async {
    if (_currentFileName == null) {
      // Create new file
      final name = await _showFileNameDialog();
      if (name == null) return;
      _currentFileName = name.endsWith('.py') ? name : '$name.py';
    }
    await _fileService.writeFile(_currentFileName!, _codeController!.text);
    setState(() {
      _isModified = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File saved')),
    );
  }

  Future<String?> _showFileNameDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter file name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g., my_script.py'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _deleteFile(String fileName) async {
    await _fileService.deleteFile(fileName);
    if (_currentFileName == fileName) {
      setState(() {
        _currentFileName = null;
        _codeController?.text = '';
      });
    }
  }

  Future<void> _sendChatMessage(String userText) async {
    final provider = _providers.firstWhere(
      (p) => p.name == _activeProviderName,
      orElse: () => AIProviderConfig(
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: 'YOUR_API_KEY',
        model: 'deepseek-chat',
      ),
    );
    if (provider.apiKey == 'YOUR_API_KEY' || provider.apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure your API key in Settings')),
      );
      return;
    }

    final newUserMessage = Message(role: 'user', content: userText);
    setState(() {
      _chatMessages.add(newUserMessage);
      _isLoading = true;
    });

    // Build messages with optional file context
    final messagesToSend = <Message>[];
    if (_includeFileContext && _codeController!.text.isNotEmpty) {
      messagesToSend.add(Message(
        role: 'user',
        content: 'Current file content:\n```\n${_codeController!.text}\n```',
      ));
    }
    messagesToSend.addAll(_chatMessages);

    try {
      final response = await _aiService.chat(provider, messagesToSend);
      setState(() {
        _chatMessages.add(Message(role: 'assistant', content: response));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _chatMessages.add(Message(
          role: 'assistant',
          content: 'Error: $e',
        ));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentFileName ?? 'CursorDroid'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveCurrentFile,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildFilesTab(),
          _buildEditorTab(),
          _buildChatTab(),
          _buildSettingsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Files'),
          BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Editor'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    return FutureBuilder<List<FileSystemEntity>>(
      future: _fileService.listFiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final files = snapshot.data ?? [];
        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final name = file.path.split('/').last;
            return ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text(name),
              onTap: () => _openFile(name),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteFile(name),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditorTab() {
    return Column(
      children: [
        Expanded(
          child: CodeField(
            controller: _codeController!,
            textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            onChanged: () => setState(() => _isModified = true),
          ),
        ),
        if (_isModified)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Unsaved changes', style: TextStyle(color: Colors.orange)),
          ),
      ],
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              final isUser = msg.role == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue.shade700 : Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(msg.content),
                ),
              );
            },
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildChatInput() {
    final controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Checkbox(
            value: _includeFileContext,
            onChanged: (v) => setState(() => _includeFileContext = v!),
          ),
          const Text('Include file'),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Ask AI...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _sendChatMessage(text.trim());
                  controller.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                _sendChatMessage(text);
                controller.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('AI Providers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ..._providers.map((p) => RadioListTile<String>(
              title: Text(p.name),
              subtitle: Text('${p.model} @ ${p.baseUrl}'),
              value: p.name,
              groupValue: _activeProviderName,
              onChanged: (value) {
                setState(() => _activeProviderName = value);
                _settingsService.setActiveProvider(value!);
              },
            )),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Provider'),
          onPressed: _addProviderDialog,
        ),
        if (_providers.isNotEmpty)
          ElevatedButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text('Delete Selected Provider'),
            onPressed: () {
              if (_activeProviderName != null) {
                final provider = _providers.firstWhere((p) => p.name == _activeProviderName);
                setState(() {
                  _providers.remove(provider);
                  if (_providers.isNotEmpty) {
                    _activeProviderName = _providers.first.name;
                  } else {
                    _activeProviderName = null;
                  }
                });
                _settingsService.saveProviders(_providers);
                _settingsService.setActiveProvider(_activeProviderName ?? '');
              }
            },
          ),
        const Divider(height: 32),
        const Text('Add Provider Details', style: TextStyle(fontSize: 16)),
      ],
    );
  }

  Future<void> _addProviderDialog() async {
    final nameController = TextEditingController();
    final baseUrlController = TextEditingController();
    final apiKeyController = TextEditingController();
    final modelController = TextEditingController();

    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add AI Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: baseUrlController, decoration: const InputDecoration(labelText: 'Base URL')),
            TextField(controller: apiKeyController, decoration: const InputDecoration(labelText: 'API Key')),
            TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Model')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final provider = AIProviderConfig(
                name: nameController.text.trim(),
                baseUrl: baseUrlController.text.trim(),
                apiKey: apiKeyController.text.trim(),
                model: modelController.text.trim(),
              );
              setState(() {
                _providers.add(provider);
                _activeProviderName = provider.name;
              });
              _settingsService.saveProviders(_providers);
              _settingsService.setActiveProvider(provider.name);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
