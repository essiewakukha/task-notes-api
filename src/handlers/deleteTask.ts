import { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { DeleteCommand, GetCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, publishTaskEvent, jsonResponse } from "../lib/aws";
import { Task } from "../lib/types";

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const id = event.pathParameters?.id;
  if (!id) {
    return jsonResponse(400, { message: "task id is required" });
  }

  const existing = await ddb.send(
    new GetCommand({ TableName: process.env.TABLE_NAME, Key: { id } })
  );

  if (!existing.Item) {
    return jsonResponse(404, { message: "task not found" });
  }

  await ddb.send(
    new DeleteCommand({ TableName: process.env.TABLE_NAME, Key: { id } })
  );

  await publishTaskEvent({ type: "TASK_DELETED", task: existing.Item as Task });

  return jsonResponse(204, {});
};