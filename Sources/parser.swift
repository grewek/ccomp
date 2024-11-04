enum AstProgram {
    case Program(function: AstFunctionDefinition)

    func Display() -> String {
        switch self {
        case .Program(let function):
            return "Program(\(function.Display()))"
        }
    }
}

enum AstFunctionDefinition {
    case Function(identifier: String, statement: AstStatement)

    func Display() -> String {
        switch self {

        case .Function(let identifier, let statement):
            return "Function(\n\tname = \(identifier)\n\tbody=\(statement.Display())\n)"
        }
    }
}

enum AstStatement {
    case Return(expression: AstExpression)

    func Display() -> String {
        switch self {
        case .Return(let expression):
            return "Return(\(expression.Display())\n\t)"
        }
    }
}

indirect enum AstExpression {
    case Constant(value: Int)
    case Unary(unaryOperator: AstUnaryOperator, expression: AstExpression)

    func Display() -> String {
        switch self {
        case .Constant(let value):
            return "\n\t\tConstant(\(value))"
        case .Unary(let unaryOperator, let expression):
            return
                "\n\t\tUnary(Operator = \(unaryOperator.Display())\n\t\tExpression = \(expression.Display()))"
        }

    }
}

enum AstUnaryOperator {
    case Complement
    case Negate

    func Display() -> String {
        switch self {

        case .Complement:
            return "Complement"
        case .Negate:
            return "Negate"
        }
    }
}

struct Parser {
    var tokenizer: Lexer

    mutating func Expect(tokenOfType: TokenType) -> Bool {
        let current = try? tokenizer.next()

        if current?.tokenType == tokenOfType {
            return true
        }

        fatalError("ERROR: Expected \(tokenOfType) but found \(current!.tokenType)")
    }

    mutating func ParseProgram() -> AstProgram {
        let function = ParseFunction()

        _ = Expect(tokenOfType: TokenType.Eof)

        return AstProgram.Program(function: function)
    }

    mutating func ParseIdentifier() -> String {
        let current = try? tokenizer.next()
        if current?.tokenType == TokenType.Identifier {
            return String(current!.tokenRepr)
        }

        fatalError("ERROR: Expected \(TokenType.Identifier) but found \(current!.tokenType)")
    }

    mutating func ParseFunction() -> AstFunctionDefinition {
        /*Return type parser */
        _ = Expect(tokenOfType: TokenType.KW_int)
        /*Function Name parser */
        let identifier = ParseIdentifier()

        /*Argument List parser */
        _ = Expect(tokenOfType: TokenType.OpenParen)
        _ = Expect(tokenOfType: TokenType.KW_void)
        _ = Expect(tokenOfType: TokenType.ClosedParen)

        /*Body parser */
        _ = Expect(tokenOfType: TokenType.OpenBrace)
        let statement = ParseStatement()
        _ = Expect(tokenOfType: TokenType.ClosedBrace)

        return AstFunctionDefinition.Function(identifier: identifier, statement: statement)

    }
    mutating func ParseStatement() -> AstStatement {
        _ = Expect(tokenOfType: TokenType.KW_Return)
        let expression = ParseExpression()
        _ = Expect(tokenOfType: TokenType.Semicolon)

        return AstStatement.Return(expression: expression)
    }

    func ParseUnaryOperation(token: Token?) -> AstUnaryOperator {

        if token?.tokenType == TokenType.Negation {
            return AstUnaryOperator.Negate
        } else if token?.tokenType == TokenType.Complement {
            print("Parsed a complement operator")
            return AstUnaryOperator.Complement
        }

        fatalError("Error: Expected a Unary Operator but found \(token!.tokenType)")
    }

    mutating func ParseExpression() -> AstExpression {
        let value = try? tokenizer.next()

        if value?.tokenType == TokenType.Constant {
            let value = Int(value!.tokenRepr)
            return AstExpression.Constant(value: value!)
        } else if value?.tokenType == TokenType.Negation || value?.tokenType == TokenType.Complement
        {
            let op = ParseUnaryOperation(token: value)
            let expression = ParseExpression()
            return AstExpression.Unary(unaryOperator: op, expression: expression)

        } else if value?.tokenType == TokenType.OpenParen {
            let innerExpression = ParseExpression()
            _ = Expect(tokenOfType: TokenType.ClosedParen)
            return innerExpression

        } else {
            /*TODO: ERROR*/
        }

        fatalError("ERROR: Expected Numeric value but got \(value!.tokenType)")
    }
}
