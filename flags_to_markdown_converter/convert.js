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

// Write header
writeLine('---');
writeLine('title: Bazel flags');
writeLine('---');
writeLine('');

// Write each flag
for (const flag of flags.flagInfos) {
    const abbrev = flag.abbreviation ? `(-${flag.abbreviation})` : '';
    writeLine(`## --${flag.name} ${abbrev}`);
    writeLine('');
    // TODO: add history - what version of Bazel introduced this flag?
    // TODO: this is wrapped in a <pre> tag to avoid invalid markdown like bare html tags
    writeLine(escapeHtml(flag.documentation));
    
    if (flag.commands.length > 0) {
        writeLine('');
        writeLine(`_May apply to commands: ${flag.commands.join(', ')}_`);
    }
    
    writeLine('');
}
