import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";
import { SNSClient, PublishCommand } from "@aws-sdk/client-sns";
import { TaskEvent } from "./types";

// Reused across invocations on a warm Lambda - avoids re-creating a client
// (and re-negotiating TLS) on every single request.
const ddbClient = new DynamoDBClient({});
export const ddb = DynamoDBDocumentClient.from(ddbClient);

const sns = new SNSClient({});

export async function publishTaskEvent(event: TaskEvent): Promise<void> {
  const topicArn = process.env.TASK_TOPIC_ARN;
  if (!topicArn) {
    // Fail loudly in dev rather than silently dropping events
    throw new Error("TASK_TOPIC_ARN is not set");
  }

  await sns.send(
    new PublishCommand({
      TopicArn: topicArn,
      Message: JSON.stringify(event),
      MessageAttributes: {
        eventType: { DataType: "String", StringValue: event.type },
      },
    })
  );
}

export function jsonResponse(statusCode: number, body: unknown) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}