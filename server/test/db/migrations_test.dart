import 'dart:io';

import 'package:arij_server/src/db/migration_runner.dart';
import 'package:test/test.dart';

void main() {
  group('миграции этапа 1 (server/migrations)', () {
    test('пронумерованы без пропусков и дублей', () {
      expect(discoverMigrations('migrations'), [
        '0000_schema_migrations.sql',
        '0001_users.sql',
        '0002_projects.sql',
        '0003_project_members.sql',
      ]);
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

    test('нет DROP и TRUNCATE в миграциях', () {
      for (final name in <String>[
        '0000_schema_migrations.sql',
        '0001_users.sql',
        '0002_projects.sql',
        '0003_project_members.sql',
      ]) {
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
