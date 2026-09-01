import { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { GetCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, publishTaskEvent, jsonResponse } from "../lib/aws";
import { Task, TaskStatus } from "../lib/types";

const VALID_STATUSES: TaskStatus[] = ["pending", "in_progress", "completed"];

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const id = event.pathParameters?.id;
  if (!id) {
    return jsonResponse(400, { message: "task id is required" });
  }

  const body = event.body ? JSON.parse(event.body) : {};
  if (body.status && !VALID_STATUSES.includes(body.status)) {
    return jsonResponse(400, { message: `status must be one of ${VALID_STATUSES.join(", ")}` });
  }

  const existing = await ddb.send(
    new GetCommand({ TableName: process.env.TABLE_NAME, Key: { id } })
  );

  if (!existing.Item) {
    return jsonResponse(404, { message: "task not found" });
  }

  const current = existing.Item as Task;
  const updated: Task = {
    ...current,
    title: body.title ?? current.title,
    notes: body.notes ?? current.notes,
    status: body.status ?? current.status,
    updatedAt: new Date().toISOString(),
  };

  await ddb.send(
    new PutCommand({ TableName: process.env.TABLE_NAME, Item: updated })
  );

  const justCompleted = current.status !== "completed" && updated.status === "completed";
  await publishTaskEvent({
    type: justCompleted ? "TASK_COMPLETED" : "TASK_UPDATED",
    task: updated,
  });

  return jsonResponse(200, updated);
};