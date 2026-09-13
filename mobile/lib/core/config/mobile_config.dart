class MobileConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const authCallbackUrl = String.fromEnvironment(
      'AUTH_CALLBACK_URL',
      defaultValue: 'https://battlegraf-landing-five.vercel.app',
    );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
