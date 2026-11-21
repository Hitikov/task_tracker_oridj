-- Этап 2: справочники `task_types` и `statuses` (docs/architecture.md, раздел 7).
--
-- Обе таблицы принадлежат проекту: типы расширяемы без миграции enum,
-- статусы задают колонки Backlog/Kanban. Существующие и новые проекты
-- получают базовые значения (bug/feature/custom и To Do/In Progress/Done)
-- через backfill ниже и триггер `trg_projects_seed_task_defaults`.
--
-- `UNIQUE (id, project_id)` нужен составным внешним ключам таблицы `tasks`:
-- они гарантируют, что задача ссылается на тип/статус своего проекта.

CREATE TABLE IF NOT EXISTS task_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_task_types_project_name UNIQUE (project_id, name),
  CONSTRAINT uq_task_types_id_project UNIQUE (id, project_id)
);

CREATE TABLE IF NOT EXISTS statuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 50),
  position INTEGER NOT NULL DEFAULT 0 CHECK (position >= 0),
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_statuses_project_name UNIQUE (project_id, name),
  CONSTRAINT uq_statuses_project_position UNIQUE (project_id, position),
  CONSTRAINT uq_statuses_id_project UNIQUE (id, project_id)
);

-- Ровно один статус по умолчанию на проект.
CREATE UNIQUE INDEX IF NOT EXISTS uq_statuses_project_default
  ON statuses (project_id) WHERE is_default;

-- Типы и статусы для проектов, созданных до этой миграции.
INSERT INTO task_types (project_id, name)
SELECT p.id, v.name
  FROM projects p
  CROSS JOIN (VALUES ('bug'), ('feature'), ('custom')) AS v(name)
 WHERE NOT EXISTS (
   SELECT 1 FROM task_types t
    WHERE t.project_id = p.id AND t.name = v.name
 );

INSERT INTO statuses (project_id, name, position, is_default)
SELECT p.id, v.name, v.position, v.is_default
  FROM projects p
  CROSS JOIN (VALUES
    ('To Do', 0, true),
    ('In Progress', 1, false),
    ('Done', 2, false)
  ) AS v(name, position, is_default)
 WHERE NOT EXISTS (
   SELECT 1 FROM statuses s
    WHERE s.project_id = p.id AND s.name = v.name
 );

-- Проекты, созданные после этой миграции, получают базовые значения сразу.
CREATE OR REPLACE FUNCTION seed_project_task_defaults() RETURNS trigger AS $$
BEGIN
  INSERT INTO task_types (project_id, name)
  VALUES (NEW.id, 'bug'), (NEW.id, 'feature'), (NEW.id, 'custom')
  ON CONFLICT DO NOTHING;

  INSERT INTO statuses (project_id, name, position, is_default)
  VALUES
    (NEW.id, 'To Do', 0, true),
    (NEW.id, 'In Progress', 1, false),
    (NEW.id, 'Done', 2, false)
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_projects_seed_task_defaults
  AFTER INSERT ON projects
  FOR EACH ROW EXECUTE FUNCTION seed_project_task_defaults();
