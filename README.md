# Task Notes API

A small serverless task/notes API built to practice (and demonstrate) the exact
stack used in senior cloud engineering roles: API Gateway, Lambda, DynamoDB,
event-driven decoupling with SNS/SQS, CloudWatch alerting, Terraform, and a
GitHub Actions CI/CD pipeline.

## Architecture

```
Client -> API Gateway (HTTP API) -> CRUD Lambda -> DynamoDB
                                          |
                                          v
                                    SNS topic (task-events)
                                          |
                                          v
                              SQS queue (+ DLQ, 3 retries)
                                          |
                                          v
                                    Notify Lambda -> Slack

CloudWatch Alarms (Lambda errors, DLQ depth, API 5xx)
    -> SNS topic (infra-alerts) -> Alert Lambda -> Slack
```

**Request path (synchronous):** a client calls the HTTP API, API Gateway
invokes the matching Lambda with a proxy integration, the Lambda reads/writes
DynamoDB, and the response goes straight back to the client.

**Notification path (asynchronous):** after a successful write, the same
Lambda publishes an event to an SNS topic. It does not wait for that
notification to be delivered anywhere - the API response goes back to the
client immediately. SNS fans the event out to an SQS queue, which triggers a
separate Notify Lambda that posts a message to Slack. If Slack is slow or
down, SQS retries automatically (up to 3 times) before the message lands in
a dead-letter queue - the API and the DynamoDB write are never affected.

**Alerting path:** three CloudWatch alarms (Notify Lambda errors, messages
landing in the DLQ, API Gateway 5xx rate) publish to a *separate* SNS topic
that also forwards to Slack, through its own Lambda. This is deliberately
kept apart from the task-notification path - a broken Slack integration for
"task completed" pings shouldn't take down infra alerting, and vice versa.

## Why these choices (talking points for later)

- **SNS -> SQS instead of Lambda calling Slack directly.** Decoupling means
  a slow or failing webhook can never slow down or fail the actual API
  request. SQS's built-in retry + DLQ replaces custom retry logic entirely.
- **SNS in front of SQS, not SQS alone.** The CRUD Lambda publishes once to
  SNS. Adding a second subscriber later (e.g. an analytics pipeline) means
  subscribing another queue to the topic - zero changes to the CRUD Lambda.
- **HTTP API (v2) over REST API (v1).** Cheaper, lower latency, and this
  project only needs simple Lambda proxy integrations - none of the REST
  API's extra features (request validation, usage plans) are needed here.
- **DynamoDB with a single table, on-demand billing.** Traffic is small and
  unpredictable, so PAY_PER_REQUEST avoids managing provisioned capacity.
  `listTasks` uses a Scan, which is explicitly called out in the code as
  something you'd replace with a Query + GSI once the table grows past a
  few thousand items - worth mentioning proactively in an interview, since
  it shows you know the limitation rather than having missed it.
- **Three separate CloudWatch alarms, one alerts channel.** Lambda errors,
  DLQ depth, and API 5xx rate are different failure signals monitored
  independently, but they all route to the same Slack channel via one
  Lambda - matches the JD's "optimising alerting strategy" bullet directly.
- **Per-handler Lambda bundles, not one monolith Lambda.** Each handler is
  bundled separately by esbuild and zipped independently by Terraform. This
  keeps each function's package small (faster cold starts) and its IAM
  permissions scoped to exactly what that one handler needs.

## Repo layout

```
terraform/     All infrastructure as code (API Gateway, Lambda, DynamoDB,
               SNS, SQS, IAM, CloudWatch alarms)
src/handlers/  One TypeScript file per Lambda function
src/lib/       Shared DynamoDB/SNS clients and types
src/test/      Unit tests (Jest)
src/build.js   esbuild script - bundles each handler into src/dist/<name>/
.github/workflows/deploy.yml   CI: lint, test, build, terraform plan/apply
```

## Running it locally

```bash
cd src
npm install
npm run lint    # tsc --noEmit
npm test        # jest
npm run build   # bundles each handler into src/dist/
```

## Deploying it yourself

You'll need an AWS account and Terraform >= 1.6.

```bash
cd src && npm install && npm run build
cd ../terraform
terraform init
terraform plan  -var="slack_webhook_url=https://hooks.slack.com/services/..."
terraform apply -var="slack_webhook_url=https://hooks.slack.com/services/..."
```

Terraform will print the API's base URL as an output. Try it:

```bash
curl -X POST "$API_URL/tasks" -H "Content-Type: application/json" \
  -d '{"title": "Prep for the Sigma Digital interview"}'

curl "$API_URL/tasks"
```

### Setting up the CI/CD pipeline

The GitHub Actions workflow deploys on every push to `main`. It authenticates
to AWS via OIDC federation - no long-lived AWS access keys are ever stored in
GitHub. `terraform/oidc.tf` provisions this:

- An **OIDC identity provider** in IAM that trusts GitHub's token issuer
  (`token.actions.githubusercontent.com`).
- An **IAM role** (`task-notes-api-github-actions-deploy`) that only this
  specific repo can assume, enforced via the `sub` claim on the OIDC token -
  not a wildcard, not any repo in the org.
- A **permissions policy** scoped to just the AWS services this project
  touches (Lambda, API Gateway, DynamoDB, SNS, SQS, CloudWatch, and IAM
  actions limited to roles prefixed `task-notes-api-*`) - not
  `AdministratorAccess`.

To wire this up yourself:

1. Set `github_repo` in `terraform/oidc.tf` to your actual `owner/repo`.
2. `terraform apply` locally once (you'll need your own AWS credentials
   configured for this one-time bootstrap step).
3. Copy the `github_actions_deploy_role_arn` output.
4. In your repo: **Settings -> Secrets and variables -> Actions**, add
   `AWS_DEPLOY_ROLE_ARN` (the ARN from step 3) and `SLACK_WEBHOOK_URL`.
5. The workflow also needs `permissions: id-token: write` set at the top of
   `deploy.yml` - without it, GitHub never issues the OIDC token in the
   first place, regardless of how the AWS side is configured.

Without these secrets the `build-and-test` job still runs on every PR (lint,
test, build) - only the `terraform` job needs AWS access.

## What I'd extend next

- A GSI on `status` so `listTasks?status=completed` uses Query instead of Scan
- API key or JWT authorizer on API Gateway (currently open)
- A second SQS subscriber on the `task-events` topic for basic analytics
- X-Ray tracing across the Lambda -> SNS -> SQS -> Lambda hop to see the
  full async latency, not just each piece in isolation