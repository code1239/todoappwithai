import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: ref.read(apiClientProvider).baseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(auth.username ?? 'Kullanici'),
              subtitle: const Text('Giris yapildi'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Sunucu adresi (API)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'http://10.0.2.2:8000/api',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Android emulator: http://10.0.2.2:8000/api\n'
            'USB ile gercek cihaz (adb reverse): http://127.0.0.1:8000/api\n'
            'Ayni wifi: http://<bilgisayar-ip>:8000/api',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Kaydet'),
            onPressed: () async {
              await ref.read(apiClientProvider).setBaseUrl(_url.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sunucu adresi kaydedildi')),
                );
              }
            },
          ),
          const Divider(height: 40),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Cikis yap'),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
