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
    //TODO: case AllocateStack(value: Int)
    case Unary(operator: AssemblyUnaryOperator, operand: AssemblyOperand)
    case AllocateStack(size: Int)
    case Ret

    func Display() -> String {
        switch self {

        case .Move(let dest, let src):
            return "\tMove(\(dest.Display()), \(src.Display()))\n"
        case .Unary(let op, let operand):
            return "\tUnary(\(op.Display()),\(operand.Display()))\n"
        case .AllocateStack(let size):
            return "\tStackSize(\(size))\n"
        case .Ret:
            return "\tReturn\n"
        }
    }
}

enum AssemblyUnaryOperator {
    case Neg
    case Not

    func Display() -> String {
        switch self {
        case .Neg:
            return "neg"
        case .Not:
            return "not"
        }
    }
}
enum AssemblyOperand {
    case Immediate(value: Int)
    case Register(register: AssemblyRegister)
    case Pseudo(identifier: String)
    case Stack(value: Int)

    func Display() -> String {
        switch self {
        case .Immediate(let value):
            return "Imm(\(value))"
        case .Register(let register):
            return "Reg(\(register.Display())"
        case .Pseudo(let identifier):
            return "Pseudo(\(identifier))"
        case .Stack(let value):
            return "Stack(\(value))"
        }
    }
}

enum AssemblyRegister {
    case Ax
    case R10

    func Display() -> String {
        switch self {
        case .Ax:
            return "eax"
        case .R10:
            return "r10d"
        }
    }
}

struct Generator {
    var ast: AstTackyProgram
    var stackWaterMark: Int = -4
    var localPseudoRegisters: [String: Int] = [:]

    mutating func GenerateAssembly() -> AssemblyProgram {
        var firstPass: AssemblyProgram
        switch self.ast {
        case .Program(let function):
            firstPass = AssemblyProgram.Program(definition: GenerateFunction(function))
        }

        return AssemblyProgram.Program(
            definition: ReplaceInstructionsWithPseudoValues(repr: &firstPass))

    }

    func GetLocalStackSize() -> Int {
        //NOTE: We convert the stack size back into a positive value as we
        //need to generate a positive value in the emitted subtraction
        //if it would be negative at this point the stack would shrink not grow
        //which is definitly not what we want!
        let stackSize = abs(self.stackWaterMark + 4)
        return stackSize
    }
    mutating func ReplaceInstructionsWithPseudoValues(repr: inout AssemblyProgram)
        -> AssemblyFunctionDefintion
    {
        var newName = ""
        var result: [AssemblyInstruction] = []
        switch repr {
        case .Program(let definition):
            switch definition {
            case .FunctionDefinition(let name, let instructions):
                newName = name
                for instruction in instructions {
                    //TODO: Can we mutate in place instead of generating a new list?
                    let generatedInstruction = ReplacePseudo(instruction: instruction)

                    switch generatedInstruction {
                    case .Move(AssemblyOperand.Stack(let src), AssemblyOperand.Stack(let dest)):
                        let generatedInstructions = RewriteIllegalStackInstruction(
                            srcValue: src, destValue: dest)
                        result.append(contentsOf: generatedInstructions)
                    default:
                        result.append(generatedInstruction)
                    }
                }

                result.insert(
                    AssemblyInstruction.AllocateStack(size: GetLocalStackSize()), at: 0)
            }
        }
        return AssemblyFunctionDefintion.FunctionDefinition(name: newName, instructions: result)
    }

    func RewriteIllegalStackInstruction(srcValue: Int, destValue: Int) -> [AssemblyInstruction] {
        [
            AssemblyInstruction.Move(
                dest: AssemblyOperand.Register(register: AssemblyRegister.R10),
                src: AssemblyOperand.Stack(value: srcValue)),
            AssemblyInstruction.Move(
                dest: AssemblyOperand.Stack(value: destValue),
                src: AssemblyOperand.Register(register: AssemblyRegister.R10)),
        ]
    }

    mutating func InsertPseudoRegister(name: String) -> Int {
        if self.localPseudoRegisters[name] == nil {
            let waterMark = stackWaterMark
            stackWaterMark -= 4

            self.localPseudoRegisters[name] = waterMark
        }

        return self.localPseudoRegisters[name]!
    }

    mutating func ReplacePseudo(instruction: AssemblyInstruction) -> AssemblyInstruction {
        switch instruction {
        case .Move(
            AssemblyOperand.Pseudo(let pseudoDestName), AssemblyOperand.Pseudo(let pseudoSrcName)):
            let waterMarkDest = InsertPseudoRegister(name: pseudoDestName)
            let waterMarkSrc = InsertPseudoRegister(name: pseudoSrcName)
            return AssemblyInstruction.Move(
                dest: AssemblyOperand.Stack(value: waterMarkDest),
                src: AssemblyOperand.Stack(value: waterMarkSrc))
        case .Move(AssemblyOperand.Pseudo(let pseudoRegName), let src):
            let waterMark = InsertPseudoRegister(name: pseudoRegName)
            return AssemblyInstruction.Move(
                dest: AssemblyOperand.Stack(value: waterMark),
                src: src)
        case .Move(let dest, AssemblyOperand.Pseudo(let pseudoRegName)):
            let waterMark = InsertPseudoRegister(name: pseudoRegName)
            return AssemblyInstruction.Move(
                dest: dest,
                src: AssemblyOperand.Stack(value: waterMark))
        case .AllocateStack(_):
            fatalError(
                "ERROR: AllocateStack is not possible yet as we don't know the absolute stack size yet!"
            )
        case .Unary(operator: let op, operand: AssemblyOperand.Pseudo(let pseudoRegName)):
            let waterMark = InsertPseudoRegister(name: pseudoRegName)
            return AssemblyInstruction.Unary(
                operator: op, operand: AssemblyOperand.Stack(value: waterMark))
        default:
            break
        }

        return instruction
    }

    func GenerateFunction(_ definition: AstTackyFunction) -> AssemblyFunctionDefintion {
        switch definition {

        case .Function(let identifier, let statement):
            return AssemblyFunctionDefintion.FunctionDefinition(
                name: identifier, instructions: GenerateInstructions(statement))
        }
    }

    func GenerateInstructions(_ statements: [AstTackyInstruction]) -> [AssemblyInstruction] {
        var result: [AssemblyInstruction] = []

        for statement in statements {
            switch statement {
            case .Return(let expression):
                let returnValue = ConstantValue(expression)
                result.append(
                    AssemblyInstruction.Move(
                        dest: AssemblyOperand.Register(register: AssemblyRegister.Ax),
                        src: AssemblyOperand.Immediate(value: returnValue)))
                result.append(AssemblyInstruction.Ret)
                break
            case .Unary(let op, let dest, let src):
                let convertedOperator = GenerateAssemblyOperator(operand: op)
                let destOperand = GenerateAssemblyOperand(operand: dest)
                let srcOperand = GenerateAssemblyOperand(operand: src)
                result.append(
                    AssemblyInstruction.Move(
                        dest: destOperand,
                        src: srcOperand))
                result.append(
                    AssemblyInstruction.Unary(operator: convertedOperator, operand: destOperand))
                break
            }
        }

        return result
    }

    func GenerateAssemblyOperand(operand: AstTackyValue) -> AssemblyOperand {
        switch operand {
        case .Constant(let value):
            return AssemblyOperand.Immediate(value: value)
        case .Var(let identifier):
            return AssemblyOperand.Pseudo(identifier: identifier)
        }
    }

    func GenerateAssemblyOperator(operand: AstTackyUnaryOperator) -> AssemblyUnaryOperator {
        switch operand {
        case .Complement:
            return .Not
        case .Negate:
            return .Neg
        }
    }

    //TODO: Is this still a necessary function? Can we delete it?
    func ConstantValue(_ expression: AstTackyValue) -> Int {
        switch expression {

        case .Constant(let value):
            return value

        case .Var(_):
            //TODO: This is a standin value to make the error go away for now!
            return 1
        }
    }
}
