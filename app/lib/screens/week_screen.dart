import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../providers.dart';
import '../utils.dart';
import '../widgets.dart';

class WeekScreen extends ConsumerStatefulWidget {
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  late DateTime _weekStart = weekStartOf(DateTime.now());

  void _shift(int weeks) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * weeks)));
  }

  @override
  Widget build(BuildContext context) {
    final key = fmtDate(_weekStart);
    final goals = ref.watch(weekGoalsProvider(key));
    final weekPlan = ref.watch(weekPlanProvider(key));
    final weekEnd = _weekStart.add(const Duration(days: 6));

    return Scaffold(
      appBar: AppBar(title: const Text('Haftalik plan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddGoalSheet(context, ref, weekStart: _weekStart),
        icon: const Icon(Icons.add),
        label: const Text('Hedef'),
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
                Column(
                  children: [
                    const Text('Hafta',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${fmtShort(_weekStart)} - ${fmtShort(weekEnd)}'),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shift(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: goals.when(
              data: (list) {
                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(weekGoalsProvider(key).future);
                    ref.invalidate(weekGoalsProvider(key));
                    await ref.read(weekPlanProvider(key).future);
                    ref.invalidate(weekPlanProvider(key));
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 96, top: 8),
                    children: [
                      if (list.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Bu hafta icin hedef yok.\n+ ile haftalik hedef ekle.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ...list.map((g) => GoalTile(goal: g)),
                      _WeekDaysSection(plan: weekPlan),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$e', textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDaysSection extends ConsumerWidget {
  final AsyncValue<WeekPlanData> plan;
  const _WeekDaysSection({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            'Haftanin plani (tum gunler)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        plan.when(
          data: (p) => _WeekDays(plan: p),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$e', style: const TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}

class _WeekDays extends StatelessWidget {
  final WeekPlanData plan;
  const _WeekDays({required this.plan});

  @override
  Widget build(BuildContext context) {
    final todayKey = fmtDate(DateTime.now());
    final anyTask = plan.days.any((d) => !d.isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!anyTask)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Bu hafta henuz gorev yok.',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          ...plan.days.map(
            (d) => _DayBlock(day: d, isToday: d.date == todayKey),
          ),
      ],
    );
  }
}

class _DayBlock extends StatelessWidget {
  final WeekDayPlan day;
  final bool isToday;
  const _DayBlock({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final count = day.blocks.length + day.list.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  fmtDayLabel(parseDay(day.date)),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isToday
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black87,
                  ),
                ),
              ),
              if (count > 0)
                Text(
                  '$count gorev',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
            ],
          ),
        ),
        if (day.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Gorev yok',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ),
        if (day.blocks.isNotEmpty) ...[
          const _DaySection('Saatli'),
          ...day.blocks.map((t) => TaskTile(task: t)),
        ],
        if (day.list.isNotEmpty) ...[
          const _DaySection('Liste'),
          ...day.list.map((t) => TaskTile(task: t)),
        ],
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  final String title;
  const _DaySection(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
