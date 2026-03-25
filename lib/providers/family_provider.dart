import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/family_member.dart';

class FamilyProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<FamilyMember> _familyMembers = [];
  bool _isLoading = false;
  int _completedTasksCount = 0;

  List<FamilyMember> get familyMembers => _familyMembers;
  bool get isLoading => _isLoading;
  int get completedTasksCount => _completedTasksCount;

  Future<void> loadFamilyMembers(String familyId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Загружаем участников семьи через таблицу users
      final membersResponse = await _supabase
          .from('users')
          .select('*')
          .eq('family_id', familyId);

      if (membersResponse != null && membersResponse is List) {
        _familyMembers = (membersResponse as List).map((user) {
          return FamilyMember(
            id: user['id'] as String,
            name: user['name'] as String? ?? 'Неизвестный',
            role: user['user_type'] == 'parent' ? FamilyRole.parent : FamilyRole.child,
            email: user['email'] as String?,
            todayCompletedTasks: 0,
            todayTotalTasks: 0,
          );
        }).toList();
      } else {
        _familyMembers = [];
      }

      // Загружаем статистику выполненных задач
      await _loadCompletedTasksCount(familyId);

    } catch (e) {
      debugPrint('Error loading family members: $e');
      _familyMembers = [];
      _completedTasksCount = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCompletedTasksCount(String familyId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select('id')
          .eq('family_id', familyId)
          .eq('completed', true);

      // Безопасная проверка
      if (response != null && response is List) {
        _completedTasksCount = (response as List).length;
      } else {
        _completedTasksCount = 0;
      }
    } catch (e) {
      debugPrint('Error loading completed tasks count: $e');
      _completedTasksCount = 0;
    }
  }

  void clearFamilyMembers() {
    _familyMembers = [];
    _completedTasksCount = 0;
    notifyListeners();
  }
}