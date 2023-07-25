// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////////

const { FuzzedDataProvider } = require("@jazzer.js/core");
const ts = require("typescript");

module.exports.fuzz = function(data) {
  const provider = new FuzzedDataProvider(data);

  try {
    const fileName = provider.consumeString(10) + ".ts";
    const filePath = provider.consumeString(10) + "/" + fileName;
    const fileContent = provider.consumeString(100);

    const sourceFile = ts.createSourceFile(fileName, fileContent, ts.ScriptTarget.Latest);

    const result = ts.parseSourceFile(sourceFile, ts.ScriptTarget.Latest, true);
    const _diagnostics = result.diagnostics.map(diagnostic => {
      return {
        message: diagnostic.messageText,
        start: diagnostic.start,
        length: diagnostic.length,
        file: diagnostic.file.fileName
      };
    });


    const program = ts.createProgram([fileName], { allowJs: true });
    const printer = ts.createPrinter();
    const nodes = ts.createNodeArray([sourceFile]);
    const transformers = [() => node => node];
    const identifier = ts.createIdentifier(provider.consumeString(10));
    const typeNode = ts.createTypeReferenceNode(identifier, []);

    ts.createSourceMapFile(sourceFile.fileName, filePath, fileContent, [], [], [], program.getCompilerOptions());
    printer.printFile(sourceFile);

    ts.transform(nodes, transformers);
    ts.createSymbol(ts.SymbolFlags.Type, identifier);
    ts.createType(typeNode);

    const watchCompilerHost = ts.createWatchCompilerHost([fileName], { allowJs: true }, ts.sys, ts.createSemanticDiagnosticsBuilderProgram, undefined, undefined, undefined, undefined, undefined, undefined, undefined, undefined);

    program.getTypeChecker();
    program.emit();
    program.getTypeRoots();
    ts.getParsedCommandLineOfConfigFile(fileName, {}, ts.sys).errors;
    program.getDeclarationDiagnostics();
  }
  catch (error) {
    if (!ignoredError(error)) {
      throw error;
    }
  }
};

function ignoredError(error) {
  return !!ignored.find((message) => error.message.indexOf(message) !== -1);
}

const ignored = [
  "is not a function"
];

