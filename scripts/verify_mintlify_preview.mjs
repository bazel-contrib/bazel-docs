#!/usr/bin/env node
/**
 * Visual verification for bazel Mintlify preview PRs.
 *
 * Usage (from bazel-docs repo root):
 *   node scripts/verify_mintlify_preview.mjs <pr_number> --path <page_path> [--path ...]
 *   node scripts/verify_mintlify_preview.mjs <pr_number> --checks-file checks.json
 *
 * Preview root often 404s; always pass specific page paths from the issue repro
 * or the fix-type table in agent-skills/bazel-docs-migration-manager/reference.md.
 *
 * Optional checks file (create per PR locally; do not commit PR-specific files):
 * {
 *   "pages": [
 *     {
 *       "path": "/configure/attributes",
 *       "name": "configure-attributes",
 *       "checks": [
 *         { "selector": "table tr", "minCount": 1 },
 *         { "selector": "pre, code", "mustNotContain": ["&lt;", "&gt;"] }
 *       ]
 *     }
 *   ]
 * }
 *
 * docs2mdx fixes may need reference doc regen before preview reflects changes.
 */
import { chromium } from 'playwright';
import { mkdir, readFile, writeFile } from 'fs/promises';
import { join } from 'path';

function usage() {
  console.error(`Usage:
  node scripts/verify_mintlify_preview.mjs <pr_number> --path <page_path> [--path ...]
  node scripts/verify_mintlify_preview.mjs <pr_number> --checks-file <checks.json>

Examples:
  node scripts/verify_mintlify_preview.mjs 12345 --path /configure/attributes
  node scripts/verify_mintlify_preview.mjs 12345 --path /reference/be/common-definitions#common-attributes
  node scripts/verify_mintlify_preview.mjs 12345 --checks-file /tmp/pr-12345-checks.json`);
}

const args = process.argv.slice(2);
const pr = args[0];
if (!pr || pr.startsWith('-')) {
  usage();
  process.exit(1);
}

/** @type {{ path: string, name?: string, checks?: Array<Record<string, unknown>> }[]} */
let pages = [];
let checksFile = null;

for (let i = 1; i < args.length; i++) {
  const arg = args[i];
  if (arg === '--path') {
    const path = args[++i];
    if (!path) {
      console.error('ERROR: --path requires a value');
      process.exit(1);
    }
    pages.push({ path });
  } else if (arg === '--checks-file') {
    checksFile = args[++i];
    if (!checksFile) {
      console.error('ERROR: --checks-file requires a value');
      process.exit(1);
    }
  } else {
    console.error(`ERROR: unknown argument: ${arg}`);
    usage();
    process.exit(1);
  }
}

if (checksFile) {
  const raw = JSON.parse(await readFile(checksFile, 'utf8'));
  pages = raw.pages ?? raw;
  if (!Array.isArray(pages) || pages.length === 0) {
    console.error('ERROR: checks file must contain a non-empty "pages" array');
    process.exit(1);
  }
}

if (pages.length === 0) {
  console.error('ERROR: provide at least one --path or a --checks-file');
  usage();
  process.exit(1);
}

const BASE = `https://bazel-pr-${pr}.mintlify.app`;
const OUT = `/tmp/bazel-docs-screenshots/pr-${pr}`;
await mkdir(OUT, { recursive: true });

function slugFromPath(path) {
  return path.replace(/^#/, '').split('#')[0].replace(/\//g, '-').replace(/^-/, '') || 'root';
}

async function runChecks(page, checks) {
  const details = [];
  let ok = true;

  for (const check of checks ?? []) {
    const selector = /** @type {string} */ (check.selector);
    const name = check.name ?? selector;

    if (check.minCount != null) {
      const count = await page.locator(selector).count();
      const pass = count >= /** @type {number} */ (check.minCount);
      details.push(`${name}: count=${count} (min ${check.minCount})`);
      ok = ok && pass;
    }

    if (check.mustNotContain) {
      const texts = await page.locator(selector).allTextContents();
      const joined = texts.join('\n');
      const forbidden = /** @type {string[]} */ (check.mustNotContain);
      const found = forbidden.filter((s) => joined.includes(s));
      details.push(`${name}: forbidden=${found.length ? found.join(',') : 'none'}`);
      ok = ok && found.length === 0;
    }

    if (check.mustContain) {
      const texts = await page.locator(selector).allTextContents();
      const joined = texts.join('\n');
      const required = /** @type {string[]} */ (check.mustContain);
      const missing = required.filter((s) => !joined.includes(s));
      details.push(`${name}: missing=${missing.length ? missing.join(',') : 'none'}`);
      ok = ok && missing.length === 0;
    }

    if (check.anchorId) {
      const info = await page.evaluate((anchorId) => {
        const el = document.getElementById(anchorId);
        const heading = [...document.querySelectorAll('h1,h2,h3,h4')].find(
          (h) => h.id === anchorId || h.textContent?.includes(anchorId),
        );
        return {
          anchorId: el?.id ?? null,
          headingId: heading?.id ?? null,
          hash: location.hash,
        };
      }, /** @type {string} */ (check.anchorId));
      const pass =
        info.anchorId === check.anchorId ||
        info.headingId === check.anchorId ||
        info.hash === `#${check.anchorId}`;
      details.push(`${name}: anchor=${JSON.stringify(info)}`);
      ok = ok && pass;
    }
  }

  return { ok, detail: details.join('; ') || 'custom checks passed' };
}

async function basicSanity(page) {
  const bodyText = ((await page.locator('body').textContent()) ?? '').trim();
  const hasContent = bodyText.length > 100;
  const looksLikeError =
    /page not found|internal server error|something went wrong/i.test(bodyText);
  return {
    ok: hasContent && !looksLikeError,
    detail: `bodyLength=${bodyText.length}, errorPage=${looksLikeError}`,
  };
}

const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
const results = [];

for (const entry of pages) {
  const page = await context.newPage();
  const url = `${BASE}${entry.path}`;
  const name = entry.name ?? slugFromPath(entry.path);
  let httpOk = false;

  try {
    const resp = await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
    httpOk = resp != null && resp.status() === 200;
  } catch (e) {
    results.push({
      name,
      path: entry.path,
      ok: false,
      httpOk: false,
      detail: `navigation failed: ${e.message}`,
    });
    await page.close();
    continue;
  }

  const shot = join(OUT, `${name}.png`);
  await page.screenshot({ path: shot, fullPage: true });

  const sanity = await basicSanity(page);
  let custom = { ok: true, detail: 'no custom checks' };
  if (entry.checks?.length) {
    custom = await runChecks(page, entry.checks);
  }

  results.push({
    name,
    path: entry.path,
    screenshot: shot,
    httpOk,
    ok: httpOk && sanity.ok && custom.ok,
    detail: [sanity.detail, custom.detail].filter(Boolean).join('; '),
  });
  await page.close();
}

await browser.close();

const report = {
  pr,
  base: BASE,
  timestamp: new Date().toISOString(),
  results,
  passed: results.filter((r) => r.ok).length,
  total: results.length,
};

await writeFile(join(OUT, 'verification-report.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
process.exit(report.passed === report.total ? 0 : 1);
