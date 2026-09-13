import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://mlzrqgocvenrwjnabljm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1senJxZ29jdmVucndqbmFibGptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NTg5NjEsImV4cCI6MjA4OTEzNDk2MX0.kcO8daZS3KM6keSZX-PlaShP_JRxJ2U0eUS5Nmn6AWA',
  );

  try {
    final res = await client
        .from('orders')
        .select()
        .order('created_at', ascending: false)
        .limit(10);
    print('Last 10 orders count: ${res.length}');
    for (final o in res) {
      print('Order ID: ${o['id']}, painter_id: ${o['painter_id']}, name: ${o['painter_name']}, phone: ${o['painter_phone']}, status: ${o['status']}, site: ${o['site_location']}, created_at: ${o['created_at']}');
    }
  } catch (e) {
    print('Error querying orders: $e');
  }
}
