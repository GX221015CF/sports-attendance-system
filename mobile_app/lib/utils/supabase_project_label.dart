import '../config/supabase_config.dart';

String getSupabaseProjectLabel() {
  if (supabaseUrl.isEmpty) {
    return 'Supabase 未配置';
  }

  final uri = Uri.tryParse(supabaseUrl);
  final host = uri?.host ?? '';
  if (host.isEmpty) {
    return 'Supabase 地址格式异常';
  }

  final projectRef = host.split('.').first;
  if (projectRef.length <= 10) {
    return 'Supabase 项目：$host';
  }

  final maskedRef =
      '${projectRef.substring(0, 6)}****${projectRef.substring(projectRef.length - 4)}';
  return 'Supabase 项目：$maskedRef.supabase.co';
}
