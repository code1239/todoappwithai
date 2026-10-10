import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';
import 'utils.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('apiClientProvider override edilmeli');
});

class AuthState {
  final bool initialized;
  final bool loggedIn;
  final bool loading;
  final String? username;
  final String? error;

  const AuthState({
    this.initialized = false,
    this.loggedIn = false,
    this.loading = false,
    this.username,
    this.error,
  });

  AuthState copyWith({
    bool? initialized,
    bool? loggedIn,
    bool? loading,
    String? username,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      initialized: initialized ?? this.initialized,
      loggedIn: loggedIn ?? this.loggedIn,
      loading: loading ?? this.loading,
      username: username ?? this.username,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient api;
  AuthNotifier(this.api) : super(const AuthState()) {
    _restore();
  }

  Future<void> _restore() async {
    final token = await api.getToken();
    state = state.copyWith(
      initialized: true,
      loggedIn: token != null && token.isNotEmpty,
    );
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await api.login(username, password);
      state = state.copyWith(loading: false, loggedIn: true, username: username);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    }
  }

  Future<bool> register(String username, String password, {String? email}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await api.register(username, password, email: email);
      state = state.copyWith(loading: false, loggedIn: true, username: username);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    }
  }

  Future<void> logout() async {
    await api.logout();
    state = const AuthState(initialized: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(apiClientProvider));
});

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final date = ref.watch(selectedDateProvider);
  return api.dashboard(date: fmtDate(date));
});

final proposalsProvider = FutureProvider.autoDispose<List<Proposal>>((ref) async {
  return ref.watch(apiClientProvider).proposals();
});

final weekGoalsProvider =
    FutureProvider.autoDispose.family<List<WeeklyGoal>, String>((ref, weekStart) async {
  return ref.watch(apiClientProvider).goals(weekStart);
});

final weekPlanProvider =
    FutureProvider.autoDispose.family<WeekPlanData, String>((ref, date) async {
  return ref.watch(apiClientProvider).weekPlan(date);
});

class ChatState {
  final int? sessionId;
  final List<ChatMessage> messages;
  final bool loading;
  final bool sending;
  final String? error;

  const ChatState({
    this.sessionId,
    this.messages = const [],
    this.loading = false,
    this.sending = false,
    this.error,
  });

  ChatState copyWith({
    int? sessionId,
    List<ChatMessage>? messages,
    bool? loading,
    bool? sending,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiClient api;
  final Ref ref;
  ChatNotifier(this.api, this.ref) : super(const ChatState()) {
    _load();
  }

  List<ChatMessage> _parse(dynamic raw) {
    final list = (raw as List?) ?? const [];
    return list
        .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> _load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await api.chatMessages();
      state = ChatState(
        sessionId: res['session_id'] as int?,
        messages: _parse(res['messages']),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  void newSession() {
    state = const ChatState();
  }

  Future<void> loadSession(int id) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await api.chatMessages(sessionId: id);
      state = ChatState(
        sessionId: res['session_id'] as int? ?? id,
        messages: _parse(res['messages']),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.sending) return;
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(role: 'user', content: message)],
      sending: true,
      clearError: true,
    );
    try {
      final res = await api.sendChat(message, sessionId: state.sessionId);
      final reply = ChatMessage(
        role: 'assistant',
        content: res['reply'] as String? ?? '',
        draft: (res['draft'] as Map?)?.cast<String, dynamic>() ?? const {},
        proposalId: res['proposal_id'] as int?,
      );
      state = state.copyWith(
        sessionId: res['session_id'] as int?,
        messages: [...state.messages, reply],
        sending: false,
      );
      if (reply.proposalId != null) {
        ref.invalidate(proposalsProvider);
      }
    } catch (e) {
      state = state.copyWith(sending: false, error: '$e');
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(apiClientProvider), ref);
});
