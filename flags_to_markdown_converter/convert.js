import { FlagCollectionSchema } from '@buf/bazel_bazel.bufbuild_es/bazel_flags/bazel_flags_pb.js';
import { fromBinary } from '@bufbuild/protobuf'

const writeLine = (line) => process.stdout.write(line + '\n');
function escapeHtml(str) {
    return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

// Read stdin as a stream
let base64String = '';
process.stdin.setEncoding('utf8');
for await (const chunk of process.stdin) {
    base64String += chunk;
}

const flags = fromBinary(FlagCollectionSchema, Buffer.from(base64String.trim(), 'base64'));
const documentedFlags = flags.flagInfos.filter(f => f.documentationCategory !== 'UNDOCUMENTED');
const flagsByCategory = documentedFlags.reduce((m, f) => {
    if (f.metadataTags.length > 1) throw Error();
    // Invent a metadata tag for flags that would otherwise be ungrouped.
    // This is done to avoid having some nested more deeply than others.
    let tag = f.metadataTags[0] || 'STABLE';
    // bugfix?
    if (f.name.startsWith('experimental_')) {
        tag = 'EXPERIMENTAL'
    }
    if (!m.has(f.documentationCategory)) {
        m.set(f.documentationCategory, new Map());
    }
    if (!m.get(f.documentationCategory).has(tag)) {
        m.get(f.documentationCategory).set(tag, []);
    }
    m.get(f.documentationCategory).get(tag).push(f);
    return m;
}, new Map());

// Write header
writeLine('---');
writeLine('title: Bazel flags');
writeLine('---');

// Write each flag
for (const category of flagsByCategory.keys()) {
    writeLine(`## ${category.toLowerCase()}\n`)
    for (const tag of flagsByCategory.get(category).keys()) {
        writeLine(`### ${tag.toLowerCase()}\n`)
        for (const flag of flagsByCategory.get(category).get(tag)) {
            writeLine(`#### --${flag.name}`);
            let aliases = [];
            if (flag.abbreviation) {
                aliases.push(`-${flag.abbreviation}`);
            }
            if (flag.hasNegativeFlag) {
                aliases.push(`--no${flag.name}`);
            }
            if (flag.oldName) {
                aliases.push(`previously ${flag.oldName}`);
            }
            if (flag.deprecationWarning) {
                writeLine('[WARN] deprecated: ' + flag.deprecationWarning)
            }
            if (flag.optionExpansions.length > 0) {
                writeLine('expands to ' + flag.optionExpansions)
            }
            if (flag.enumValues.length > 0) {
                writeLine('enum values: ' + flag.enumValues)
            }
            
            writeLine('effect: ' + flag.effectTags)
            writeLine('allowsMultiple: ' + flag.allowsMultiple)
            writeLine('requiresValue: ' + flag.requiresValue)
            writeLine('defaultValue: ' + flag.defaultValue)

            // TODO: add history - what version of Bazel introduced this flag?
            // TODO: link to GitHub issue where the flag is being managed (i.e. graduate from experimental)
            // TODO: link to definition of the flag in Bazel sources
            // TODO: add popularity - how many times does it appear in github search for bazelrc files?
            // TODO: this is wrapped in a <pre> tag to avoid invalid markdown like bare html tags
            // also a bugfix for Bazel/Blaze placeholder.
            writeLine(escapeHtml(flag.documentation.replace('%{product}', 'Bazel')));
            
            if (flag.commands.length > 0) {
                writeLine('');
                writeLine(`_May apply to commands: ${flag.commands.join(', ')}_`);
            }
            
            writeLine('');
        }
    }
}