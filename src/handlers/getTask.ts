import { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, jsonResponse } from "../lib/aws";

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const id = event.pathParameters?.id;
  if (!id) {
    return jsonResponse(400, { message: "task id is required" });
  }

  const result = await ddb.send(
    new GetCommand({
      TableName: process.env.TABLE_NAME,
      Key: { id },
    })
  );

  if (!result.Item) {
    return jsonResponse(404, { message: "task not found" });
  }

  return jsonResponse(200, result.Item);
};