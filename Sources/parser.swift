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
    case Binary(binaryOperator: BinaryOperator, left: AstExpression, right: AstExpression)

    func Display() -> String {
        switch self {
        case .Constant(let value):
            return "\n\t\tConstant(\(value))"
        case .Unary(let unaryOperator, let expression):
            return
                "\n\t\tUnary(Operator = \(unaryOperator.Display())\n\t\tExpression = \(expression.Display()))"
        case .Binary(let op, let left, let right):
            return
                "\n\tBinary (Operator = \(op.Display()), \n\tleft = \(left.Display()), \n\tright = \(right.Display()))"
        }

    }
}

enum BinaryOperator {
    case Add
    case Subtract
    case Multiply
    case Divide
    case Remainder

    func Display() -> String {
        switch self {
        case .Add:
            return "+"
        case .Subtract:
            return "-"
        case .Multiply:
            return "*"
        case .Divide:
            return "/"
        case .Remainder:
            return "%"
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
    var currentToken: Token?

    init(tokenizer: Lexer) {
        self.tokenizer = tokenizer

        //TODO: Handle the actual error !
        currentToken = try? self.tokenizer.next()
    }

    mutating func Advance() {
        currentToken = try? tokenizer.next()
    }

    mutating func Expect(tokenOfType: TokenType) -> Bool {
        if currentToken?.tokenType == tokenOfType {
            Advance()
            return true
        }

        fatalError("ERROR: Expected \(tokenOfType) but found \(currentToken!.tokenType)")
    }

    mutating func ParseProgram() -> AstProgram {
        let function = ParseFunction()

        _ = Expect(tokenOfType: TokenType.Eof)

        return AstProgram.Program(function: function)
    }

    mutating func ParseIdentifier() -> String {
        if currentToken?.tokenType == TokenType.Identifier {
            let identifier = String(currentToken!.tokenRepr)
            Advance()
            return identifier
        }

        fatalError("ERROR: Expected \(TokenType.Identifier) but found \(currentToken!.tokenType)")
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
        //NOTE: We start parsing with zero
        let expression = ParseExpression(minPrecedence: 0)
        _ = Expect(tokenOfType: TokenType.Semicolon)

        return AstStatement.Return(expression: expression)
    }

    func ParseUnaryOperation() -> AstUnaryOperator {

        if currentToken?.tokenType == TokenType.Negation {
            return AstUnaryOperator.Negate
        } else if currentToken?.tokenType == TokenType.Complement {
            return AstUnaryOperator.Complement
        }

        fatalError("Error: Expected a Unary Operator but found \(currentToken!.tokenType)")
    }

    mutating func ParseBinaryOperator() -> BinaryOperator {
        if currentToken?.tokenType == TokenType.Plus {
            return BinaryOperator.Add
        } else if currentToken?.tokenType == TokenType.Negation {
            return BinaryOperator.Subtract
        } else if currentToken?.tokenType == TokenType.ForwardSlash {
            return BinaryOperator.Divide
        } else if currentToken?.tokenType == TokenType.Asterisk {
            return BinaryOperator.Multiply
        } else if currentToken?.tokenType == TokenType.Percent {
            return BinaryOperator.Remainder
        }

        fatalError("ERROR: Unknown Binary Operation cannot proceed with Parsing")

    }

    mutating func ParseFactor(minPrecedence: UInt) -> AstExpression {
        if currentToken?.tokenType == TokenType.Constant {
            let value = Int(currentToken!.tokenRepr)
            Advance()
            return AstExpression.Constant(value: value!)
        } else if currentToken?.tokenType == TokenType.Negation
            || currentToken?.tokenType == TokenType.Complement
        {
            let op = ParseUnaryOperation()
            Advance()
            let expression = ParseFactor(minPrecedence: 0)
            return AstExpression.Unary(unaryOperator: op, expression: expression)

        } else if currentToken?.tokenType == TokenType.OpenParen {
            Advance()
            let innerExpression = ParseExpression(minPrecedence: 0)
            _ = Expect(tokenOfType: TokenType.ClosedParen)
            return innerExpression

        }

        fatalError("ERROR: Unknown Factor in Expression \(currentToken!)")
    }

    func IsBinaryOperator() -> Bool {
        let tokenType = currentToken?.tokenType

        return tokenType == TokenType.Negation || tokenType == TokenType.Plus
            || tokenType == TokenType.ForwardSlash || tokenType == TokenType.Asterisk
            || tokenType == TokenType.Percent
    }

    func OperatorPrecedence() -> UInt {
        let tokenType = currentToken?.tokenType

        if tokenType == TokenType.Negation || tokenType == TokenType.Plus {
            return 45
        } else if tokenType == TokenType.ForwardSlash || tokenType == TokenType.Asterisk
            || tokenType == TokenType.Percent
        {
            return 50
        }

        fatalError("Expected Operator but found \(tokenType!)")
    }

    func OperatorPrecedence(op: BinaryOperator) -> UInt {
        switch op {
        case .Add, .Subtract:
            return 45
        case .Multiply, .Divide, .Remainder:
            return 50
        }
    }

    mutating func ParseExpression(minPrecedence: UInt) -> AstExpression {
        var left = ParseFactor(minPrecedence: minPrecedence)

        while IsBinaryOperator() && OperatorPrecedence() >= minPrecedence {
            let binOp = ParseBinaryOperator()
            Advance()
            let right = ParseExpression(minPrecedence: OperatorPrecedence(op: binOp) + 1)
            left = AstExpression.Binary(binaryOperator: binOp, left: left, right: right)
        }

        return left
    }
}
