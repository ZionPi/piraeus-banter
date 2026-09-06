import 'dart:io';

class ApiConfig {
  static const _baseUrl = String.fromEnvironment(
    'PIRAEUS_API_BASE_URL',
    defaultValue: 'https://api-us.benjoe.top',
  );
  static const _proxyToken = String.fromEnvironment('PIRAEUS_API_TOKEN');

  static Uri uri(String path) => Uri.parse(_baseUrl).resolve(path);

  static void authorize(HttpClientRequest request) {
    if (_proxyToken.isEmpty) {
      throw StateError('应用未配置服务器访问令牌，请重新安装正式版本。');
    }
    request.headers.set('X-Piraeus-Token', _proxyToken);
  }
}
