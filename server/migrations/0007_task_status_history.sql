-- Этап 6: история переходов статусов задач Канбан-доски.
--
-- Каждая успешная смена статуса через `PATCH /tasks/{id}/status` оставляет
-- запись: прежний статус, новый статус, инициатор и время изменения. Строка
-- привязана к задаче (каскадное удаление вместе с ней), проекту и пользователю,
-- а составные FK гарантируют, что оба статуса принадлежат проекту задачи —
-- так же, как это сделано для `tasks.status_id` в миграции 0006.

CREATE TABLE IF NOT EXISTS task_status_changes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  from_status_id UUID NOT NULL REFERENCES statuses(id) ON DELETE RESTRICT,
  to_status_id UUID NOT NULL REFERENCES statuses(id) ON DELETE RESTRICT,
  changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_task_status_changes_from_status_same_project
    FOREIGN KEY (from_status_id, project_id)
    REFERENCES statuses (id, project_id) ON DELETE RESTRICT,
  CONSTRAINT fk_task_status_changes_to_status_same_project
    FOREIGN KEY (to_status_id, project_id)
    REFERENCES statuses (id, project_id) ON DELETE RESTRICT
);

-- История читается одной задачей в хронологическом порядке.
CREATE INDEX IF NOT EXISTS idx_task_status_changes_task_changed_at
  ON task_status_changes (task_id, changed_at);
CREATE INDEX IF NOT EXISTS idx_task_status_changes_project_id
  ON task_status_changes (project_id);
CREATE INDEX IF NOT EXISTS idx_task_status_changes_changed_by
  ON task_status_changes (changed_by);
