import { SQSHandler } from "aws-lambda";
import { TaskEvent } from "../lib/types";

// Exported separately so it can be unit tested without mocking SQS/fetch.
export function buildSlackMessage(taskEvent: TaskEvent): string {
  const MESSAGES: Record<TaskEvent["type"], (t: TaskEvent["task"]) => string> = {
    TASK_CREATED: (t) => `📝 New task created: *${t.title}*`,
    TASK_UPDATED: (t) => `✏️ Task updated: *${t.title}* (status: ${t.status})`,
    TASK_COMPLETED: (t) => `✅ Task completed: *${t.title}*`,
    TASK_DELETED: (t) => `🗑️ Task deleted: *${t.title}*`,
  };
  return MESSAGES[taskEvent.type](taskEvent.task);
}

// This Lambda is decoupled from the CRUD Lambdas on purpose: SNS -> SQS
// means a slow or failing Slack webhook never blocks or slows down the
// actual API request, and SQS retries + a DLQ handle transient failures
// (like a rate-limited webhook) without any custom retry logic here.
export const handler: SQSHandler = async (event) => {
  const webhookUrl = process.env.SLACK_WEBHOOK_URL;

  for (const record of event.Records) {
    const snsEnvelope = JSON.parse(record.body);
    const taskEvent: TaskEvent = JSON.parse(snsEnvelope.Message);

    const text = buildSlackMessage(taskEvent);
    console.log(text);

    if (webhookUrl) {
      const res = await fetch(webhookUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text }),
      });

      if (!res.ok) {
        // Throwing here fails the batch item, which puts it back on the
        // queue for retry (up to maxReceiveCount) before it lands in the DLQ.
        throw new Error(`Slack webhook responded with ${res.status}`);
      }
    }
  }
};