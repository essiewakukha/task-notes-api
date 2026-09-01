import { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { ScanCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, jsonResponse } from "../lib/aws";

// A Scan is fine here: this is a small demo table. In a real production
// table at scale you'd add a GSI (e.g. on status) and Query instead,
// since Scan reads every item and doesn't scale past a few thousand rows.
export const handler: APIGatewayProxyHandlerV2 = async () => {
  const result = await ddb.send(
    new ScanCommand({ TableName: process.env.TABLE_NAME })
  );

  return jsonResponse(200, result.Items ?? []);
};