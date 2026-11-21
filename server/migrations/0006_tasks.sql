-- Этап 2: таблица задач (docs/architecture.md, раздел 7).
--
-- Два разных измерения: `kind` (enum `task_kind` — уровень иерархии) и
-- `type_id` (справочник `task_types` — классификация bug/feature/custom).
--
-- Нумерация: `number` уникален в рамках проекта, задача получает
-- `max(number) + 1` при создании (логика на сервере); `key` в API
-- вычисляется как `<key проекта>-<number>`, например `ARIJ-1`.
--
-- Иерархия: epic без родителя, task — без родителя или внутри epic,
-- subtask — только внутри task. Часть правил закреплена CHECK-ограничениями
-- ниже, часть — триггерами `trg_tasks_check_hierarchy` и
-- `trg_tasks_recheck_children` (проверка вида родителя возможна только
-- на уровне строк).

CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  number INTEGER NOT NULL CHECK (number >= 1),
  kind task_kind NOT NULL DEFAULT 'task',
  type_id UUID NOT NULL REFERENCES task_types(id) ON DELETE RESTRICT,
  status_id UUID NOT NULL REFERENCES statuses(id) ON DELETE RESTRICT,
  title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 200),
  description TEXT CHECK (char_length(description) <= 5000),
  priority task_priority NOT NULL DEFAULT 'medium',
  assignee_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  parent_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  due_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_tasks_project_number UNIQUE (project_id, number),
  -- epic никогда не имеет родителя.
  CONSTRAINT chk_tasks_epic_without_parent
    CHECK (kind <> 'epic' OR parent_id IS NULL),
  -- subtask всегда имеет родителя; его kind проверяется триггером.
  CONSTRAINT chk_tasks_subtask_with_parent
    CHECK (kind <> 'subtask' OR parent_id IS NOT NULL),
  -- Тип и статус обязаны принадлежать тому же проекту, что и задача:
  -- составные FK ссылаются на UNIQUE (id, project_id) справочников.
  CONSTRAINT fk_tasks_type_same_project
    FOREIGN KEY (type_id, project_id)
    REFERENCES task_types (id, project_id) ON DELETE RESTRICT,
  CONSTRAINT fk_tasks_status_same_project
    FOREIGN KEY (status_id, project_id)
    REFERENCES statuses (id, project_id) ON DELETE RESTRICT
);

-- Индексы для Backlog: список задач проекта, фильтры по статусу,
-- исполнителю и родителю.
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks (project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status_id ON tasks (status_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee_id ON tasks (assignee_id);
CREATE INDEX IF NOT EXISTS idx_tasks_parent_id ON tasks (parent_id);

-- Проверка родителя при вставке и при смене kind/parent_id/project_id.
CREATE OR REPLACE FUNCTION tasks_check_hierarchy() RETURNS trigger AS $$
DECLARE
  parent_kind task_kind;
  parent_project UUID;
BEGIN
  IF NEW.parent_id IS NULL THEN
    IF NEW.kind = 'subtask' THEN
      RAISE EXCEPTION 'subtask должен иметь родителя-задачу'
        USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;

  SELECT t.kind, t.project_id
    INTO parent_kind, parent_project
    FROM tasks t
   WHERE t.id = NEW.parent_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'родительская задача % не найдена', NEW.parent_id
      USING ERRCODE = '23503';
  END IF;

  IF parent_project <> NEW.project_id THEN
    RAISE EXCEPTION 'родительская задача принадлежит другому проекту'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.kind = 'epic' THEN
    RAISE EXCEPTION 'epic не может иметь родителя'
      USING ERRCODE = '23514';
  ELSIF NEW.kind = 'task' AND parent_kind <> 'epic' THEN
    RAISE EXCEPTION 'task может быть вложен только в epic'
      USING ERRCODE = '23514';
  ELSIF NEW.kind = 'subtask' AND parent_kind <> 'task' THEN
    RAISE EXCEPTION 'subtask может быть вложен только в task'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tasks_check_hierarchy
  BEFORE INSERT OR UPDATE OF parent_id, kind, project_id ON tasks
  FOR EACH ROW EXECUTE FUNCTION tasks_check_hierarchy();

-- Смена kind родителя не должна ломать уже созданных детей:
-- у epic дети только task, у task — только subtask.
CREATE OR REPLACE FUNCTION tasks_recheck_children() RETURNS trigger AS $$
DECLARE
  child RECORD;
BEGIN
  FOR child IN SELECT id, kind FROM tasks WHERE parent_id = NEW.id LOOP
    IF NEW.kind = 'epic' AND child.kind = 'task' THEN
      CONTINUE;
    END IF;
    IF NEW.kind = 'task' AND child.kind = 'subtask' THEN
      CONTINUE;
    END IF;
    RAISE EXCEPTION
      'смена kind на % нарушает иерархию: задача % имеет kind %',
      NEW.kind, child.id, child.kind
      USING ERRCODE = '23514';
  END LOOP;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tasks_recheck_children
  AFTER UPDATE OF kind ON tasks
  FOR EACH ROW EXECUTE FUNCTION tasks_recheck_children();
