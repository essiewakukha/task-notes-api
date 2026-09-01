import { buildSlackMessage } from "../handlers/notify";
import { Task, TaskEvent } from "../lib/types";

const baseTask: Task = {
  id: "abc-123",
  title: "Write the interview prep doc",
  status: "pending",
  createdAt: "2026-08-01T00:00:00.000Z",
  updatedAt: "2026-08-01T00:00:00.000Z",
};

describe("buildSlackMessage", () => {
  it("formats a TASK_CREATED event", () => {
    const event: TaskEvent = { type: "TASK_CREATED", task: baseTask };
    expect(buildSlackMessage(event)).toContain("New task created");
    expect(buildSlackMessage(event)).toContain(baseTask.title);
  });

  it("includes status when a task is updated", () => {
    const task: Task = { ...baseTask, status: "in_progress" };
    const event: TaskEvent = { type: "TASK_UPDATED", task };
    expect(buildSlackMessage(event)).toContain("in_progress");
  });

  it("formats a TASK_COMPLETED event", () => {
    const task: Task = { ...baseTask, status: "completed" };
    const event: TaskEvent = { type: "TASK_COMPLETED", task };
    expect(buildSlackMessage(event)).toContain("completed");
  });
});