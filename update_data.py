import sys

def update_main():
    with open('lib/main.dart', 'r', encoding='utf-8') as f:
        text = f.read()
    if 'shared_preferences' not in text:
        text = "import 'package:shared_preferences/shared_preferences.dart';\nimport 'services/data_service.dart';\n" + text
        text = text.replace("WidgetsFlutterBinding.ensureInitialized();", "WidgetsFlutterBinding.ensureInitialized();\n  final prefs = await SharedPreferences.getInstance();")
        text = text.replace("const ProviderScope(\n      child: KutbiPaintsApp(),\n    )", "ProviderScope(\n      overrides: [\n        sharedPreferencesProvider.overrideWithValue(prefs),\n      ],\n      child: const KutbiPaintsApp(),\n    )")
        with open('lib/main.dart', 'w', encoding='utf-8') as f:
            f.write(text)

def update_data_service():
    with open('lib/services/data_service.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    if 'extends ChangeNotifier' in content: return

    # 1. Add imports
    content = content.replace("import 'package:uuid/uuid.dart';", "import 'package:uuid/uuid.dart';\nimport 'dart:convert';\nimport 'package:shared_preferences/shared_preferences.dart';\nimport 'package:flutter/foundation.dart';")

    # 2. Change class signature
    content = content.replace("class DataService {", "class DataService extends ChangeNotifier {")

    # 3. Add prefs initialization
    attributes_old = """  // In-memory stores
  List<UserModel> _users = List.from(DemoData.users);
  List<ProductModel> _products = List.from(DemoData.products);
  List<OrderModel> _orders = List.from(DemoData.orders);
  List<GoalModel> _goals = List.from(DemoData.goals);
  List<RewardModel> _rewards = List.from(DemoData.rewards);

  static const _uuid = Uuid();"""

    attributes_new = """  // In-memory stores
  List<UserModel> _users = [];
  List<ProductModel> _products = [];
  List<OrderModel> _orders = [];
  List<GoalModel> _goals = [];
  List<RewardModel> _rewards = [];

  final SharedPreferences prefs;

  DataService(this.prefs) {
    _loadData();
  }

  void _loadData() {
    final u = prefs.getString('users');
    if (u != null) {
      _users = (jsonDecode(u) as List).map((e) => UserModel.fromJson(Map<String,dynamic>.from(e))).toList();
    } else {
      _users = List.from(DemoData.users);
    }
    
    final p = prefs.getString('products');
    if (p != null) {
      _products = (jsonDecode(p) as List).map((e) => ProductModel.fromJson(Map<String,dynamic>.from(e))).toList();
    } else {
      _products = List.from(DemoData.products);
    }
    
    final o = prefs.getString('orders');
    if (o != null) {
      _orders = (jsonDecode(o) as List).map((e) => OrderModel.fromJson(Map<String,dynamic>.from(e))).toList();
    } else {
      _orders = List.from(DemoData.orders);
    }
    
    final g = prefs.getString('goals');
    if (g != null) {
      _goals = (jsonDecode(g) as List).map((e) => GoalModel.fromJson(Map<String,dynamic>.from(e))).toList();
    } else {
      _goals = List.from(DemoData.goals);
    }
    
    final r = prefs.getString('rewards');
    if (r != null) {
      _rewards = (jsonDecode(r) as List).map((e) => RewardModel.fromJson(Map<String,dynamic>.from(e))).toList();
    } else {
      _rewards = List.from(DemoData.rewards);
    }
  }

  void _saveData() {
    prefs.setString('users', jsonEncode(_users.map((e) => e.toJson()).toList()));
    prefs.setString('products', jsonEncode(_products.map((e) => e.toJson()).toList()));
    prefs.setString('orders', jsonEncode(_orders.map((e) => e.toJson()).toList()));
    prefs.setString('goals', jsonEncode(_goals.map((e) => e.toJson()).toList()));
    prefs.setString('rewards', jsonEncode(_rewards.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  static const _uuid = Uuid();"""

    content = content.replace(attributes_old, attributes_new)

    replacements = [
        ("_users.add(user);\n    return user;", "_users.add(user);\n    _saveData();\n    return user;"),
        ("updatedAt: DateTime.now(),\n      );\n    }", "updatedAt: DateTime.now(),\n      );\n      _saveData();\n    }"), 
        ("_users.removeWhere((u) => u.id == userId);", "_users.removeWhere((u) => u.id == userId);\n    _saveData();"),
        ("_products.add(product);", "_products.add(product);\n    _saveData();"),
        ("_products[i] = product;\n    }", "_products[i] = product;\n      _saveData();\n    }"),
        ("_products.removeWhere((p) => p.id == productId);", "_products.removeWhere((p) => p.id == productId);\n    _saveData();"),
        ("_orders.add(newOrder);\n    return newOrder;", "_orders.add(newOrder);\n    _saveData();\n    return newOrder;"),
        ("_goals.add(goal);", "_goals.add(goal);\n    _saveData();"),
        ("_goals[i] = goal;\n    }", "_goals[i] = goal;\n      _saveData();\n    }"),
        ("_rewards.add(reward);", "_rewards.add(reward);\n    _saveData();"),
        ("final dataServiceProvider = Provider<DataService>((ref) {\n  return DataService();\n});", "final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());\n\nfinal dataServiceProvider = ChangeNotifierProvider<DataService>((ref) {\n  final prefs = ref.watch(sharedPreferencesProvider);\n  return DataService(prefs);\n});")
    ]

    for old_s, new_s in replacements:
        content = content.replace(old_s, new_s)

    with open('lib/services/data_service.dart', 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    update_main()
    update_data_service()
