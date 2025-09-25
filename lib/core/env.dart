import 'package:flutter/foundation.dart' show kIsWeb;

const _kApiBaseUrlConfigured = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8080',
);

final String kApiBaseUrl = kIsWeb &&
        (_kApiBaseUrlConfigured.contains('10.0.2.2') ||
            _kApiBaseUrlConfigured.contains('0.0.0.0'))
    ? 'http://localhost:8080'
    : _kApiBaseUrlConfigured;
