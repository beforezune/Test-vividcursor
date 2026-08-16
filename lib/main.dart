import 'package:flutter/material.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/languages/python.dart';
import 'dart:io';
import 'models.dart';
import 'services/file_service.dart';
import 'services/settings_service.dart';
import 'services/ai_service.dart';
import 'services/execution_service.dart';

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
  final ExecutionService _executionService = ExecutionService();

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
  bool _autoSendLogs = false;

  // Execution state
  String _executionOutput = '';
  bool _isExecuting = false;

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
      text: '# New Python file\n',
      language: python,
    );
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final providers = await _settingsService.loadProviders();
    final active = await _settingsService.getActiveProviderName();
    final autoSend = await _settingsService.getAutoSendLogs();
    setState(() {
      _providers = providers;
      _activeProviderName = active;
      _autoSendLogs = autoSend;
    });
  }

  Future<void> _openFile(String fileName) async {
    final content = await _fileService.readFile(fileName);
    setState(() {
      _currentFileName = fileName;
      _codeController?.text = content;
      _isModified = false;
      _currentIndex = 1;
    });
  }

  Future<void> _saveCurrentFile() async {
    if (_currentFileName == null) {
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

  // Extract first code block with language detection
  Map<String, String>? _extractCodeBlockWithLanguage(String content) {
    final start = content.indexOf('```');
    if (start == -1) return null;
    final end = content.indexOf('```', start + 3);
    if (end == -1) return null;
    String code = content.substring(start + 3, end).trim();
    String language = '';
    final firstLineEnd = code.indexOf('\n');
    if (firstLineEnd != -1) {
      final firstLine = code.substring(0, firstLineEnd).trim().toLowerCase();
      if (firstLine == 'python' || firstLine == 'py' || firstLine == 'bash' || firstLine == 'sh') {
        language = firstLine == 'py' ? 'python' : firstLine;
        code = code.substring(firstLineEnd + 1).trim();
      }
    }
    if (language.isEmpty) language = 'python';
    return {'language': language, 'code': code};
  }

  // Execute code via Piston API
  Future<void> _executeCode(String code, String language) async {
    setState(() {
      _isExecuting = true;
      _executionOutput = 'Running $language...';
    });

    final result = await _executionService.execute(
      code: code,
      language: language,
    );

    setState(() {
      _isExecuting = false;
      _executionOutput = result.stdout.isEmpty && result.stderr.isEmpty
          ? 'No output.'
          : 'STDOUT:\n${result.stdout}\n\nSTDERR:\n${result.stderr}\nExit code: ${result.exitCode}';
    });

    if (_autoSendLogs && result.isError) {
      final errorMessage =
          'The following code (language: $language) produced an error:\n```\n$code\n```\n\nError output:\n```\n${result.stderr}\n```\nPlease suggest a fix.';
      await _sendChatMessage(errorMessage);
    }

    _showExecutionOutput();
  }

  void _showExecutionOutput() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Execution Output',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(_executionOutput),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
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

    setState(() {
      _chatMessages.add(Message(role: 'user', content: userText));
      _isLoading = true;
    });

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
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              if (_codeController!.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Editor is empty')),
                );
                return;
              }
              _executeCode(_codeController!.text, 'python');
            },
          ),
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
          child: CodeTheme(
            data: CodeThemeData(styles: githubTheme),
            child: CodeField(
              controller: _codeController!,
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              onChanged: (value) => setState(() => _isModified = true),
            ),
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
              Map<String, String>? codeData;
              if (!isUser) {
                codeData = _extractCodeBlockWithLanguage(msg.content);
              }
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue.shade700 : Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.content),
                      if (codeData != null)
                        Builder(builder: (context) {
                          final code = codeData!['code']!;
                          final language = codeData!['language']!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Apply to editor'),
                                    onPressed: () {
                                      setState(() {
                                        _codeController?.text = code;
                                        _isModified = true;
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Code applied to editor')),
                                      );
                                    },
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.save_alt, size: 16),
                                    label: const Text('Save as new file'),
                                    onPressed: () async {
                                      final name = await _showFileNameDialog();
                                      if (name != null) {
                                        final fileName = name.endsWith('.py') ? name : '$name.py';
                                        await _fileService.writeFile(fileName, code);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Saved as $fileName')),
                                        );
                                      }
                                    },
                                  ),
                                  if (language == 'python')
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.play_arrow, size: 16),
                                      label: const Text('Run as Python'),
                                      onPressed: () => _executeCode(code, 'python'),
                                    ),
                                  if (language == 'bash')
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.terminal, size: 16),
                                      label: const Text('Run as Bash'),
                                      onPressed: () => _executeCode(code, 'bash'),
                                    ),
                                  if (language != 'python' && language != 'bash') ...[
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.play_arrow, size: 16),
                                      label: const Text('Run as Python'),
                                      onPressed: () => _executeCode(code, 'python'),
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.terminal, size: 16),
                                      label: const Text('Run as Bash'),
                                      onPressed: () => _executeCode(code, 'bash'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          );
                        }),
                    ],
                  ),
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
        SwitchListTile(
          title: const Text('Auto-send error logs to AI'),
          subtitle: const Text('When code execution fails, automatically send the error to AI for a fix'),
          value: _autoSendLogs,
          onChanged: (value) {
            setState(() => _autoSendLogs = value);
            _settingsService.setAutoSendLogs(value);
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

    await showDialog(
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
