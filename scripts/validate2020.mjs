// validate2020.mjs
import fs from "fs";
import path from "path";
import { glob } from "glob";

import AjvDraft7 from "ajv/dist/2019.js"; // Works for 2019 AND 07
import AjvDraft2019 from "ajv/dist/2019.js";
import AjvDraft2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

// ----------------------------------
// Parse CLI args
// ----------------------------------
const args = process.argv.slice(2);
let schemaPath = "schema.json";
let dataPattern = "data.json";
let strictMode = false;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--schema" && args[i + 1]) {
    schemaPath = args[i + 1];
    i++;
  } else if (args[i] === "--data" && args[i + 1]) {
    dataPattern = args[i + 1];
    i++;
  } else if (args[i] === "--strict") {
    strictMode = true;
  }
}

// ----------------------------------
// Load schema
// ----------------------------------
if (!fs.existsSync(schemaPath)) {
  console.error(`Schema not found: ${schemaPath}`);
  process.exit(1);
}

const rawSchema = fs.readFileSync(schemaPath, "utf8");
const schema = JSON.parse(rawSchema);

// ----------------------------------
// Auto-detect $schema draft
// ----------------------------------
function detectDraft(schema) {
  const uri = schema.$schema || "";
  if (uri.includes("2020-12")) return "draft2020";
  if (uri.includes("2019-09")) return "draft2019";
  if (uri.includes("draft-07")) return "draft7";
  return "draft2020"; // default safest path
}

const draft = detectDraft(schema);
console.log(`Detected schema draft: ${draft}`);

// ----------------------------------
// Choose appropriate Ajv instance
// ----------------------------------
let ajv;
const commonOpts = {
  strict: !!strictMode,
  allErrors: true,
};

if (draft === "draft2020") {
  ajv = new AjvDraft2020(commonOpts);
} else if (draft === "draft2019") {
  ajv = new AjvDraft2019(commonOpts);
} else if (draft === "draft7") {
  ajv = new AjvDraft7(commonOpts);
}

addFormats(ajv);

// ----------------------------------
// Compile
// ----------------------------------
const validate = ajv.compile(schema);

// ----------------------------------
// Expand data pattern using glob
// ----------------------------------
const files = await glob(dataPattern);

if (files.length === 0) {
  console.log(`No data files match: ${dataPattern} – schema compiled OK.`);
  process.exit(0);
}

let failures = 0;

// ----------------------------------
// Validate each file
// ----------------------------------
for (const file of files) {
  const rawData = fs.readFileSync(file, "utf8");
  const data = JSON.parse(rawData);
  const valid = validate(data);

  if (valid) {
    console.log(`✔ OK: ${file}`);
  } else {
    console.log(`✖ INVALID: ${file}`);
    console.log(JSON.stringify(validate.errors, null, 2));
    failures++;
  }
}

// ----------------------------------
// Exit
// ----------------------------------
process.exit(failures > 0 ? 1 : 0);
