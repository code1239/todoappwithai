class Task {
  final int id;
  final String title;
  final String notes;
  final String date; // yyyy-MM-dd
  final String kind; // block | list
  final String? startTime; // HH:mm
  final String? endTime;
  final int? durationMinutes;
  final String priority;
  final String status;
  final int order;
  final int? goalId;
  final String? goalTitle;

  Task({
    required this.id,
    required this.title,
    required this.notes,
    required this.date,
    required this.kind,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.priority,
    required this.status,
    required this.order,
    required this.goalId,
    required this.goalTitle,
  });

  bool get isBlock => kind == 'block';
  bool get isDone => status == 'done';

  String get timeLabel {
    if (!isBlock || startTime == null || endTime == null) return '';
    return '$startTime - $endTime';
  }

  static String? _hhmm(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  factory Task.fromJson(Map<String, dynamic> j) {
    return Task(
      id: j['id'] as int,
      title: j['title'] as String? ?? '',
      notes: j['notes'] as String? ?? '',
      date: j['date'] as String,
      kind: j['kind'] as String? ?? 'list',
      startTime: _hhmm(j['start_time']),
      endTime: _hhmm(j['end_time']),
      durationMinutes: j['duration_minutes'] as int?,
      priority: j['priority'] as String? ?? 'medium',
      status: j['status'] as String? ?? 'todo',
      order: j['order'] as int? ?? 0,
      goalId: j['goal'] as int?,
      goalTitle: j['goal_title'] as String?,
    );
  }
}

class WeeklyGoal {
  final int id;
  final String title;
  final String description;
  final String metric; // count | duration
  final int target;
  final String weekStart;
  final bool isActive;
  final int done;
  final int progressTarget;

  WeeklyGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.weekStart,
    required this.isActive,
    required this.done,
    required this.progressTarget,
  });

  double get ratio => progressTarget == 0 ? 0 : (done / progressTarget).clamp(0, 1);

  String get metricLabel => metric == 'duration' ? 'dakika' : 'kez';

  factory WeeklyGoal.fromJson(Map<String, dynamic> j) {
    final progress = (j['progress'] as Map<String, dynamic>?) ?? const {};
    return WeeklyGoal(
      id: j['id'] as int,
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      metric: j['metric'] as String? ?? 'count',
      target: j['target'] as int? ?? 0,
      weekStart: j['week_start'] as String? ?? '',
      isActive: j['is_active'] as bool? ?? true,
      done: progress['done'] as int? ?? 0,
      progressTarget: progress['target'] as int? ?? j['target'] as int? ?? 0,
    );
  }
}

class Proposal {
  final int id;
  final String kind;
  final String status;
  final String summary;
  final List<dynamic> changes;
  final String error;
  final String createdAt;

  Proposal({
    required this.id,
    required this.kind,
    required this.status,
    required this.summary,
    required this.changes,
    required this.error,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get hasError => error.isNotEmpty;

  String get kindLabel {
    switch (kind) {
      case 'goal_breakdown':
        return 'Haftalik hedef bolumu';
      case 'daily_review':
        return 'Gun sonu degerlendirme';
      default:
        return 'Plan revizyonu';
    }
  }

  factory Proposal.fromJson(Map<String, dynamic> j) {
    final payload = (j['payload'] as Map<String, dynamic>?) ?? const {};
    return Proposal(
      id: j['id'] as int,
      kind: j['kind'] as String? ?? '',
      status: j['status'] as String? ?? 'pending',
      summary: j['summary'] as String? ?? '',
      changes: (payload['changes'] as List<dynamic>?) ?? const [],
      error: j['error'] as String? ?? '',
      createdAt: j['created_at'] as String? ?? '',
    );
  }
}

class DashboardData {
  final String date;
  final String weekStart;
  final List<Task> blocks;
  final List<Task> list;
  final List<WeeklyGoal> goals;

  DashboardData({
    required this.date,
    required this.weekStart,
    required this.blocks,
    required this.list,
    required this.goals,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    return DashboardData(
      date: j['date'] as String,
      weekStart: j['week_start'] as String? ?? '',
      blocks: (j['blocks'] as List).map((e) => Task.fromJson(e)).toList(),
      list: (j['list'] as List).map((e) => Task.fromJson(e)).toList(),
      goals: (j['goals'] as List).map((e) => WeeklyGoal.fromJson(e)).toList(),
    );
  }
}

class WeekPlanData {
  final String weekStart;
  final List<WeekDayPlan> days;

  WeekPlanData({
    required this.weekStart,
    required this.days,
  });

  factory WeekPlanData.fromJson(Map<String, dynamic> j) {
    return WeekPlanData(
      weekStart: j['week_start'] as String? ?? '',
      days: (j['days'] as List).map((e) => WeekDayPlan.fromJson(e)).toList(),
    );
  }
}

class WeekDayPlan {
  final String date;
  final int weekday;
  final List<Task> blocks;
  final List<Task> list;

  WeekDayPlan({
    required this.date,
    required this.weekday,
    required this.blocks,
    required this.list,
  });

  bool get isEmpty => blocks.isEmpty && list.isEmpty;

  factory WeekDayPlan.fromJson(Map<String, dynamic> j) {
    return WeekDayPlan(
      date: j['date'] as String,
      weekday: j['weekday'] as int? ?? 0,
      blocks: (j['blocks'] as List).map((e) => Task.fromJson(e)).toList(),
      list: (j['list'] as List).map((e) => Task.fromJson(e)).toList(),
    );
  }
}

class ChatMessage {
  final int? id;
  final String role;
  final String content;
  final Map<String, dynamic> draft;
  final int? proposalId;
  final String createdAt;

  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.draft = const {},
    this.proposalId,
    this.createdAt = '',
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final draft = (j['draft'] as Map<String, dynamic>?) ?? const {};
    return ChatMessage(
      id: j['id'] as int?,
      role: j['role'] as String? ?? 'assistant',
      content: j['content'] as String? ?? '',
      draft: draft,
      proposalId: j['proposal'] as int?,
      createdAt: j['created_at'] as String? ?? '',
    );
  }
}

class ChatSession {
  final int? id;
  final String updatedAt;
  final String createdAt;
  final String preview;

  ChatSession({
    this.id,
    this.updatedAt = '',
    this.createdAt = '',
    this.preview = '',
  });

  factory ChatSession.fromJson(Map<String, dynamic> j) {
    return ChatSession(
      id: j['id'] as int?,
      updatedAt: j['updated_at'] as String? ?? '',
      createdAt: j['created_at'] as String? ?? '',
      preview: j['preview'] as String? ?? '',
    );
  }
}
