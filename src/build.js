const esbuild = require("esbuild");
const path = require("path");

const handlers = [
  "createTask",
  "getTask",
  "listTasks",
  "updateTask",
  "deleteTask",
  "notify",
  "alert",
];

async function build() {
  for (const name of handlers) {
    await esbuild.build({
      entryPoints: [path.join(__dirname, "handlers", `${name}.ts`)],
      bundle: true,
      platform: "node",
      target: "node20",
      outfile: path.join(__dirname, "dist", name, "index.js"),
      external: ["@aws-sdk/*"], // provided by the Lambda Node 20 runtime
      sourcemap: false,
      minify: true,
    });
    console.log(`built ${name}`);
  }
}

build().catch((err) => {
  console.error(err);
  process.exit(1);
});