import { SNSHandler } from "aws-lambda";

interface CloudWatchAlarmMessage {
  AlarmName: string;
  NewStateValue: "ALARM" | "OK" | "INSUFFICIENT_DATA";
  NewStateReason: string;
}

// Separate from notify.ts on purpose: infra alerts and task-event
// notifications are different concerns with different audiences, even
// though both end up in Slack. Keeping them as separate Lambdas/topics
// means changing one alerting channel never risks the other.
export const handler: SNSHandler = async (event) => {
  const webhookUrl = process.env.SLACK_WEBHOOK_URL;

  for (const record of event.Records) {
    const alarm: CloudWatchAlarmMessage = JSON.parse(record.Sns.Message);
    const emoji = alarm.NewStateValue === "ALARM" ? "🚨" : "✅";
    const text = `${emoji} *${alarm.AlarmName}* is now ${alarm.NewStateValue}\n${alarm.NewStateReason}`;

    console.log(text);

    if (webhookUrl) {
      await fetch(webhookUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text }),
      });
    }
  }
};