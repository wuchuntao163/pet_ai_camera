import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/auth_session_store.dart';
import 'api_config.dart';
import 'api_paths.dart';

// ─────────────────────────────────────────────────────────────
//  对外入口：先 Api.init()，再 Api.get / Api.post
// ─────────────────────────────────────────────────────────────

/// 网络请求统一入口
class Api {
  Api._();

  static bool _ready = false;

  static Future<void> init({String device = ''}) async {
    if (_ready) return;
    await AuthSessionStore.instance.init();
    await _Http.instance.ensureInitialized(device: device);
    _ready = true;
  }

  static Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic json)? parser,
  }) {
    _checkReady();
    return _Http.instance.get<T>(path, queryParameters: query, parser: parser);
  }

  static Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? data,
    T Function(dynamic json)? parser,
    Duration? receiveTimeout,
  }) {
    _checkReady();
    return _Http.instance.post<T>(
      path,
      data: data,
      parser: parser,
      receiveTimeout: receiveTimeout,
    );
  }

  static Future<ApiResponse<T>> upload<T>(
    String path, {
    required String filePath,
    String fileField = 'file',
    String? filename,
    Map<String, dynamic>? fields,
    T Function(dynamic json)? parser,
  }) {
    _checkReady();
    return _Http.instance.upload<T>(
      path: path,
      filePath: filePath,
      fileField: fileField,
      filename: filename,
      fields: fields,
      parser: parser,
    );
  }

  static void _checkReady() {
    if (!_ready) {
      throw StateError('请先调用 Api.init()');
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  响应 / 异常
// ─────────────────────────────────────────────────────────────

class ApiResponse<T> {
  const ApiResponse({
    required this.code,
    required this.msg,
    this.data,
    this.fromEncrypted = false,
  });

  final int code;
  final String msg;
  final T? data;
  final bool fromEncrypted;

  bool get isSuccess => code == 200 || code == 4000;

  @override
  String toString() =>
      'ApiResponse(code: $code, msg: $msg, data: $data, fromEncrypted: $fromEncrypted)';

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    T Function(dynamic json)? parser,
    bool fromEncrypted = false,
  }) {
    final raw = json['data'];
    return ApiResponse(
      code: _asInt(json['code']),
      msg: json['msg']?.toString() ?? '',
      data: parser != null && raw != null ? parser(raw) : raw as T?,
      fromEncrypted: fromEncrypted,
    );
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.code,
    this.rawData,
    this.isNetworkError = false,
  });

  final int? code;
  final String message;
  final dynamic rawData;
  final bool isNetworkError;

  @override
  String toString() =>
      'ApiException(code: $code, message: $message, rawData: $rawData)';

  factory ApiException.business(int code, String message, [dynamic raw]) =>
      ApiException(code: code, message: message, rawData: raw);

  factory ApiException.network(String message, {dynamic rawData}) =>
      ApiException(message: message, rawData: rawData, isNetworkError: true);
}

// ─────────────────────────────────────────────────────────────
//  HTTP 客户端 + 拦截器 + 解密（内部实现，无需关心）
// ─────────────────────────────────────────────────────────────

class _Http {
  _Http._();
  static final _Http instance = _Http._();

  Dio? _dio;
  bool _initialized = false;

  Future<void> ensureInitialized({String device = ''}) async {
    if (_initialized) return;
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.plain,
      ),
    );
    _dio!.interceptors.addAll([
      _AuthInterceptor(device: device),
      _LogInterceptor(),
      _ErrorInterceptor(),
    ]);
    _initialized = true;
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? parser,
  }) =>
      _request(path, method: 'GET', queryParameters: queryParameters, parser: parser);

  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? data,
    T Function(dynamic json)? parser,
    Duration? receiveTimeout,
  }) =>
      _request(
        path,
        method: 'POST',
        data: data,
        parser: parser,
        receiveTimeout: receiveTimeout,
      );

  Future<ApiResponse<T>> upload<T>({
    required String path,
    required String filePath,
    String fileField = 'file',
    String? filename,
    Map<String, dynamic>? fields,
    T Function(dynamic json)? parser,
  }) async {
    final form = FormData.fromMap({
      if (fields != null) ...fields,
      fileField: await MultipartFile.fromFile(
        filePath,
        filename: filename ?? p.basename(filePath),
      ),
    });
    return _request(path, method: 'POST', data: form, parser: parser);
  }

  Future<ApiResponse<T>> _request<T>(
    String path, {
    required String method,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    T Function(dynamic json)? parser,
    Duration? receiveTimeout,
  }) async {
    try {
      final res = await _dio!.request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          receiveTimeout: receiveTimeout,
          contentType: data is FormData ? null : Headers.jsonContentType,
        ),
      );
      if (res.data == null) throw ApiException.network('响应为空');
      return _parseBody<T>(
        _parseJson(res.data),
        path: path,
        parser: parser,
      );
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      _logApi(
        '[API] DioException ${e.requestOptions.path}\n'
        '  status: ${e.response?.statusCode}\n'
        '  raw: ${_truncateForLog(e.response?.data)}',
        path: e.requestOptions.path,
      );
      throw ApiException.network(
        e.error?.toString() ?? e.message ?? '网络请求失败',
        rawData: e.response?.data,
      );
    }
  }

  ApiResponse<T> _parseBody<T>(
    Map<String, dynamic> body, {
    required String path,
    T Function(dynamic json)? parser,
  }) {
    final code = _asInt(body['code']);
    final msg = body['msg']?.toString() ?? '';
    final payload = body['data'];

    _logApi(
      '[API] envelope $path:\n${_prettyJson({
        'code': code,
        'msg': msg,
        'data': _envelopeDataForLog(payload),
      })}',
      path: path,
    );

    if (code == 8001) {
      _logApi('[API] business error $path: code=$code msg=$msg', path: path);
      throw ApiException.business(code, msg.isNotEmpty ? msg : '签名错误', payload);
    }
    if (code != 200 && code != 4000) {
      _logApi('[API] business error $path: code=$code msg=$msg', path: path);
      throw ApiException.business(
        code,
        msg.isNotEmpty ? msg : '请求失败($code)',
        payload,
      );
    }

    // 加密响应 data.k + data.r → AES 解密（对齐 uniapp decryptAjax）
    if (payload is Map && payload['k'] != null && payload['r'] != null) {
      final decrypted = _Crypto.decryptAjax(
        payload['k'].toString(),
        payload['r'].toString(),
      );
      _logApi(
        '[API] decrypted $path:\n${_prettyJson(decrypted)}',
        path: path,
      );
      final parsed =
          parser != null && decrypted != null ? parser(decrypted) : decrypted as T?;
      final result =
          ApiResponse(code: code, msg: msg, data: parsed, fromEncrypted: true);
      _logApi(
        '[API] parsed $path:\n${_prettyJson({
          'code': result.code,
          'msg': result.msg,
          'data': result.data,
          'fromEncrypted': true,
        })}',
        path: path,
      );
      return result;
    }

    final result = ApiResponse.fromJson(body, parser: parser);
    _logApi(
      '[API] parsed $path:\n${_prettyJson({
        'code': result.code,
        'msg': result.msg,
        'data': result.data,
      })}',
      path: path,
    );
    return result;
  }

  Map<String, dynamic> _parseJson(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final t = data.trim();
      if (t.isEmpty) throw ApiException.network('响应为空');
      try {
        final decoded = jsonDecode(t);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        throw ApiException.network('响应不是 JSON', rawData: data);
      }
    }
    throw ApiException.network('无法解析响应: ${data.runtimeType}', rawData: data);
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({this.device = ''});
  final String device;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final common = <String, dynamic>{
      'app_id': ApiConfig.appId,
      'source': ApiConfig.source,
      'device': device,
    };
    final userId = AuthSessionStore.instance.userId;
    if (userId != null) common['user_id'] = userId;

    if (options.method == 'GET') {
      options.queryParameters = {...common, ...options.queryParameters};
    } else {
      final d = options.data;
      if (d is FormData) {
        for (final entry in common.entries) {
          d.fields.add(MapEntry(entry.key, entry.value.toString()));
        }
        options.data = d;
      } else if (d == null) {
        options.data = common;
      } else if (d is Map) {
        options.data = {...common, ...Map<String, dynamic>.from(d)};
      } else {
        options.data = d;
      }
    }

    final token = AuthSessionStore.instance.token;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] =
          token.startsWith('Bearer ') ? token : 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) AuthSessionStore.instance.clear();
    handler.next(err);
  }
}

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode &&
        ApiConfig.enableLog &&
        _shouldLogApiPath(options.path)) {
      // ignore: avoid_print
      print('[API] --> ${options.method} ${options.uri}');
      if (options.data != null) {
        // ignore: avoid_print
        print('[API] body: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode &&
        ApiConfig.enableLog &&
        _shouldLogApiPath(response.requestOptions.path)) {
      final path = response.requestOptions.path;
      // ignore: avoid_print
      print('[API] <-- ${response.statusCode} $path');
    }
    handler.next(response);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final path = err.requestOptions.path;
    final raw = err.response?.data;
    final suppressLog = !_shouldLogApiPath(path);

    if (!suppressLog) {
      _logApi(
        '[API] HTTP error $path\n'
        '  status: ${err.response?.statusCode}\n'
        '  raw: ${_truncateForLog(raw)}',
        path: path,
      );
    }

    if (raw != null) {
      try {
        final map = _Http.instance._parseJson(raw);
        final code = _asInt(map['code']);
        final msg = map['msg']?.toString() ?? '请求失败!!!';
        final payload = map['data'];
        dynamic decrypted = payload;
        if (payload is Map && payload['k'] != null && payload['r'] != null) {
          decrypted = _Crypto.decryptAjax(
            payload['k'].toString(),
            payload['r'].toString(),
          );
          if (!suppressLog) {
            _logApi('[API] HTTP error decrypted $path:\n${_prettyJson(decrypted)}', path: path);
          }
        } else if (!suppressLog) {
          _logApi(
            '[API] HTTP error envelope $path:\n${_prettyJson({
              'code': code,
              'msg': msg,
              'data': payload,
            })}',
            path: path,
          );
        }
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: ApiException.business(code, msg, decrypted ?? payload),
        ));
        return;
      } catch (parseErr) {
        if (!suppressLog) {
          _logApi('[API] HTTP error parse failed $path: $parseErr', path: path);
        }
      }
    }
    handler.reject(DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: ApiException.network(err.message ?? '网络请求失败!!!', rawData: raw),
    ));
  }
}

/// AES 解密（移植 uniappAPI/aes/aes_util.js decryptAjax）
class _Crypto {
  static dynamic decryptAjax(String key, String value) {
    final keyHex = _strToHex(key);
    final iv = _strToMd5(keyHex);
    final riv = iv.split('').reversed.join();
    final plain = _aesDecrypt(value, riv, iv);
    try {
      return jsonDecode(plain);
    } catch (_) {
      return plain;
    }
  }

  static String _strToHex(String str) {
    final b = StringBuffer();
    for (final c in str.runes) {
      b.write(c.toRadixString(16));
    }
    return b.toString();
  }

  static String _strToMd5(String str) {
    final md5Str = md5.convert(utf8.encode(str)).toString().substring(0, 16);
    return md5Str.split('').reversed.join();
  }

  static String _aesDecrypt(String hex, String keyStr, String ivStr) {
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key.fromUtf8(keyStr), mode: enc.AESMode.cbc, padding: 'PKCS7'),
    );
    final bytes = <int>[];
    final h = hex.length.isOdd ? '0$hex' : hex;
    for (var i = 0; i < h.length; i += 2) {
      bytes.add(int.parse(h.substring(i, i + 2), radix: 16));
    }
    return encrypter.decrypt(
      enc.Encrypted.fromBase64(base64.encode(bytes)),
      iv: enc.IV.fromUtf8(ivStr),
    );
  }
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

void _logApi(String message, {required String path}) {
  if (!_shouldLogApiPath(path)) return;
  if (kDebugMode && ApiConfig.enableLog) {
    // ignore: avoid_print
    print(message);
  }
}

bool _shouldLogApiPath(String path) {
  const allowed = [
    ApiPaths.saveCameraRecord,
    ApiPaths.addCustomSoundEffect,
    ApiPaths.uploadLocalImage,
    ApiPaths.upload,
  ];
  return allowed.any(path.contains);
}

String _prettyJson(dynamic data) {
  if (data == null) return 'null';
  try {
    return const JsonEncoder.withIndent('  ').convert(data);
  } catch (_) {
    return data.toString();
  }
}

dynamic _envelopeDataForLog(dynamic payload) {
  if (payload is Map && payload['k'] != null && payload['r'] != null) {
    final r = payload['r'].toString();
    return {
      'k': payload['k'],
      'r': '${r.substring(0, r.length.clamp(0, 32))}...(${r.length} chars)',
    };
  }
  return payload;
}

String _truncateForLog(dynamic data, {int maxLen = 500}) {
  if (data == null) return 'null';
  final s = data.toString();
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen)}...(${s.length} chars)';
}
