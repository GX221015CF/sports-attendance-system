import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class ConnectionTestPage extends StatefulWidget {
  const ConnectionTestPage({super.key});

  @override
  State<ConnectionTestPage> createState() => _ConnectionTestPageState();
}

class _ConnectionTestPageState extends State<ConnectionTestPage> {
  bool _loading = false;
  int? _memberCount;
  String? _errorMessage;

  Future<void> _testConnection() async {
    setState(() {
      _loading = true;
      _memberCount = null;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('members')
          .select()
          .count(CountOption.exact);

      if (!mounted) {
        return;
      }

      setState(() {
        _memberCount = response.count;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supabase 连接测试')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supabase 连接测试',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '当前页面只用于验证 Flutter App 是否能通过 Supabase anon key 读取 members 表数量。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    if (!hasSupabaseConfig)
                      _InfoPanel(
                        color: Theme.of(context).colorScheme.error,
                        title: '未配置 Supabase',
                        message:
                            '请使用 --dart-define 传入 SUPABASE_URL 和 SUPABASE_ANON_KEY。',
                      )
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _testConnection,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_done_outlined),
                          label: Text(_loading ? '测试中...' : '测试连接'),
                        ),
                      ),
                      if (_memberCount != null) ...[
                        const SizedBox(height: 16),
                        _InfoPanel(
                          color: const Color(0xFF22C55E),
                          title: '连接成功',
                          message: 'Supabase 连接成功，成员数量：$_memberCount',
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _InfoPanel(
                          color: Theme.of(context).colorScheme.error,
                          title: '连接失败',
                          message: _errorMessage!,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.color,
    required this.title,
    required this.message,
  });

  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(message),
        ],
      ),
    );
  }
}
