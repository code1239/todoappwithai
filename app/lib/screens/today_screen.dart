import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../providers.dart';
import '../utils.dart';
import '../widgets.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  Future<void> _aiRevise(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('AI plani inceliyor...')));
    try {
      final date = ref.read(selectedDateProvider);
      final p = await ref.read(apiClientProvider).propose(
            'revise_plan',
            date: fmtDate(date),
          );
      ref.invalidate(proposalsProvider);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            p.hasError
                ? 'Hata: ${p.error}'
                : 'Oneri hazir: ${p.summary.isEmpty ? p.kindLabel : p.summary}',
          ),
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final dash = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Planim'),
            Text(
              fmtDayLabel(date),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Planimi duzenle (AI)',
            onPressed: () => _aiRevise(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddTaskSheet(
          context,
          ref,
          date: date,
          goals: dash.value?.goals ?? const [],
        ),
        icon: const Icon(Icons.add),
        label: const Text('Gorev'),
      ),
      body: Column(
        children: [
          _DaySelector(date: date),
          Expanded(
            child: dash.when(
              data: (d) => _buildBody(context, ref, d),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('$e', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.invalidate(dashboardProvider),
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, DashboardData d) {
    if (d.blocks.isEmpty && d.list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardProvider.future),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.event_available, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('Bu gun icin gorev yok. + ile ekle.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(dashboardProvider.future),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96, top: 4),
        children: [
          if (d.blocks.isNotEmpty) const _SectionHeader('Saatli plan'),
          ...d.blocks.map((t) => TaskTile(task: t)),
          if (d.list.isNotEmpty) const _SectionHeader('Liste'),
          ...d.list.map((t) => TaskTile(task: t)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DaySelector extends ConsumerWidget {
  final DateTime date;
  const _DaySelector({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void setDate(DateTime d) =>
        ref.read(selectedDateProvider.notifier).state = d;
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setDate(date.subtract(const Duration(days: 1))),
          ),
          TextButton(
            onPressed: () => setDate(DateTime.now()),
            child: Text(fmtDayLabel(date)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setDate(date.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }
}
