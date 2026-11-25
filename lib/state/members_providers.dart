import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/api_client.dart';
import '../models/project.dart';
import '../models/project_member.dart';
import 'auth_providers.dart';
import 'projects_providers.dart';

class MembersRepository {
  MembersRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<ProjectMember>> listMembers(String projectId) async {
    final data = await _api.getProjectMembers(projectId);
    return [for (final entry in data) ProjectMember.fromJson(entry)];
  }

  Future<ProjectMember> addMember(
    String projectId, {
    required String email,
    String? role,
  }) async {
    final data = await _api.addProjectMember(
      projectId,
      email: email,
      role: role,
    );
    return ProjectMember.fromJson(data);
  }

  Future<void> removeMember(String projectId, String userId) {
    return _api.removeProjectMember(projectId, userId);
  }
}

final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  return MembersRepository(api: ref.read(apiClientProvider));
});

class MembersNotifier extends AsyncNotifier<List<ProjectMember>> {
  MembersNotifier(this.projectId);

  final String projectId;

  @override
  Future<List<ProjectMember>> build() async {
    return ref.read(membersRepositoryProvider).listMembers(projectId);
  }

  List<ProjectMember> get members => state.value ?? const <ProjectMember>[];

  Future<void> refresh() async {
    state = const AsyncValue<List<ProjectMember>>.loading();
    try {
      final members = await ref.read(membersRepositoryProvider).listMembers(
            projectId,
          );
      state = AsyncValue.data(members);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<ProjectMember> addMember({
    required String email,
    String? role,
  }) async {
    final member = await ref.read(membersRepositoryProvider).addMember(
          projectId,
          email: email,
          role: role,
        );
    final current = members;
    if (!current.any((item) => item.userId == member.userId)) {
      state = AsyncValue.data([...current, member]);
    }
    return member;
  }

  Future<void> removeMember(String userId) async {
    final previous = List<ProjectMember>.of(members);
    state = AsyncValue.data(<ProjectMember>[
      for (final member in previous)
        if (member.userId != userId) member,
    ]);
    try {
      await ref.read(membersRepositoryProvider).removeMember(projectId, userId);
    } catch (_) {
      state = AsyncValue.data(previous);
      rethrow;
    }
  }
}

final membersProvider =
    AsyncNotifierProvider.family<MembersNotifier, List<ProjectMember>, String>(
  MembersNotifier.new,
);

final selectedProjectIdProvider = StateProvider<String?>((_) => null);

final selectedProjectProvider = Provider<Project?>((ref) {
  final projects = ref.watch(projectsProvider).value ?? const <Project>[];
  if (projects.isEmpty) return null;
  final selectedId = ref.watch(selectedProjectIdProvider);
  if (selectedId != null) {
    for (final project in projects) {
      if (project.id == selectedId) return project;
    }
  }
  return projects.first;
});
