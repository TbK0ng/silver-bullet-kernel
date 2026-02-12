import fs from "node:fs";
import path from "node:path";
import ts from "typescript";

type CliOptions = {
  file: string;
  line: number;
  column: number;
  newName: string;
  dryRun: boolean;
  includeComments: boolean;
  includeStrings: boolean;
};

function readArgs(argv: string[]): CliOptions {
  const args = new Map<string, string>();
  const flags = new Set<string>();
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token) {
      continue;
    }
    if (!token.startsWith("--")) {
      continue;
    }
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      flags.add(key);
      continue;
    }
    args.set(key, next);
    i += 1;
  }

  const file = args.get("file");
  const line = Number(args.get("line"));
  const column = Number(args.get("column"));
  const newName = args.get("newName");

  if (!file || Number.isNaN(line) || Number.isNaN(column) || !newName) {
    throw new Error(
      "Usage: npm run refactor:rename -- --file <path> --line <1-based> --column <1-based> --newName <name> [--dryRun] [--includeComments] [--includeStrings]",
    );
  }
  if (line <= 0 || column <= 0) {
    throw new Error("line and column must be 1-based positive integers.");
  }
  if (!/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(newName)) {
    throw new Error(`newName '${newName}' is not a valid TypeScript identifier.`);
  }

  return {
    file,
    line,
    column,
    newName,
    dryRun: flags.has("dryRun"),
    includeComments: flags.has("includeComments"),
    includeStrings: flags.has("includeStrings"),
  };
}

function toAbsolutePath(p: string, cwd: string): string {
  const absolute = path.isAbsolute(p) ? p : path.join(cwd, p);
  return path.normalize(absolute);
}

function lineColumnToPosition(content: string, line: number, column: number): number {
  const lines = content.split(/\r?\n/);
  if (line > lines.length) {
    throw new Error(`line ${line} exceeds file line count ${lines.length}.`);
  }
  const targetLine = lines[line - 1];
  if (targetLine === undefined) {
    throw new Error(`line ${line} is not available in target file.`);
  }
  if (column > targetLine.length + 1) {
    throw new Error(`column ${column} exceeds line length ${targetLine.length + 1}.`);
  }
  let offset = 0;
  for (let i = 0; i < line - 1; i += 1) {
    offset += (lines[i] ?? "").length + 1;
  }
  return offset + (column - 1);
}

function applyFileEdits(
  originalContent: string,
  edits: Array<{ start: number; end: number; replacement: string }>,
): string {
  const sorted = [...edits].sort((a, b) => b.start - a.start);
  let next = originalContent;
  for (const edit of sorted) {
    next =
      next.slice(0, edit.start) +
      edit.replacement +
      next.slice(edit.end);
  }
  return next;
}

function createLanguageService(projectRoot: string): {
  service: ts.LanguageService;
  parsedConfig: ts.ParsedCommandLine;
} {
  const configPath = ts.findConfigFile(projectRoot, ts.sys.fileExists, "tsconfig.json");
  if (!configPath) {
    throw new Error(`tsconfig.json not found from ${projectRoot}`);
  }

  const configText = fs.readFileSync(configPath, "utf8");
  const jsonResult = ts.parseConfigFileTextToJson(configPath, configText);
  if (jsonResult.error) {
    throw new Error(ts.flattenDiagnosticMessageText(jsonResult.error.messageText, "\n"));
  }

  const parsedConfig = ts.parseJsonConfigFileContent(
    jsonResult.config,
    ts.sys,
    path.dirname(configPath),
  );
  if (parsedConfig.errors.length > 0) {
    const first = parsedConfig.errors[0];
    if (!first) {
      throw new Error("failed to parse tsconfig with unknown error.");
    }
    throw new Error(ts.flattenDiagnosticMessageText(first.messageText, "\n"));
  }

  const versions = new Map<string, string>();
  for (const fileName of parsedConfig.fileNames) {
    versions.set(path.normalize(fileName), "0");
  }

  const host: ts.LanguageServiceHost = {
    getCompilationSettings: () => parsedConfig.options,
    getScriptFileNames: () => parsedConfig.fileNames,
    getScriptVersion: (fileName) => versions.get(path.normalize(fileName)) ?? "0",
    getScriptSnapshot: (fileName) => {
      if (!fs.existsSync(fileName)) {
        return undefined;
      }
      return ts.ScriptSnapshot.fromString(fs.readFileSync(fileName, "utf8"));
    },
    getCurrentDirectory: () => projectRoot,
    getDefaultLibFileName: (options) => ts.getDefaultLibFilePath(options),
    fileExists: ts.sys.fileExists,
    readFile: ts.sys.readFile,
    readDirectory: ts.sys.readDirectory,
  };

  const service = ts.createLanguageService(host, ts.createDocumentRegistry());
  return { service, parsedConfig };
}

function main(): void {
  const cwd = process.cwd();
  const options = readArgs(process.argv.slice(2));
  const targetFile = toAbsolutePath(options.file, cwd);

  if (!fs.existsSync(targetFile)) {
    throw new Error(`file not found: ${targetFile}`);
  }

  const { service, parsedConfig } = createLanguageService(cwd);
  const fileInProgram = parsedConfig.fileNames
    .map((f) => path.normalize(f))
    .includes(targetFile);
  if (!fileInProgram) {
    throw new Error(`target file is not included by tsconfig: ${targetFile}`);
  }

  const content = fs.readFileSync(targetFile, "utf8");
  const position = lineColumnToPosition(content, options.line, options.column);

  const renameInfo = service.getRenameInfo(targetFile, position, {
    allowRenameOfImportPath: false,
  });
  if (!renameInfo.canRename) {
    throw new Error(renameInfo.localizedErrorMessage ?? "symbol at given position cannot be renamed.");
  }

  const locations =
    service.findRenameLocations(
      targetFile,
      position,
      options.includeStrings,
      options.includeComments,
      true,
    ) ?? [];
  if (locations.length === 0) {
    throw new Error("no rename locations found.");
  }

  const byFile = new Map<string, Array<{ start: number; end: number; replacement: string }>>();
  for (const loc of locations) {
    const file = path.normalize(loc.fileName);
    const fileEdits = byFile.get(file) ?? [];
    const prefix = loc.prefixText ?? "";
    const suffix = loc.suffixText ?? "";
    fileEdits.push({
      start: loc.textSpan.start,
      end: loc.textSpan.start + loc.textSpan.length,
      replacement: `${prefix}${options.newName}${suffix}`,
    });
    byFile.set(file, fileEdits);
  }

  let touchedFiles = 0;
  let touchedLocations = 0;
  for (const [fileName, edits] of byFile.entries()) {
    touchedFiles += 1;
    touchedLocations += edits.length;
    if (options.dryRun) {
      continue;
    }
    const previous = fs.readFileSync(fileName, "utf8");
    const next = applyFileEdits(previous, edits);
    fs.writeFileSync(fileName, next, "utf8");
  }

  const mode = options.dryRun ? "dry-run" : "apply";
  console.log(
    JSON.stringify(
      {
        mode,
        symbol: renameInfo.displayName,
        from: {
          file: path.relative(cwd, targetFile),
          line: options.line,
          column: options.column,
        },
        to: options.newName,
        touchedFiles,
        touchedLocations,
      },
      null,
      2,
    ),
  );
}

try {
  main();
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[semantic-rename] ${message}`);
  process.exit(1);
}
