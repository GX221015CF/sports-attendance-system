import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';
import '../services/offline_attendance_service.dart';
import '../services/offline_store.dart';
import 'current_session_page.dart';
import 'offline_home_page.dart';

class ModeHomePage extends StatefulWidget {
  const ModeHomePage({super.key, this.local});
  final OfflineAttendanceService? local;
  @override
  State<ModeHomePage> createState() => _ModeHomePageState();
}

class _ModeHomePageState extends State<ModeHomePage> {
  late final OfflineAttendanceService _local;
  bool? _offline;
  String? _error;

  @override
  void initState() {
    super.initState();
    _local =
        widget.local ??
        OfflineAttendanceService(
          store: OfflineStore(),
          scope: const Uuid().v5(Namespace.url.value, supabaseUrl),
        );
    _loadMode();
  }

  Future<void> _loadMode() async {
    try {
      final offline = await _local.getOfflineMode();
      if (mounted) {
        setState(() {
          _offline = offline;
          _error = null;
        });
      }
    } on Object catch (_) {
      if (mounted) setState(() => _error = '本地数据读取失败。请重试，不要清除应用数据。');
    }
  }

  Future<void> _switchMode(bool offline) async {
    try {
      await _local.setOfflineMode(offline);
      if (mounted) setState(() => _offline = offline);
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('模式保存失败，请重试。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              TextButton(onPressed: _loadMode, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_offline == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_offline!) {
      return OfflineHomePage(
        local: _local,
        onGoOnline: () => _switchMode(false),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.cloud_outlined, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('在线模式 · 实时读取云端')),
                  TextButton.icon(
                    onPressed: () => _switchMode(true),
                    icon: const Icon(Icons.offline_bolt_outlined),
                    label: const Text('离线模式'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: hasSupabaseConfig
                  ? const CurrentSessionPage()
                  : const Center(child: Text('未配置线上服务，可进入离线模式查看本机记录。')),
            ),
          ],
        ),
      ),
    );
  }
}
