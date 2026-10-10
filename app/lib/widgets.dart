import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'providers.dart';
import 'utils.dart';

Color priorityColor(String p) {
  switch (p) {
    case 'high':
      return Colors.red;
    case 'low':
      return Colors.green;
    default:
      return Colors.orange;
  }
}

String priorityLabel(String p) {
  switch (p) {
    case 'high':
      return 'Yuksek';
    case 'low':
      return 'Dusuk';
    default:
      return 'Orta';
  }
}

class TaskTile extends ConsumerWidget {
  final Task task;
  const TaskTile({required this.task, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: task.isDone,
          onChanged: (_) async {
            await ref.read(apiClientProvider).completeTask(task.id);
            ref.invalidate(dashboardProvider);
          },
        ),
        title: Text(
          task.title,
          style: task.isDone
              ? const TextStyle(
                  decoration: TextDecoration.lineThrough, color: Colors.grey)
              : null,
        ),
        subtitle: Row(
          children: [
            if (task.timeLabel.isNotEmpty) ...[
              const Icon(Icons.schedule, size: 14),
              const SizedBox(width: 4),
              Text(task.timeLabel),
              const SizedBox(width: 10),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor(task.priority).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                priorityLabel(task.priority),
                style: TextStyle(
                  fontSize: 11,
                  color: priorityColor(task.priority),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (task.goalTitle != null) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '# ${task.goalTitle}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.indigo),
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await ref.read(apiClientProvider).deleteTask(task.id);
            ref.invalidate(dashboardProvider);
          },
        ),
      ),
    );
  }
}

class GoalTile extends ConsumerWidget {
  final WeeklyGoal goal;
  const GoalTile({required this.goal, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Text('${goal.done}/${goal.progressTarget} ${goal.metricLabel}'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: goal.ratio,
                minHeight: 8,
                backgroundColor: Colors.black12,
              ),
            ),
            if (goal.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(goal.description,
                  style: const TextStyle(color: Colors.black54)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Gunlere bol (AI)'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('AI onerisi hazirlaniyor...')),
                  );
                  try {
                    final p = await ref
                        .read(apiClientProvider)
                        .propose('goal_breakdown', goalId: goal.id);
                    ref.invalidate(proposalsProvider);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text('Oneri olusturuldu: ${p.summary}')),
                    );
                  } catch (e) {
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAddTaskSheet(BuildContext context, WidgetRef ref,
    {required DateTime date, List<WeeklyGoal> goals = const []}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AddTaskSheet(date: date, goals: goals),
  );
}

class _AddTaskSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final List<WeeklyGoal> goals;
  const _AddTaskSheet({required this.date, required this.goals});

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  String _kind = 'list';
  String _priority = 'medium';
  int? _goalId;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _fmt(TimeOfDay? t) =>
      t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).createTask({
        'title': _title.text.trim(),
        'notes': _notes.text.trim(),
        'date': fmtDate(widget.date),
        'kind': _kind,
        'priority': _priority,
        if (_kind == 'block' && _start != null) 'start_time': _fmt(_start),
        if (_kind == 'block' && _end != null) 'end_time': _fmt(_end),
        if (_goalId != null) 'goal': _goalId,
      });
      ref.invalidate(dashboardProvider);
      ref.invalidate(weekGoalsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni gorev - ${fmtDayLabel(widget.date)}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Baslik',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'list', label: Text('Liste')),
              ButtonSegment(value: 'block', label: Text('Saatli blok')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(_start == null ? 'Baslangic' : _fmt(_start)!),
                  onPressed: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                    if (t != null) setState(() => _start = t);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(_end == null ? 'Bitis' : _fmt(_end)!),
                  onPressed: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
                    if (t != null) setState(() => _end = t);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: const InputDecoration(
                labelText: 'Oncelik', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Dusuk')),
              DropdownMenuItem(value: 'medium', child: Text('Orta')),
              DropdownMenuItem(value: 'high', child: Text('Yuksek')),
            ],
            onChanged: (v) => setState(() => _priority = v ?? 'medium'),
          ),
          if (widget.goals.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _goalId,
              decoration: const InputDecoration(
                  labelText: 'Haftalik hedef', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('Yok')),
                ...widget.goals.map(
                  (g) => DropdownMenuItem(value: g.id, child: Text(g.title)),
                ),
              ],
              onChanged: (v) => setState(() => _goalId = v),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

Future<void> showAddGoalSheet(BuildContext context, WidgetRef ref,
    {required DateTime weekStart}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AddGoalSheet(weekStart: weekStart),
  );
}

class _AddGoalSheet extends ConsumerStatefulWidget {
  final DateTime weekStart;
  const _AddGoalSheet({required this.weekStart});

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _title = TextEditingController();
  final _target = TextEditingController(text: '3');
  String _metric = 'count';
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).createGoal({
        'title': _title.text.trim(),
        'metric': _metric,
        'target': int.tryParse(_target.text.trim()) ?? 1,
        'week_start': fmtDate(widget.weekStart),
      });
      ref.invalidate(dashboardProvider);
      ref.invalidate(weekGoalsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni haftalik hedef',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Hedef (orn: 3 kez spor)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'count', label: Text('Adet')),
              ButtonSegment(value: 'duration', label: Text('Dakika')),
            ],
            selected: {_metric},
            onSelectionChanged: (s) => setState(() => _metric = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Hedef deger',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
