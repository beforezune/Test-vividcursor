class Message {
  final String role; // 'user' or 'assistant'
  final String content;
  Message({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AIProviderConfig {
  String name;
  String baseUrl;
  String apiKey;
  String model;

  AIProviderConfig({
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
      };

  factory AIProviderConfig.fromJson(Map<String, dynamic> json) {
    return AIProviderConfig(
      name: json['name'] ?? '',
      baseUrl: json['baseUrl'] ?? '',
      apiKey: json['apiKey'] ?? '',
      model: json['model'] ?? '',
    );
  }
}
