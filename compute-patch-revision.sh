#!/usr/bin/env bash


# 确保 UTF-8 locale，防止中文输出乱码（尤其是 Cloud / CI 环境）
export LC_ALL="${LC_ALL:-C.UTF-8}"
export LANG="${LANG:-C.UTF-8}"
compute_patch_revision() {
    local root="${1:?compute_patch_revision requires a root path}"

    node - "$root" <<'NODE'
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const root = process.argv[2];
const files = [
  "manifest.json",
  "patch-cli.sh",
  "patch-cli.js",
  "cli-translations.json",
  "bun-binary-io.js",
  "compute-patch-revision.sh",
  "hooks/session-start",
  "hooks/notification",
  "hooks/auto-repatch.sh",
  "hooks/auto-update.sh",
  "lib/common.sh",
];
const hash = crypto.createHash("sha256");

for (const file of files) {
  const target = path.join(root, file);
  if (!fs.existsSync(target)) continue;
  hash.update(file);
  hash.update("\0");
  hash.update(fs.readFileSync(target));
  hash.update("\0");
}

process.stdout.write(hash.digest("hex").slice(0, 16));
NODE
}
