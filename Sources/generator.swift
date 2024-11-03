enum AssemblyProgram {
    case Program(definition: AssemblyFunctionDefintion)

    func Display() -> String {
        switch self {

        case .Program(let definition):
            return "(Definition(\(definition.Display())))"
        }
    }
}

enum AssemblyFunctionDefintion {
    case FunctionDefinition(name: String, instructions: [AssemblyInstruction])

    func Display() -> String {
        switch self {

        case .FunctionDefinition(let name, let instructions):
            var result = "\nname: \(name)\nbody: [\n"
            for instruction in instructions {
                result += instruction.Display()
            }
            return result
        }
    }
}

enum AssemblyInstruction {
    case Move(dest: AssemblyOperand, src: AssemblyOperand)
    case Ret

    func Display() -> String {
        switch self {

        case .Move(let dest, let src):
            return "\tmov \(dest.Display()), \(src.Display())\n"
        case .Ret:
            return "\tret\n"
        }
    }
}

enum AssemblyOperand {
    case Immediate(value: Int)
    case Register

    func Display() -> String {
        switch self {

        case .Immediate(let value):
            return "\(value)"
        case .Register:
            return "eax"
        }
    }
}

struct Generator {
    var ast: AstProgram

    func GenerateAssembly() -> AssemblyProgram {
        switch self.ast {
        case .Program(let function):
            return AssemblyProgram.Program(definition: GenerateFunction(function))
        }
    }

    func GenerateFunction(_ definition: AstFunctionDefinition) -> AssemblyFunctionDefintion {
        switch definition {

        case .Function(let identifier, let statement):
            return AssemblyFunctionDefintion.FunctionDefinition(
                name: identifier, instructions: GenerateInstructions(statement))
        }
    }

    func GenerateInstructions(_ statement: AstStatement) -> [AssemblyInstruction] {
        var result: [AssemblyInstruction] = []

        switch statement {

        case .Return(let expression):
            let returnValue = ConstantValue(expression)
            result.append(
                AssemblyInstruction.Move(
                    dest: AssemblyOperand.Register,
                    src: AssemblyOperand.Immediate(value: returnValue)))
            result.append(AssemblyInstruction.Ret)
            break
        }

        return result
    }

    func ConstantValue(_ expression: AstExpression) -> Int {
        switch expression {

        case .Constant(let value):
            return value
        }
    }
}
