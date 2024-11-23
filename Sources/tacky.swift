enum AstTackyProgram {
    case Program(functionDefinition: AstTackyFunction)

    func Display() -> String {
        switch self {
        case .Program(let functionDefinition):
            return "Program(\(functionDefinition.Display()))"

        }
    }
}

enum AstTackyFunction {
    case Function(name: String, instructions: [AstTackyInstruction])

    func Display() -> String {
        switch self {
        case .Function(let name, let instructions):
            var result = "\(name):\n"
            for instruction in instructions {
                result += "\t\(instruction.Display())\n"
            }

            return result
        }
    }
}

enum AstTackyInstruction {
    case Return(value: AstTackyValue)
    case Unary(unaryOperator: AstTackyUnaryOperator, dest: AstTackyValue, src: AstTackyValue)

    func Display() -> String {
        switch self {
        case .Return(let value):
            return "return \(value)"
        case .Unary(let unaryOperator, let dest, let src):
            return "\(dest.Display()) = \(unaryOperator.Display()) \(src.Display())"
        }
    }
}

enum AstTackyValue {
    case Constant(value: Int)
    case Var(identifier: String)

    func Display() -> String {
        switch self {
        case .Constant(let value):
            return "\(value)"
        case .Var(let identifier):
            return "\(identifier)"
        }
    }
}

enum AstTackyUnaryOperator {
    case Complement
    case Negate

    func Display() -> String {
        switch self {
        case .Complement:
            return "~"
        case .Negate:
            return "-"
        }
    }
}

struct TackyGenerator {
    var ast: AstProgram
    var tempCount: UInt = 0

    mutating func MakeTemporary() -> String {
        //TODO: We need a non constant value here!
        let id = tempCount
        self.tempCount += 1
        return "tmp.\(id)"
    }

    mutating func EmitTackyProgram(programDefinition: AstProgram) -> AstTackyProgram {
        switch programDefinition {
        case .Program(let functionDefintion):
            return AstTackyProgram.Program(
                functionDefinition: EmitTackyFunction(functionDefinition: functionDefintion))
        }
    }

    mutating func EmitTackyFunction(functionDefinition: AstFunctionDefinition) -> AstTackyFunction {
        switch functionDefinition {
        case .Function(let name, let statement):
            var instructions: [AstTackyInstruction] = []

            let lastInstruction = EmitTackyInstruction(
                statement: statement, instructions: &instructions)
            instructions.append(lastInstruction)
            return AstTackyFunction.Function(
                name: name, instructions: instructions)
        }
    }

    func ConvertUnaryOperator(op: AstUnaryOperator) -> AstTackyUnaryOperator {
        switch op {
        case .Complement:
            return AstTackyUnaryOperator.Complement
        case .Negate:
            return AstTackyUnaryOperator.Negate
        }
    }

    mutating func EmitTackyInstruction(
        statement: AstStatement, instructions: inout [AstTackyInstruction]
    ) -> AstTackyInstruction {
        switch statement {
        case .Return(let expression):
            let value = EmitTackyExpression(expr: expression, instructions: &instructions)
            return AstTackyInstruction.Return(value: value)
        }
    }

    mutating func EmitTackyExpression(
        expr: AstExpression, instructions: inout [AstTackyInstruction]
    )
        -> AstTackyValue
    {
        switch expr {
        case .Constant(let val):
            return AstTackyValue.Constant(value: val)
        case .Unary(let op, let expression):
            let src: AstTackyValue = EmitTackyExpression(
                expr: expression, instructions: &instructions)
            let destName = MakeTemporary()
            let dst = AstTackyValue.Var(identifier: destName)
            let tackyOp = ConvertUnaryOperator(op: op)
            instructions.append(
                AstTackyInstruction.Unary(unaryOperator: tackyOp, dest: dst, src: src))
            return dst
        case .Binary(let op, let left, let right):
            fatalError("TODO: Handle binary operators in tacky!")
        }
    }
}
