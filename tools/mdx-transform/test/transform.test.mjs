import test from 'node:test';
import assert from 'node:assert/strict';

import {transformContent} from '../transform.mjs';

const stripFrontmatter = (content) => content.replace(/^---[\s\S]*?---\n\n/, '');

test('compare callout preserves inline markup', () => {
  const input = `# Title\n\n<p><span class="compare-better">Better —</span> Keep <code>foo</code> and <a href="https://example.com">link</a>.</p>`;
  const output = stripFrontmatter(transformContent(input));

  assert.ok(output.includes('<Callout type="success" title="Better">'));
  assert.ok(output.includes('`foo`'));
  assert.ok(output.includes('[link](https://example.com)'));
  assert.ok(output.includes('</Callout>'));
});

test('compare list items retain trailing content', () => {
  const input = `# Title\n\n<ul><li><span class="compare-worse">Worse</span> <em>still works</em></li></ul>`;
  const output = stripFrontmatter(transformContent(input));

  assert.ok(output.includes('- ⚠️ Worse: '));
  assert.ok(output.includes('*still works*'));
});

test('braces are readable and escaped for MDX', () => {
  const input = '# Title\n\nExample {\'cpu\': \'ppc\'}';
  const output = stripFrontmatter(transformContent(input));

  assert.ok(output.includes("Example \\{'cpu': 'ppc'\\}"));
});
