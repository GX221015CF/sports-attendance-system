// Pass these values with --dart-define when running the app.
// Do not hard-code real Supabase URL or keys in source code.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get hasSupabaseConfig =>
    supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
