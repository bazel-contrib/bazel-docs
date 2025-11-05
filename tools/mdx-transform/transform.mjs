#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import {fileURLToPath, pathToFileURL} from 'url';
import {unified} from 'unified';
import remarkParse from 'remark-parse';
import remarkFrontmatter from 'remark-frontmatter';
import remarkGfm from 'remark-gfm';
import remarkStringify from 'remark-stringify';
import {toHast} from 'mdast-util-to-hast';
import {toMdast} from 'hast-util-to-mdast';
import rehypeRaw from 'rehype-raw';
import {visit} from 'unist-util-visit';
import {toString} from 'mdast-util-to-string';
import {VFile} from 'vfile';
import {toText} from 'hast-util-to-text';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const remarkBase = unified()
  .use(remarkParse)
  .use(remarkFrontmatter, ['yaml'])
  .use(remarkGfm);

function escapeYaml(str) {
  return str.replace(/'/g, "''");
}

function normalizeLinkContinuations(content) {
  return content.replace(/\[([^\]]+)]\s*\((https?:\/\/[^\s)]+)\)\s*\{:[^}]*\}/g, '[$1]($2)');
}

function preprocessMdast(tree, file) {
  const metadata = [];
  let title = null;
  const retained = [];
  let encounteredHeading = false;

  for (const node of tree.children) {
    if (node.type === 'paragraph') {
      const text = toString(node).trim();
      if (!text) {
        continue;
      }
      if (text === '{% include "_buttons.html" %}' || text.startsWith('{% ') || text.includes('{% dynamic setvar')) {
        continue;
      }
    }

    if (node.type === 'html') {
      const value = node.value.trim();
      if (value === '{% include "_buttons.html" %}' || value.startsWith('{% ') || value.includes('{% dynamic setvar')) {
        continue;
      }
    }

    if (!encounteredHeading) {
      if (node.type === 'heading' && node.depth === 1 && !title) {
        title = toString(node).trim();
        encounteredHeading = true;
        continue;
      }
      if (node.type === 'paragraph') {
        const text = toString(node).trim();
        if (/^[A-Za-z0-9_-]+: /.test(text)) {
          if (!text.includes('_project.yaml') && !text.includes('_book.yaml')) {
            metadata.push(text);
          }
          continue;
        }
      }
    }
    retained.push(node);
  }

  tree.children = retained;
  const frontmatter = [];
  if (title) {
    frontmatter.push(`title: '${escapeYaml(title)}'`);
  }
  for (const line of metadata) {
    frontmatter.push(line);
  }
  if (frontmatter.length > 0) {
    file.data.frontmatter = frontmatter.join('\n');
  }
}

function stripLiquidExpressions(value) {
  if (typeof value !== 'string' || value.indexOf('{{') === -1) {
    return value;
  }
  return value.replace(/\{\{\s*['"]?([^{}'"]+?)['"]?\s*\}\}/g, (_, inner) => inner.trim());
}

function sanitizeMdast(tree) {
  visit(tree, (node) => {
    if (node.type === 'raw') {
      const value = typeof node.value === 'string' ? node.value : '';
      const cleaned = stripLiquidExpressions(
        value.replace(/\{:[^}]*\}/g, ''),
      ).replace(/<!--([\s\S]*?)-->/g, '');
      node.type = 'html';
      node.value = cleaned;
    }
    if (node.type === 'text' || node.type === 'html' || node.type === 'code' || node.type === 'inlineCode') {
      let value = node.value;
      if (typeof value === 'string') {
        value = stripLiquidExpressions(value);
        value = value
          .replace(/\{:[^}]*\}/g, '')
          .replace(/\{#[^#]*?#\}/g, '')
          .replace(/<!--([\s\S]*?)-->/g, '')
          .replace(/<([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})>/g, '$1')
          .replace(/<https?:\/\/[^>\s]+>/g, (match) => {
            const url = match.slice(1, -1);
            return `[${url}](${url})`;
          });
        if (node.type === 'code' || node.type === 'inlineCode') {
          value = value.replace(/</g, '&lt;').replace(/>/g, '&gt;');
        }
        if (node.type === 'text') {
          value = value
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/\{/g, '&#123;')
            .replace(/\}/g, '&#125;');
        }
        node.value = value;
      }
    }
  });
}

function classList(value) {
  if (!value) return [];
  if (Array.isArray(value)) {
    return value;
  }
  if (typeof value === 'string') {
    return value.split(/\s+/).filter(Boolean);
  }
  return [];
}

function convertNavTable(node) {
  const anchors = [];
  visit(node, 'element', (el) => {
    if (el.tagName === 'a' && el.properties && el.properties.href) {
      const label = toText(el).replace(/arrow_(back|forward(_ios)?)?/gi, '').trim();
      anchors.push({href: el.properties.href, label});
    }
  });
  if (anchors.length === 0) {
    return null;
  }
  const children = [];
  anchors.slice(0, 2).forEach((anchor, index) => {
    const label = index === 0 && !anchor.label.startsWith('←')
      ? `← ${anchor.label}`
      : index === 1 && !anchor.label.endsWith('→')
        ? `${anchor.label} →`
        : anchor.label;
    if (index > 0) {
      children.push({type: 'text', value: ' · '});
    }
    children.push({
      type: 'element',
      tagName: 'a',
      properties: {href: anchor.href},
      children: [{type: 'text', value: label}],
    });
  });
  return {
    type: 'element',
    tagName: 'p',
    properties: {},
    children,
  };
}

export function rehypeCustom() {
  return (tree) => {
    visit(tree, 'element', (node, index, parent) => {
      if (!parent) return;

      if (node.properties) {
        for (const key of Object.keys(node.properties)) {
          const value = node.properties[key];
          if (key === 'style') {
            delete node.properties[key];
            continue;
          }
          if (typeof value === 'string' && /[\r\n]/.test(value)) {
            const collapsed = value.replace(/\s+/g, ' ').trim();
            node.properties[key] = collapsed;
          } else if (Array.isArray(value)) {
            node.properties[key] = value.map((item) =>
              typeof item === 'string' && /[\r\n]/.test(item)
                ? item.replace(/\s+/g, ' ').trim()
                : item,
            );
          }
        }
      }

      // Normalize span icons → text arrows
      if (node.tagName === 'span') {
        const classNames = classList(node.properties?.className);
        const aria = node.properties?.ariaHidden;
        if (classNames.includes('material-icons') || aria === 'true') {
          const text = toText(node);
          if (/arrow_back/.test(text)) {
            parent.children[index] = {type: 'text', value: '←'};
            return;
          }
          if (/arrow_forward(_ios)?/.test(text)) {
            parent.children[index] = {type: 'text', value: '→'};
            return;
          }
        }
        if (node.properties && node.properties.id) {
          parent.children[index] = {
            type: 'element',
            tagName: 'a',
            properties: {id: node.properties.id},
            children: [],
          };
          return;
        }
      }

      // Navigation tables
      if (node.tagName === 'table') {
        const classes = classList(node.properties?.className);
        if (classes.includes('columns')) {
          const replacement = convertNavTable(node);
          if (replacement) {
            parent.children.splice(index, 1, replacement);
          } else {
            parent.children.splice(index, 1);
          }
          return [visit.SKIP, index];
        }
      }

      // Compare callouts
      if (node.tagName === 'p' && node.children?.length) {
        const first = node.children[0];
        if (first?.type === 'element' && first.tagName === 'span') {
          const classes = classList(first.properties?.className);
          const compare = classes.find((cls) => cls.startsWith('compare-'));
          if (compare) {
            const type = compare === 'compare-better' ? 'success' : 'warning';
            const title = toText(first).replace(/[–—-]\s*$/,'').trim() || (type === 'success' ? 'Yes' : 'No');
            const bodyNodes = node.children.slice(1);
            const bodyText = toText({type: 'element', tagName: 'div', children: bodyNodes}).trim();
            const callout = `<Callout type="${type}" title="${title}">${bodyText ? '\n' + bodyText + '\n' : ''}</Callout>`;
            parent.children[index] = {type: 'raw', value: callout};
            return [visit.SKIP, index];
          }
        }
      }

      // Compare list items
      if (node.tagName === 'li' && node.children?.length) {
        const first = node.children[0];
        if (first?.type === 'element' && first.tagName === 'span') {
          const classes = classList(first.properties?.className);
          const compare = classes.find((cls) => cls.startsWith('compare-'));
          if (compare) {
            const icon = compare === 'compare-better' ? '✅' : '⚠️';
            const label = toText(first).trim();
            const rest = node.children.slice(1);
            const restText = toText({type: 'element', tagName: 'div', children: rest}).trim();
            node.children = [{type: 'text', value: `${icon} ${label}:${restText ? ' ' + restText : ''}`}];
          }
        }
      }

      // Normalize align attr
      if (node.properties?.align && !node.properties.style) {
        node.properties.align = node.properties.align.toString();
      }

      if (node.tagName === 'img') {
        node.properties = node.properties || {};
        if (node.properties.align) {
          node.properties.align = node.properties.align.toString();
        }
      }
    });
  };
}

export function transformContent(content) {
  const normalizedContent = normalizeLinkContinuations(content);
  const file = new VFile({value: normalizedContent});
  const mdast = remarkBase.parse(file);
  preprocessMdast(mdast, file);
  sanitizeMdast(mdast);

  let hast = toHast(mdast, {allowDangerousHtml: true});
  hast = unified().use(rehypeRaw).runSync(hast, file);
  hast = unified().use(rehypeCustom).runSync(hast, file);

  const mdastResult = toMdast(hast, {});
  sanitizeMdast(mdastResult);

  let output = unified()
    .use(remarkGfm)
    .use(remarkStringify, {
      bullet: '-',
      fences: true,
      entities: {useNamedReferences: true},
      listItemIndent: 'one',
      allowDangerousHtml: true,
    })
    .stringify(mdastResult);
  output = output.replace(/\n{3,}/g, '\n\n');
  if (file.data.frontmatter) {
    output = `---\n${file.data.frontmatter}\n---\n\n${output}`;
  }
  output = stripLiquidExpressions(output);
  output = output.replace(/<([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})>/g, '[$1](mailto:$1)');
  output = output
    .replace(/\\(<\/??Callout)/g, '$1')
    .replace(/<https?:\/\/[^>\s]+>/g, (match) => {
      const url = match.slice(1, -1);
      return `[${url}](${url})`;
    })
    .replace(/https\\:\/\//g, 'https://')
    .replace(/http\\:\/\//g, 'http://');
  return output;
}

function runCli() {
  const [, , inputPath, outputPath] = process.argv;
  if (!inputPath || !outputPath) {
    console.error('Usage: mdx-transform <input.md> <output.mdx>');
    process.exit(1);
  }
  const absoluteInput = path.resolve(inputPath);
  const absoluteOutput = path.resolve(outputPath);
  const content = fs.readFileSync(absoluteInput, 'utf8');
  const transformed = transformContent(content);
  fs.mkdirSync(path.dirname(absoluteOutput), {recursive: true});
  fs.writeFileSync(absoluteOutput, transformed, 'utf8');
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  runCli();
}

export {preprocessMdast, sanitizeMdast};
