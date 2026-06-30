import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  try {
    final client = Supabase.instance.client;
    client.from('qr_codes').update({'status': 'active'}).eq('batch_id', '1').isFilter('used_by', null);
    client.from('qr_codes').update({'status': 'active'}).eq('batch_id', '1').not('used_by', 'is', null);
  } catch (_) {}
}
