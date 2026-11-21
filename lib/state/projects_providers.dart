import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import '../models/project.dart';
import '../models/project_create.dart';

/// Список проектов пользователя: `AsyncValue<List<Project>>` —
/// `isLoading` / `hasError`; список — `projects`.
class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final repository = ref.read(authRepositoryProvider);
    return repository.listProjects();
  }

  List<Project> get projects => state.value ?? const [];

  /// Создать проект (`POST /api/v1/projects`) и добавить в список.
  Future<Project> createProject(ProjectCreate create) async {
    final repository = ref.read(authRepositoryProvider);
    final project = await repository.createProject(create);
    final current = projects;
    if (!current.any((p) => p.id == project.id)) {
      state = AsyncValue.data([...current, project]);
    }
    return project;
  }

  /// Перечитать список с сервера.
  Future<void> refresh() async {
    final repository = ref.read(authRepositoryProvider);
    state = AsyncValue.loading();
    state = AsyncValue.data(await repository.listProjects());
  }
}

final projectsProvider = AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);
