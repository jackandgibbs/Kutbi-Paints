import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConstants {
  // Easy access to the Supabase client
  static final client = Supabase.instance.client;

  // Table names
  static const String usersTable = 'users';
  static const String productsTable = 'products';
  static const String ordersTable = 'orders';
  static const String orderItemsTable = 'order_items';
  static const String goalsTable = 'goals';
  static const String rewardsTable = 'rewards';
}
