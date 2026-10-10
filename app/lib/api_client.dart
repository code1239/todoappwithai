import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  static const _baseUrlKey = 'base_url';
  static const _tokenKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const androidDefaultBaseUrl = 'http://10.0.2.2:8000/api';
  static const webDefaultBaseUrl = 'http://127.0.0.1:8000/api';

  static String get defaultBaseUrl =>
      kIsWeb ? webDefaultBaseUrl : androidDefaultBaseUrl;

  final Dio _dio;
  String baseUrl;

  ApiClient._(this.baseUrl)
      : _dio = Dio(
          BaseOptions(
            responseType: ResponseType.json,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 90),
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static Future<ApiClient> create() async {
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
    return ApiClient._(base);
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
  }

  Never _fail(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      String msg = e.message ?? 'Baglanti hatasi';
      if (data is Map && data['detail'] != null) {
        msg = data['detail'].toString();
      } else if (data is Map) {
        msg = data.entries.map((x) => '${x.key}: ${x.value}').join('\n');
      }
      throw ApiException(msg, e.response?.statusCode);
    }
    throw ApiException(e.toString());
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await _dio.post('$baseUrl$path', data: body);
      return (r.data as Map).cast<String, dynamic>();
    } catch (e) {
      _fail(e);
    }
  }

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final r = await _dio.get('$baseUrl$path', queryParameters: query);
      return r.data;
    } catch (e) {
      _fail(e);
    }
  }

  // ---- auth ----
  Future<void> login(String username, String password) async {
    final data = await _post('/token/', {'username': username, 'password': password});
    await saveTokens(data['access'] as String, data['refresh'] as String);
  }

  Future<void> register(String username, String password, {String? email}) async {
    await _post('/auth/register', {
      'username': username,
      'password': password,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    await login(username, password);
  }

  Future<void> logout() => clearTokens();

  // ---- dashboard ----
  Future<DashboardData> dashboard({String? date}) async {
    final data = await _get('/dashboard/today', date == null ? null : {'date': date});
    return DashboardData.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<WeekPlanData> weekPlan(String date) async {
    final data = await _get('/week-plan', {'date': date});
    return WeekPlanData.fromJson((data as Map).cast<String, dynamic>());
  }

  // ---- tasks ----
  Future<void> createTask(Map<String, dynamic> body) => _post('/tasks/', body);

  Future<void> createGoal(Map<String, dynamic> body) => _post('/goals/', body);

  Future<List<WeeklyGoal>> goals(String weekStart) async {
    final data = await _get('/goals/', {'week_start': weekStart});
    final list = (data is Map ? data['value'] : data) as List;
    return list
        .map((e) => WeeklyGoal.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> updateTask(int id, Map<String, dynamic> body) async {
    try {
      await _dio.patch('$baseUrl/tasks/$id/', data: body);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      await _dio.delete('$baseUrl/tasks/$id/');
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> completeTask(int id) async {
    try {
      await _dio.post('$baseUrl/tasks/$id/complete/');
    } catch (e) {
      _fail(e);
    }
  }

  // ---- ai ----
  Future<List<Proposal>> proposals() async {
    final data = await _get('/ai/proposals/');
    final list = (data is Map ? data['value'] : data) as List;
    return list.map((e) => Proposal.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Proposal> propose(String kind, {int? goalId, String? date}) async {
    final data = await _post('/ai/propose', {
      'kind': kind,
      'goal_id': ?goalId,
      'date': ?date,
    });
    return Proposal.fromJson(data);
  }

  Future<Proposal> dailyReview({String? date}) async {
    final data = await _post('/ai/daily-review', {
      'date': ?date,
    });
    return Proposal.fromJson(data);
  }

  Future<Map<String, dynamic>> approve(int id) => _post('/ai/proposals/$id/approve/', {});

  Future<void> reject(int id) async {
    await _post('/ai/proposals/$id/reject/', {});
  }

  // ---- chat ----
  Future<Map<String, dynamic>> sendChat(String message, {int? sessionId}) async {
    return _post('/ai/chat', {
      'message': message,
      'session_id': ?sessionId,
    });
  }

  Future<Map<String, dynamic>> chatMessages({int? sessionId}) async {
    final data = await _get(
      '/ai/chat',
      sessionId == null ? null : {'session_id': sessionId},
    );
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<ChatSession>> chatSessions() async {
    final data = await _get('/ai/chat/sessions');
    final list = ((data as Map)['sessions'] as List?) ?? const [];
    return list
        .map((e) => ChatSession.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
