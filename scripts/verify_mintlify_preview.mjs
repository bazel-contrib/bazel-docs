#!/usr/bin/env node
/**
 * Visual verification for bazel Mintlify preview PRs.
 *
 * Usage (from bazel-docs repo root):
 *   node scripts/verify_mintlify_preview.mjs <bazelbuild/bazel PR number>
 *
 * Preview root often 404s; checks hit specific page paths.
 * docs2mdx fixes may need reference doc regen before preview reflects changes.
 */
import { chromium } from 'playwright';
import { mkdir, writeFile } from 'fs/promises';
import { join } from 'path';

const PR = process.argv[2];
if (!PR) {
  console.error('Usage: node scripts/verify_mintlify_preview.mjs <pr_number>');
  process.exit(1);
}

const BASE = `https://bazel-pr-${PR}.mintlify.app`;
const OUT = `/tmp/bazel-docs-screenshots/pr-${PR}`;
await mkdir(OUT, { recursive: true });

const CHECKS = {
  30702: [
    {
      path: '/configure/attributes',
      name: 'configure-attributes',
      verify: async (page) => {
        const hasTable = (await page.locator('table tr').count()) > 0;
        const hasStyledRow = (await page.locator('tr').filter({ hasText: 'Command' }).count()) > 0;
        return { ok: hasTable && hasStyledRow, detail: `table rows=${await page.locator('table tr').count()}` };
      },
    },
    {
      path: '/release/rolling',
      name: 'release-rolling',
      verify: async (page) => {
        const iframe = await page.locator('iframe').count();
        return { ok: iframe > 0, detail: `iframes=${iframe}` };
      },
    },
  ],
  30704: [
    {
      path: '/reference/be/common-definitions#common-attributes',
      name: 'anchor-common-attributes',
      verify: async (page) => {
        await page.waitForTimeout(1500);
        const info = await page.evaluate(() => {
          const el = document.getElementById('common-attributes');
          const heading = [...document.querySelectorAll('h2,h3')].find((h) =>
            h.textContent.includes('Attributes common to all build rules'),
          );
          return {
            anchorId: el?.id || null,
            headingId: heading?.id || null,
            hash: location.hash,
            headingTop: heading?.getBoundingClientRect().top ?? null,
          };
        });
        const ok =
          info.anchorId === 'common-attributes' ||
          info.headingId === 'common-attributes' ||
          (info.headingTop !== null && info.headingTop >= 0 && info.headingTop < 300);
        return { ok, detail: JSON.stringify(info) };
      },
    },
  ],
  30705: [
    {
      path: '/reference/be/common-definitions#common-attributes',
      name: 'lists-aspect-hints',
      verify: async (page) => {
        await page.waitForTimeout(2000);
        const nestedUl = await page
          .locator('table')
          .filter({ hasText: 'aspect_hints' })
          .locator('ul li')
          .count();
        return { ok: nestedUl >= 2, detail: `ul li in aspect_hints area=${nestedUl}` };
      },
    },
    {
      path: '/reference/be/common-definitions#common-attributes',
      name: 'lists-tags',
      verify: async (page) => {
        const ulCount = await page
          .locator('table')
          .filter({ hasText: 'tags' })
          .first()
          .locator('ul li')
          .count();
        return { ok: ulCount >= 3, detail: `ul li in tags area=${ulCount}` };
      },
    },
    {
      path: '/reference/be/common-definitions#common-attributes-tests',
      name: 'nested-table-size',
      verify: async (page) => {
        await page.waitForTimeout(2000);
        const nested = await page.locator('table').filter({ hasText: 'size' }).locator('table').count();
        return { ok: nested >= 1, detail: `nested tables near size=${nested}` };
      },
    },
    {
      path: '/rules/lib/repo/http',
      name: 'http-repo-table',
      verify: async (page) => {
        const rows = await page.locator('table tr').count();
        return { ok: rows >= 5, detail: `table rows=${rows}` };
      },
    },
  ],
  30706: [
    {
      path: '/remote/output-directories',
      name: 'code-no-entities',
      verify: async (page) => {
        const text = (await page.locator('pre, code').first().textContent().catch(() => '')) || '';
        const hasEntities = text.includes('&lt;') || text.includes('&gt;');
        return { ok: !hasEntities && text.length > 0, detail: `entities=${hasEntities}` };
      },
    },
  ],
  30708: [
    {
      path: '/reference/command-line-reference',
      name: 'flag-links',
      verify: async (page) => {
        await page.waitForTimeout(2000);
        const flagLinks = await page.locator('a[href*="flag--"]').count();
        const anchors = await page.locator('a[id*="flag--"]').count();
        return { ok: flagLinks >= 5 || anchors >= 5, detail: `flag links=${flagLinks}, anchors=${anchors}` };
      },
    },
  ],
};

const checks = CHECKS[PR];
if (!checks) {
  console.error(`No checks defined for PR ${PR}. Add a CHECKS entry in scripts/verify_mintlify_preview.mjs`);
  process.exit(1);
}

const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
const results = [];

for (const check of checks) {
  const page = await context.newPage();
  const url = `${BASE}${check.path}`;
  let httpOk = false;
  try {
    const resp = await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
    httpOk = resp && resp.status() === 200;
  } catch (e) {
    results.push({ name: check.name, path: check.path, ok: false, httpOk: false, detail: `navigation failed: ${e.message}` });
    await page.close();
    continue;
  }

  const shot = join(OUT, `${check.name}.png`);
  await page.screenshot({ path: shot, fullPage: true });

  let verify = { ok: false, detail: 'no verifier' };
  try {
    verify = await check.verify(page);
  } catch (e) {
    verify = { ok: false, detail: `verify error: ${e.message}` };
  }

  results.push({
    name: check.name,
    path: check.path,
    screenshot: shot,
    httpOk,
    ok: httpOk && verify.ok,
    detail: verify.detail,
  });
  await page.close();
}

await browser.close();

const report = {
  pr: PR,
  base: BASE,
  timestamp: new Date().toISOString(),
  results,
  passed: results.filter((r) => r.ok).length,
  total: results.length,
};

await writeFile(join(OUT, 'verification-report.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
process.exit(report.passed === report.total ? 0 : 1);
