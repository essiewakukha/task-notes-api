import { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { PutCommand } from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "crypto";
import { ddb, publishTaskEvent, jsonResponse } from "../lib/aws";
import { Task } from "../lib/types";

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const body = event.body ? JSON.parse(event.body) : {};

  if (!body.title || typeof body.title !== "string") {
    return jsonResponse(400, { message: "title is required" });
  }

  const now = new Date().toISOString();
  const task: Task = {
    id: randomUUID(),
    title: body.title,
    notes: body.notes ?? "",
    status: "pending",
    createdAt: now,
    updatedAt: now,
  };

  await ddb.send(
    new PutCommand({
      TableName: process.env.TABLE_NAME,
      Item: task,
    })
  );

  // Publish after the write succeeds - notifications are a side effect,
  // not the source of truth. If this throws, the task still exists;
  // API Gateway will surface a 500 and the client can retry safely
  // since PutCommand above is idempotent on task.id.
  await publishTaskEvent({ type: "TASK_CREATED", task });

  return jsonResponse(201, task);
};