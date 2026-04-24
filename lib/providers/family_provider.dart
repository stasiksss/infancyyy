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
        final baseMembers = (membersResponse as List).map((user) {
          return FamilyMember(
            id: user['id'] as String,
            name: user['name'] as String? ?? 'Неизвестный',
            role: user['user_type'] == 'parent' ? FamilyRole.parent : FamilyRole.child,
            email: user['email'] as String?,
            todayCompletedTasks: 0,
            todayTotalTasks: 0,
          );
        }).toList();

        _familyMembers = await _loadMemberTaskStats(baseMembers, familyId);
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

  Future<List<FamilyMember>> _loadMemberTaskStats(
    List<FamilyMember> members,
    String familyId,
  ) async {
    if (members.isEmpty) return members;

    try {
      final response = await _supabase
          .from('task_assignments')
          .select('user_id, tasks!inner(id, completed, family_id)')
          .eq('tasks.family_id', familyId);

      final totalByUser = <String, int>{};
      final completedByUser = <String, int>{};

      for (final item in (response as List)) {
        final row = item as Map<String, dynamic>;
        final userId = row['user_id'] as String?;
        final task = row['tasks'] as Map<String, dynamic>?;
        if (userId == null || task == null) continue;

        totalByUser[userId] = (totalByUser[userId] ?? 0) + 1;
        if (task['completed'] == true) {
          completedByUser[userId] = (completedByUser[userId] ?? 0) + 1;
        }
      }

      return members
          .map(
            (member) => FamilyMember(
              id: member.id,
              name: member.name,
              role: member.role,
              email: member.email,
              todayCompletedTasks: completedByUser[member.id] ?? 0,
              todayTotalTasks: totalByUser[member.id] ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error loading member task stats: $e');
      return members;
    }
  }

  void clearFamilyMembers() {
    _familyMembers = [];
    _completedTasksCount = 0;
    notifyListeners();
  }
}