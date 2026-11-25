import 'dart:io';

import 'package:arij_server/src/db/migration_runner.dart';
import 'package:test/test.dart';

void main() {
  const migrations = <String>[
    '0000_schema_migrations.sql',
    '0001_users.sql',
    '0002_projects.sql',
    '0003_project_members.sql',
    '0004_task_enums.sql',
    '0005_task_types_statuses.sql',
    '0006_tasks.sql',
    '0007_task_status_history.sql',
  ];

  group('миграции (server/migrations)', () {
    test('пронумерованы без пропусков и дублей', () {
      expect(discoverMigrations('migrations'), migrations);
    });

    test('0000_schema_migrations.sql создаёт schema_migrations', () {
      final sql = File(
        'migrations/0000_schema_migrations.sql',
      ).readAsStringSync();
      expect(sql, contains('CREATE TABLE IF NOT EXISTS schema_migrations'));
      expect(sql, contains('filename TEXT PRIMARY KEY'));
      expect(sql, contains('applied_at TIMESTAMPTZ NOT NULL DEFAULT now()'));
    });

    test('0001_users.sql создаёт citext и таблицу users', () {
      final sql = File('migrations/0001_users.sql').readAsStringSync();
      expect(sql, contains('CREATE EXTENSION IF NOT EXISTS citext'));
      expect(sql, contains('CREATE TABLE IF NOT EXISTS users'));
      expect(sql, contains('email CITEXT NOT NULL UNIQUE'));
      expect(sql, contains('id UUID PRIMARY KEY DEFAULT gen_random_uuid()'));
      expect(
        sql,
        contains(
          'name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100)',
        ),
      );
      expect(sql, contains('created_at TIMESTAMPTZ NOT NULL DEFAULT now()'));
      expect(sql, contains('updated_at TIMESTAMPTZ NOT NULL DEFAULT now()'));
    });

    test('0002_projects.sql создаёт таблицу projects', () {
      final sql = File('migrations/0002_projects.sql').readAsStringSync();
      expect(sql, contains('CREATE TABLE IF NOT EXISTS projects'));
      expect(sql, contains('id UUID PRIMARY KEY DEFAULT gen_random_uuid()'));
      expect(
        sql,
        contains(
          r"key TEXT NOT NULL UNIQUE CHECK (key ~ '^[A-Z][A-Z0-9]{1,9}$')",
        ),
      );
      expect(
        sql,
        contains(
          'name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100)',
        ),
      );
      expect(
        sql,
        contains(
          'owner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT',
        ),
      );
      expect(
        sql,
        contains('description TEXT CHECK (char_length(description) <= 2000)'),
      );
    });

    test('0003_project_members.sql создаёт project_members и индексы', () {
      final sql = File(
        'migrations/0003_project_members.sql',
      ).readAsStringSync();
      expect(sql, contains('CREATE TABLE IF NOT EXISTS project_members'));
      expect(sql, contains('REFERENCES projects(id) ON DELETE CASCADE'));
      expect(sql, contains('REFERENCES users(id) ON DELETE CASCADE'));
      expect(
        sql,
        contains(
          "role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member'))",
        ),
      );
      expect(sql, contains('PRIMARY KEY (project_id, user_id)'));
      expect(
        sql,
        contains(
          'CREATE INDEX IF NOT EXISTS idx_project_members_user_id '
          'ON project_members (user_id)',
        ),
      );
      // Проверка уникальности owner-индекса: уникален и частичный
      // (только для одного владельца проекта).
      expect(
        sql,
        contains('CREATE UNIQUE INDEX IF NOT EXISTS uq_project_members_owner'),
      );
      expect(sql, contains("WHERE role = 'owner'"));
    });

    test('0004_task_enums.sql создаёт enum-типы этапа 2', () {
      final sql = File('migrations/0004_task_enums.sql').readAsStringSync();
      expect(
        sql,
        contains("CREATE TYPE task_kind AS ENUM ('epic', 'task', 'subtask')"),
      );
      expect(
        sql,
        contains(
          'CREATE TYPE task_priority AS ENUM '
          "('low', 'medium', 'high', 'critical')",
        ),
      );
      expect(
        sql,
        contains("CREATE TYPE user_role AS ENUM ('owner', 'member')"),
      );
    });

    test(
      '0005_task_types_statuses.sql создаёт справочники и базовые значения',
      () {
        final sql = File(
          'migrations/0005_task_types_statuses.sql',
        ).readAsStringSync();
        expect(sql, contains('CREATE TABLE IF NOT EXISTS task_types'));
        expect(sql, contains('CREATE TABLE IF NOT EXISTS statuses'));
        expect(sql, contains('REFERENCES projects(id) ON DELETE CASCADE'));
        expect(
          sql,
          contains(
            'CONSTRAINT uq_task_types_project_name '
            'UNIQUE (project_id, name)',
          ),
        );
        expect(
          sql,
          contains(
            'CONSTRAINT uq_statuses_project_name '
            'UNIQUE (project_id, name)',
          ),
        );
        expect(
          sql,
          contains(
            'CONSTRAINT uq_statuses_project_position '
            'UNIQUE (project_id, position)',
          ),
        );
        expect(
          sql,
          contains(
            'CONSTRAINT uq_statuses_id_project '
            'UNIQUE (id, project_id)',
          ),
        );
        expect(sql, contains('is_default BOOLEAN NOT NULL DEFAULT false'));
        expect(
          sql,
          contains(
            'CREATE UNIQUE INDEX IF NOT EXISTS uq_statuses_project_default',
          ),
        );
        // Базовые типы и статусы: есть и backfill, и триггер для новых проектов.
        expect(sql, contains("('bug'), ('feature'), ('custom')"));
        expect(sql, contains("('To Do', 0, true)"));
        expect(sql, contains("('In Progress', 1, false)"));
        expect(sql, contains("('Done', 2, false)"));
        expect(sql, contains('CREATE TRIGGER trg_projects_seed_task_defaults'));
        expect(sql, contains('AFTER INSERT ON projects'));
      },
    );

    test('0006_tasks.sql создаёт таблицу задач, индексы и иерархию', () {
      final sql = File('migrations/0006_tasks.sql').readAsStringSync();
      expect(sql, contains('CREATE TABLE IF NOT EXISTS tasks'));
      expect(sql, contains('project_id UUID NOT NULL REFERENCES projects(id)'));
      expect(sql, contains('number INTEGER NOT NULL CHECK (number >= 1)'));
      expect(sql, contains('kind task_kind NOT NULL DEFAULT \'task\''));
      expect(sql, contains('type_id UUID NOT NULL REFERENCES task_types(id)'));
      expect(sql, contains('status_id UUID NOT NULL REFERENCES statuses(id)'));
      expect(
        sql,
        contains('priority task_priority NOT NULL DEFAULT \'medium\''),
      );
      expect(sql, contains('assignee_id UUID REFERENCES users(id)'));
      expect(sql, contains('reporter_id UUID NOT NULL REFERENCES users(id)'));
      expect(sql, contains('parent_id UUID REFERENCES tasks(id)'));
      expect(sql, contains('due_date DATE'));
      // Уникальность номера в проекте.
      expect(
        sql,
        contains(
          'CONSTRAINT uq_tasks_project_number UNIQUE (project_id, number)',
        ),
      );
      // Иерархия: CHECK + триггеры.
      expect(sql, contains('CONSTRAINT chk_tasks_epic_without_parent'));
      expect(sql, contains('CONSTRAINT chk_tasks_subtask_with_parent'));
      expect(sql, contains('CREATE TRIGGER trg_tasks_check_hierarchy'));
      expect(
        sql,
        contains('BEFORE INSERT OR UPDATE OF parent_id, kind, project_id'),
      );
      expect(sql, contains('CREATE TRIGGER trg_tasks_recheck_children'));
      // Составные FK: тип и статус — из того же проекта, удаление запрещено.
      expect(sql, contains('CONSTRAINT fk_tasks_type_same_project'));
      expect(sql, contains('CONSTRAINT fk_tasks_status_same_project'));
      expect(
        sql,
        contains(
          'REFERENCES task_types (id, project_id) '
          'ON DELETE RESTRICT',
        ),
      );
      expect(
        sql,
        contains(
          'REFERENCES statuses (id, project_id) '
          'ON DELETE RESTRICT',
        ),
      );
      // Индексы по project_id/status_id/assignee_id/parent_id.
      expect(
        sql,
        contains(
          'CREATE INDEX IF NOT EXISTS idx_tasks_project_id '
          'ON tasks (project_id)',
        ),
      );
      expect(
        sql,
        contains(
          'CREATE INDEX IF NOT EXISTS idx_tasks_status_id '
          'ON tasks (status_id)',
        ),
      );
      expect(
        sql,
        contains(
          'CREATE INDEX IF NOT EXISTS idx_tasks_assignee_id '
          'ON tasks (assignee_id)',
        ),
      );
      expect(
        sql,
        contains(
          'CREATE INDEX IF NOT EXISTS idx_tasks_parent_id '
          'ON tasks (parent_id)',
        ),
      );
    });

    test('нет DROP и TRUNCATE в миграциях', () {
      for (final name in migrations) {
        final sql = File('migrations/$name').readAsStringSync();
        expect(
          sql,
          isNot(contains('DROP')),
          reason: 'файл $name не должен содержать DROP',
        );
        expect(
          sql,
          isNot(contains('TRUNCATE')),
          reason: 'файл $name не должен содержать TRUNCATE',
        );
      }
    });
  });
}
