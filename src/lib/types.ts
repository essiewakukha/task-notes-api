export type TaskStatus = "pending" | "in_progress" | "completed";

export interface Task {
  id: string;
  title: string;
  notes?: string;
  status: TaskStatus;
  createdAt: string;
  updatedAt: string;
}

export type TaskEventType =
  | "TASK_CREATED"
  | "TASK_UPDATED"
  | "TASK_COMPLETED"
  | "TASK_DELETED";

export interface TaskEvent {
  type: TaskEventType;
  task: Task;
}