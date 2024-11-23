enum LexerError: Error {
    case UnrecognizedToken(
        start: String.Index, end: String.Index, expected: TokenType, token: String.SubSequence)
}

enum InternalLexerError: Error {
    case InvalidToken(start: String.Index, expectedType: TokenType)
    case IndexOutOfRange
}

enum TokenType {
    /* Keyword Tokentypes */
    case KW_void
    case KW_int
    case KW_Return

    /* General Tokentypes */
    case Identifier
    case Constant
    case Symbol
    case Eof

    /* Operator Tokens */
    case OpenBrace
    case ClosedBrace
    case OpenParen
    case ClosedParen
    case ForwardSlash
    case Semicolon
    case Negation
    case Decrement
    case Complement
    case Plus
    case Asterisk
    case Percent

}

struct Token {
    let tokenType: TokenType
    let tokenRepr: String.SubSequence
}

struct Lexer {
    var source: String
    var currentPosition: Int

    func IdentifierToKeyword(possibleKeyword: String.SubSequence) -> Token {
        switch possibleKeyword {
        case "int":
            return Token(tokenType: TokenType.KW_int, tokenRepr: possibleKeyword)
        case "void":
            return Token(tokenType: TokenType.KW_void, tokenRepr: possibleKeyword)
        case "return":
            return Token(tokenType: TokenType.KW_Return, tokenRepr: possibleKeyword)
        default:
            return Token(tokenType: TokenType.Identifier, tokenRepr: possibleKeyword)
        }
    }

    func IsIdentifier(_ character: Character) -> Bool {
        return character.isLetter || character.isWholeNumber || character == "_"
    }

    func IsSpecialCharacter(_ character: Character) -> Bool {
        return character == "@"
    }

    mutating func GenerateIdentifierToken() throws -> Token {
        let tokenStart = currentPosition

        while currentPosition < source.count {
            let pos = String.Index.init(utf16Offset: currentPosition, in: source)
            let currentChar = source[pos]

            if IsIdentifier(currentChar) {
                currentPosition += 1
            } else if IsSpecialCharacter(currentChar)
                || !currentChar.isPunctuation && currentChar != ";"
                    && !currentChar.isWhitespace
            {
                let startPos = String.Index.init(utf16Offset: tokenStart, in: source)
                throw InternalLexerError.InvalidToken(
                    start: startPos, expectedType: TokenType.Identifier)
            } else {
                break
            }
        }

        let start = String.Index.init(utf16Offset: tokenStart, in: source)
        let end = String.Index.init(utf16Offset: currentPosition, in: source)

        return IdentifierToKeyword(possibleKeyword: source[start..<end])
    }

    mutating func GenerateConstantToken() throws -> String.SubSequence {
        let tokenStart = currentPosition
        var tokenEnd = currentPosition

        while currentPosition < source.count {
            let pos = String.Index.init(utf16Offset: currentPosition, in: source)
            let currentChar = source[pos]

            if currentChar.isWholeNumber {
                currentPosition += 1
            } else if !source[pos].isPunctuation && !source[pos].isSymbol && source[pos] != ";"
                && !source[pos].isWhitespace
            {
                let startPos = String.Index.init(utf16Offset: tokenStart, in: source)
                throw InternalLexerError.InvalidToken(
                    start: startPos, expectedType: TokenType.Constant)
            } else {
                tokenEnd = currentPosition
                break
            }
        }

        let start = String.Index.init(utf16Offset: tokenStart, in: source)
        let end = String.Index.init(utf16Offset: tokenEnd, in: source)

        return source[start..<end]
    }
    mutating func ConsumeWhitespace(character: Character) -> Bool {
        if character.isWhitespace {
            currentPosition += 1
            return true
        }

        return false
    }

    mutating func SkipError() {
        while currentPosition < source.count {
            let pos = String.Index.init(utf16Offset: currentPosition, in: source)
            let currentChar = source[pos]

            if currentChar.isWhitespace || currentChar == ";" {
                break
            }

            currentPosition += 1
        }
    }

    func PeekCharacter() throws -> Character {
        if currentPosition + 1 < source.count {
            let nextPosition = String.Index.init(utf16Offset: currentPosition + 1, in: source)
            return source[nextPosition]
        }

        throw InternalLexerError.IndexOutOfRange
    }

    mutating func ConsumeMultiLineComment() {
        while currentPosition < source.count {
            let pos = String.Index.init(utf16Offset: currentPosition, in: source)

            if source[pos] == "*" {
                let nextChar = try? PeekCharacter()
                if nextChar == "/" {
                    currentPosition += 2
                    break
                }
            }

            currentPosition += 1
        }
    }

    mutating func ConsumeComment() {
        while currentPosition < source.count {
            let pos = String.Index.init(utf16Offset: currentPosition, in: source)

            if source[pos] == "\n" {
                currentPosition += 1
                break
            }

            currentPosition += 1
        }
    }
    mutating func GenerateSymbolToken() -> Token {
        let pos = String.Index.init(utf16Offset: currentPosition, in: source)

        switch source[pos] {
        case "{":
            let token = source[pos...pos]
            currentPosition += 1
            return Token(tokenType: TokenType.OpenBrace, tokenRepr: token)
        case "}":
            let token = source[pos...pos]
            currentPosition += 1
            return Token(tokenType: TokenType.ClosedBrace, tokenRepr: token)
        case "(":
            let token = source[pos...pos]
            currentPosition += 1
            return Token(tokenType: TokenType.OpenParen, tokenRepr: token)
        case ")":
            let token = source[pos...pos]
            currentPosition += 1
            return Token(tokenType: TokenType.ClosedParen, tokenRepr: token)
        case "+":
            let token = source[pos...pos]
            currentPosition += 1
            return Token(tokenType: TokenType.Plus, tokenRepr: token)
        case "-":
            let token = source[pos...pos]
            let nextCharacter = try? PeekCharacter()
            if nextCharacter == "-" {
                currentPosition += 2
                let endPos = String.Index.init(utf16Offset: currentPosition, in: source)
                let token = source[pos...endPos]
                return Token(tokenType: TokenType.Decrement, tokenRepr: token)
            } else {
                currentPosition += 1
                return Token(tokenType: TokenType.Negation, tokenRepr: token)
            }
        case "*":
            let token = source[pos...pos]
            currentPosition += 1
            return Token(tokenType: TokenType.Asterisk, tokenRepr: token)
        case "%":
            let token = source[pos...pos]
            currentPosition += 1
            return Token(tokenType: TokenType.Percent, tokenRepr: token)
        case "~":
            let token = source[pos...pos]
            currentPosition += 1
            return Token(tokenType: TokenType.Complement, tokenRepr: token)
        case "/":
            let token = source[pos...pos]
            currentPosition += 1
            return Token(tokenType: TokenType.ForwardSlash, tokenRepr: token)
        case ";":
            let token = source[pos...pos]
            currentPosition += 1
            return Token(tokenType: TokenType.Semicolon, tokenRepr: token)
        default:
            let token = source[pos...pos]
            currentPosition += 1
            return Token(tokenType: TokenType.Symbol, tokenRepr: token)

        }
    }

    mutating func next() throws -> Token {
        while currentPosition < source.count {
            let pos = String.Index.init(utf16Offset: currentPosition, in: source)
            let currentChar = source[pos]

            if ConsumeWhitespace(character: currentChar) {
                continue
            }

            do {
                switch source[pos] {
                case "_", "a"..."z", "A"..."Z":
                    let token = try GenerateIdentifierToken()
                    return token
                case "0"..."9":
                    let token = try GenerateConstantToken()
                    return Token(tokenType: TokenType.Constant, tokenRepr: token)
                case "/":
                    let nextChar = try? PeekCharacter()
                    if nextChar == "*" {
                        currentPosition += 2
                        ConsumeMultiLineComment()
                    } else if nextChar == "/" {
                        currentPosition += 2
                        ConsumeComment()
                    } else {
                        return GenerateSymbolToken()
                    }
                default:
                    return GenerateSymbolToken()

                }
            } catch InternalLexerError.InvalidToken(let startPos, let tokenType) {
                SkipError()
                let end = String.Index.init(utf16Offset: currentPosition, in: source)
                let token = source[startPos..<end]
                throw LexerError.UnrecognizedToken(
                    start: startPos, end: end, expected: tokenType, token: token)

            } catch {
                print("error: unknown errorstate")
            }

        }

        return Token(tokenType: TokenType.Eof, tokenRepr: "")
    }
}
