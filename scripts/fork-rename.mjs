#!/usr/bin/env node
// Re-apply the fork's name transform after pulling upstream changes: the
// upstream project name -> sjujperpowers in file contents, file names, and
// directory names. Idempotent, and it leaves upstream attribution URLs
// (github.com/obra/<upstream>/...) alone. The upstream name is assembled at
// runtime so this file never contains it and cannot rewrite itself.
//
// Usage: node scripts/fork-rename.mjs   (from the repo root)
import fs from "node:fs";
import path from "node:path";

const up = ["super", "powers"].join("");
const fork = "sjujperpowers";
const cap = s => s[0].toUpperCase() + s.slice(1);
const pairs = [[up, fork], [cap(up), cap(fork)], [up.toUpperCase(), fork.toUpperCase()]];
const keep = `obra/${up}`;
const skip = new Set([".jj", ".git", "node_modules", ".workspaces"]);

const paths = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    if (skip.has(e.name)) continue;
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    paths.push(p);
  }
})(".");

let rewritten = 0;
for (const p of paths) {
  if (!fs.statSync(p).isFile()) continue;
  const buf = fs.readFileSync(p);
  if (buf.includes(0)) continue; // binary
  const s = buf.toString("utf8");
  const t = s.split(keep).map(seg => pairs.reduce((acc, [a, b]) => acc.replaceAll(a, b), seg)).join(keep);
  if (t !== s) { fs.writeFileSync(p, t); rewritten++; }
}

const renameBase = b => pairs.reduce((acc, [a, c]) => acc.replaceAll(a, c), b);
let moved = 0;
for (const p of paths.filter(p => renameBase(path.basename(p)) !== path.basename(p)).sort((a, b) => b.length - a.length)) {
  fs.renameSync(p, path.join(path.dirname(p), renameBase(path.basename(p))));
  moved++;
}
console.log(`fork-rename: rewrote ${rewritten} files, moved ${moved} paths`);
