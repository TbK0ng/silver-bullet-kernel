import fs from "node:fs";
import path from "node:path";
import ts from "typescript";

type SemanticOperation = "rename" | "reference-map" | "safe-delete-candidates";

type CliOptions = {
  operation: SemanticOperation;
  file: string;
  line: number;
  column: number;
  newName: string;
  dryRun: boolean;
  includeComments: boolean;
  includeStrings: boolean;
  maxResults: number;
};

type FileEdit = {
  start: number;
  end: number;
  replacement: string;
};

function parseOperation(raw: string | undefined): SemanticOperation {
  if (!raw || raw.trim().length === 0) {
    return "rename";
  }
  const normalized = raw.trim().toLowerCase();
  if (
    normalized === "rename" ||
    normalized === "reference-map" ||
    normalized === "safe-delete-candidates"
  ) {
    return normalized;
  }
  throw new Error(
    `unsupported operation '${raw}'. use rename|reference-map|safe-delete-candidates.`,
  );
}

function readArgs(argv: string[]): CliOptions {
  const args = new Map<string, string>();
  const flags = new Set<string>();
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token || !token.startsWith("--")) {
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

  const operation = parseOperation(args.get("operation"));
  const file = args.get("file");
  const line = Number(args.get("line"));
  const column = Number(args.get("column"));
  const newName = args.get("newName") ?? "";
  const maxResults = Number(args.get("maxResults") ?? "200");

  if (!file || Number.isNaN(line) || Number.isNaN(column)) {
    throw new Error(
      "Usage: tsx scripts/semantic-rename.ts --operation <rename|reference-map|safe-delete-candidates> --file <path> --line <1-based> --column <1-based> [--newName <name>] [--dryRun] [--maxResults <n>]",
    );
  }
  if (line <= 0 || column <= 0) {
    throw new Error("line and column must be 1-based positive integers.");
  }
  if (!Number.isInteger(maxResults) || maxResults <= 0) {
    throw new Error("maxResults must be a positive integer.");
  }
  if (operation === "rename") {
    if (!newName) {
      throw new Error("rename operation requires --newName <name>.");
    }
    if (!/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(newName)) {
      throw new Error(`newName '${newName}' is not a valid TypeScript identifier.`);
    }
  }

  return {
    operation,
    file,
    line,
    column,
    newName,
    dryRun: flags.has("dryRun"),
    includeComments: flags.has("includeComments"),
    includeStrings: flags.has("includeStrings"),
    maxResults,
  };
}

function toAbsolutePath(inputPath: string, cwd: string): string {
  const absolute = path.isAbsolute(inputPath) ? inputPath : path.join(cwd, inputPath);
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

function positionToLineColumn(content: string, position: number): { line: number; column: number } {
  let line = 1;
  let column = 1;
  const end = Math.max(0, Math.min(position, content.length));
  for (let i = 0; i < end; i += 1) {
    if (content[i] === "\n") {
      line += 1;
      column = 1;
    } else {
      column += 1;
    }
  }
  return { line, column };
}

function isIdentifierChar(ch: string | undefined): boolean {
  return !!ch && /[A-Za-z0-9_$]/.test(ch);
}

function extractIdentifierAtPosition(content: string, position: number): string {
  if (content.length === 0) {
    throw new Error("target file is empty.");
  }

  let pivot = Math.max(0, Math.min(position, content.length - 1));
  if (!isIdentifierChar(content[pivot])) {
    if (pivot > 0 && isIdentifierChar(content[pivot - 1])) {
      pivot -= 1;
    } else {
      throw new Error("no TypeScript identifier found at the target position.");
    }
  }

  let start = pivot;
  let end = pivot;
  while (start > 0 && isIdentifierChar(content[start - 1])) {
    start -= 1;
  }
  while (end < content.length - 1 && isIdentifierChar(content[end + 1])) {
    end += 1;
  }

  const symbol = content.slice(start, end + 1);
  if (!/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(symbol)) {
    throw new Error(`resolved token '${symbol}' is not a valid identifier.`);
  }
  return symbol;
}

function applyFileEdits(originalContent: string, edits: FileEdit[]): string {
  const sorted = [...edits].sort((a, b) => b.start - a.start);
  let next = originalContent;
  for (const edit of sorted) {
    next = next.slice(0, edit.start) + edit.replacement + next.slice(edit.end);
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

function assertFileInProgram(parsedConfig: ts.ParsedCommandLine, targetFile: string): void {
  const fileInProgram = parsedConfig.fileNames.map((f) => path.normalize(f)).includes(targetFile);
  if (!fileInProgram) {
    throw new Error(`target file is not included by tsconfig: ${targetFile}`);
  }
}

function getSymbolName(service: ts.LanguageService, fileName: string, position: number, content: string): string {
  const renameInfo = service.getRenameInfo(fileName, position, {
    allowRenameOfImportPath: false,
  });
  if (renameInfo.canRename && renameInfo.displayName) {
    return renameInfo.displayName;
  }
  return extractIdentifierAtPosition(content, position);
}

function readFileCached(cache: Map<string, string>, fileName: string): string {
  const normalized = path.normalize(fileName);
  const existing = cache.get(normalized);
  if (existing !== undefined) {
    return existing;
  }
  const content = fs.readFileSync(normalized, "utf8");
  cache.set(normalized, content);
  return content;
}

function makeSpanKey(fileName: string, start: number, length: number): string {
  return `${path.normalize(fileName)}:${start}:${length}`;
}

function buildDefinitionLookup(
  service: ts.LanguageService,
  targetFile: string,
  position: number,
): Set<string> {
  const definitions = service.getDefinitionAtPosition(targetFile, position) ?? [];
  const lookup = new Set<string>();
  for (const item of definitions) {
    lookup.add(makeSpanKey(item.fileName, item.textSpan.start, item.textSpan.length));
  }
  return lookup;
}

function runRename(
  options: CliOptions,
  service: ts.LanguageService,
  cwd: string,
  targetFile: string,
  position: number,
): Record<string, unknown> {
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

  const byFile = new Map<string, FileEdit[]>();
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

  return {
    operation: "rename",
    mode: options.dryRun ? "dry-run" : "apply",
    backend: "typescript-language-service",
    symbol: renameInfo.displayName,
    from: {
      file: path.relative(cwd, targetFile),
      line: options.line,
      column: options.column,
    },
    to: options.newName,
    touchedFiles,
    touchedLocations,
  };
}

function runReferenceMap(
  options: CliOptions,
  service: ts.LanguageService,
  cwd: string,
  targetFile: string,
  position: number,
  content: string,
): Record<string, unknown> {
  const allReferences = service.getReferencesAtPosition(targetFile, position) ?? [];
  if (allReferences.length === 0) {
    throw new Error("no references found for selected symbol.");
  }
  const symbol = getSymbolName(service, targetFile, position, content);
  const definitionLookup = buildDefinitionLookup(service, targetFile, position);
  const fileCache = new Map<string, string>();
  const limited = allReferences.slice(0, options.maxResults);
  const touchedFiles = new Set<string>();

  const references = limited.map((entry) => {
    const fileName = path.normalize(entry.fileName);
    const referenceKey = makeSpanKey(fileName, entry.textSpan.start, entry.textSpan.length);
    const isDefinition = definitionLookup.has(referenceKey);
    touchedFiles.add(fileName);
    const entryContent = readFileCached(fileCache, fileName);
    const coordinates = positionToLineColumn(entryContent, entry.textSpan.start);
    return {
      file: path.relative(cwd, fileName),
      line: coordinates.line,
      column: coordinates.column,
      length: entry.textSpan.length,
      isDefinition,
      isWriteAccess: !!entry.isWriteAccess,
    };
  });

  const definitionCount = allReferences.filter((entry) =>
    definitionLookup.has(makeSpanKey(entry.fileName, entry.textSpan.start, entry.textSpan.length)),
  ).length;
  const writeCount = allReferences.filter((entry) => !!entry.isWriteAccess).length;
  const readCount = Math.max(0, allReferences.length - writeCount);

  return {
    operation: "reference-map",
    mode: "analysis",
    backend: "typescript-language-service",
    symbol,
    from: {
      file: path.relative(cwd, targetFile),
      line: options.line,
      column: options.column,
    },
    summary: {
      totalReferences: allReferences.length,
      emittedReferences: references.length,
      truncated: allReferences.length > references.length,
      touchedFiles: touchedFiles.size,
      definitionCount,
      readCount,
      writeCount,
    },
    references,
  };
}

function runSafeDelete(
  options: CliOptions,
  service: ts.LanguageService,
  cwd: string,
  targetFile: string,
  position: number,
  content: string,
): Record<string, unknown> {
  const allReferences = service.getReferencesAtPosition(targetFile, position) ?? [];
  if (allReferences.length === 0) {
    throw new Error("no references found for selected symbol.");
  }
  const symbol = getSymbolName(service, targetFile, position, content);
  const definitionLookup = buildDefinitionLookup(service, targetFile, position);
  const nonDefinition = allReferences.filter(
    (entry) =>
      !definitionLookup.has(makeSpanKey(entry.fileName, entry.textSpan.start, entry.textSpan.length)),
  );
  const safeToDelete = nonDefinition.length === 0;
  const confidence = safeToDelete ? "high" : nonDefinition.length <= 2 ? "medium" : "low";

  const fileCache = new Map<string, string>();
  const limited = allReferences.slice(0, options.maxResults);
  const references = limited.map((entry) => {
    const fileName = path.normalize(entry.fileName);
    const entryContent = readFileCached(fileCache, fileName);
    const coordinates = positionToLineColumn(entryContent, entry.textSpan.start);
    const referenceKey = makeSpanKey(fileName, entry.textSpan.start, entry.textSpan.length);
    return {
      file: path.relative(cwd, fileName),
      line: coordinates.line,
      column: coordinates.column,
      isDefinition: definitionLookup.has(referenceKey),
      isWriteAccess: !!entry.isWriteAccess,
    };
  });

  return {
    operation: "safe-delete-candidates",
    mode: "analysis",
    backend: "typescript-language-service",
    symbol,
    from: {
      file: path.relative(cwd, targetFile),
      line: options.line,
      column: options.column,
    },
    candidate: {
      safeToDelete,
      confidence,
      totalReferences: allReferences.length,
      nonDefinitionReferences: nonDefinition.length,
      rationale: safeToDelete
        ? "symbol has no non-definition references in TypeScript language-service index"
        : "symbol has active references and cannot be marked safe-delete",
    },
    summary: {
      emittedReferences: references.length,
      truncated: allReferences.length > references.length,
    },
    references,
  };
}

function main(): void {
  const cwd = process.cwd();
  const options = readArgs(process.argv.slice(2));
  const targetFile = toAbsolutePath(options.file, cwd);
  if (!fs.existsSync(targetFile)) {
    throw new Error(`file not found: ${targetFile}`);
  }

  const { service, parsedConfig } = createLanguageService(cwd);
  assertFileInProgram(parsedConfig, targetFile);

  const content = fs.readFileSync(targetFile, "utf8");
  const position = lineColumnToPosition(content, options.line, options.column);

  let payload: Record<string, unknown>;
  switch (options.operation) {
    case "rename":
      payload = runRename(options, service, cwd, targetFile, position);
      break;
    case "reference-map":
      payload = runReferenceMap(options, service, cwd, targetFile, position, content);
      break;
    case "safe-delete-candidates":
      payload = runSafeDelete(options, service, cwd, targetFile, position, content);
      break;
    default:
      throw new Error(`unsupported operation '${String(options.operation)}'.`);
  }

  console.log(JSON.stringify(payload, null, 2));
}

try {
  main();
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[semantic-rename] ${message}`);
  process.exit(1);
}
