-- Этап 2: enum-типы для задач и ролей (docs/architecture.md, разделы 6-7).
--
-- `task_kind` — структурная роль задачи в иерархии (epic/task/subtask).
-- `task_priority` — приоритет задачи.
-- `user_role` — роли пользователя; создаётся на этапе 2, но применяется
-- позже (этап 4): колонка `project_members.role` остаётся TEXT с CHECK,
-- потому что перевод типов потребовал бы удаления существующего
-- ограничения, а миграции этапов 0-2 двигаются только вперёд.

CREATE TYPE task_kind AS ENUM ('epic', 'task', 'subtask');

CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high', 'critical');

CREATE TYPE user_role AS ENUM ('owner', 'member');
