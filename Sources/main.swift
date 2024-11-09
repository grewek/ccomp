import Foundation

// The Swift Programming Language
// https://docs.swift.org/swift-book

var errorCode: Int32 = 0
if CommandLine.arguments.count == 3 {
    if CommandLine.arguments[1] == "--lex" {
        let filepath = CommandLine.arguments[2]
        let source = try String(contentsOfFile: filepath, encoding: String.Encoding.ascii)
        var lexer = Lexer(source: source, currentPosition: 0)

        while true {
            do {
                let nextToken: Token = try lexer.next()

                if nextToken.tokenType == TokenType.Eof {
                    print("Reached the end!")
                    break
                }

                print("Token: \(nextToken.tokenType) => \(nextToken.tokenRepr)")
            } catch LexerError.UnrecognizedToken(
                _, _, let expected, let got)
            {
                print(
                    "error: unrecognized token type tried to parse a \(expected) token but \(got) did not match the token rules"
                )
                errorCode = 1
            }
        }

        exit(errorCode)
    } else if CommandLine.arguments[1] == "--parse" {
        let filepath = CommandLine.arguments[2]
        let source = try String(contentsOfFile: filepath, encoding: String.Encoding.ascii)

        var parser = Parser(tokenizer: Lexer(source: source, currentPosition: 0))
        let result = parser.ParseProgram()
        let repr = result.Display()
        print("\(repr)")
    } else if CommandLine.arguments[1] == "--tacky" {
        let filepath = CommandLine.arguments[2]
        let source = try String(contentsOfFile: filepath, encoding: String.Encoding.ascii)

        var parser = Parser(tokenizer: Lexer(source: source, currentPosition: 0))
        let result = parser.ParseProgram()
        var tacky = TackyGenerator(ast: result)
        let tackyResult = tacky.EmitTackyProgram(programDefinition: result)

        print("\(tackyResult.Display())")

    } else if CommandLine.arguments[1] == "--codegen" {
        let filepath = CommandLine.arguments[2]
        let source = try String(contentsOfFile: filepath, encoding: String.Encoding.ascii)

        var parser = Parser(tokenizer: Lexer(source: source, currentPosition: 0))
        let result = parser.ParseProgram()
        let codeGenerator = Generator(ast: result)

        print(codeGenerator.GenerateAssembly().Display())
        var myTestEmitter = Emitter(assembly: codeGenerator.GenerateAssembly(), path: "./test.txt")
        myTestEmitter.EmitProgram()
    } else {
        print("Usage: ccomp <FLAGS> <sourcefile>")
    }

    exit(0)
}
