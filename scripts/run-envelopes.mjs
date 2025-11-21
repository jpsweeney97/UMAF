// scripts/run-envelopes.mjs
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "..");

// PERFORMANCE RATCHET: Fail if batch takes longer than this (ms)
const MAX_DURATION_MS = 2500;

function findCli() {
  if (process.env.UMAF_CLI) {
    const p = process.env.UMAF_CLI;
    if (fs.existsSync(p)) return p;
    console.warn(`UMAF_CLI is set to ${p}, but it does not exist on disk.`);
  }

  const candidates = [
    path.join(projectRoot, ".build", "release", "umaf"),
    path.join(projectRoot, ".build", "debug", "umaf"),
  ];

  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }

  throw new Error(`Could not find umaf CLI. Set UMAF_CLI or run swift build -c release.`);
}

async function main() {
  const cliPath = findCli();
  const crucibleDir = path.join(projectRoot, "crucible");
  const outDir = path.join(projectRoot, ".build", "envelopes");

  if (fs.existsSync(outDir)) {
    fs.rmSync(outDir, { recursive: true, force: true });
  }
  fs.mkdirSync(outDir, { recursive: true });

  console.log(`🚀 Batch processing: ${crucibleDir} -> ${outDir}`);
  
  const startTime = performance.now();

  const child = spawn(cliPath, [
    "--input-dir", crucibleDir,
    "--output-dir", outDir,
    "--json"
  ], {
    stdio: "inherit"
  });

  await new Promise((resolve, reject) => {
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`CLI exited with code ${code}`));
    });
    child.on("error", reject);
  });

  const duration = performance.now() - startTime;
  console.log(`✅ Batch generation complete in ${duration.toFixed(2)}ms`);

  if (duration > MAX_DURATION_MS) {
    console.error(`❌ PERFORMANCE REGRESSION: Batch took ${duration.toFixed(2)}ms (limit: ${MAX_DURATION_MS}ms)`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("❌ Build validation failed:", err);
  process.exit(1);
});
