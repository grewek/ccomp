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
    case Binary(binOp: AssemblyBinaryOperator, dest: AssemblyOperand, src: AssemblyOperand)
    case Idiv(op: AssemblyOperand)
    case Cdq
    case AllocateStack(size: Int)
    case Ret

    func Display() -> String {
        switch self {

        case .Move(let dest, let src):
            return "\tMove(\(dest.Display()), \(src.Display()))\n"
        case .Unary(let op, let operand):
            return "\tUnary(\(op.Display()),\(operand.Display()))\n"
        case .Binary(let binOp, let dest, let src):
            return "\tBinary(\(binOp.Display()), \(dest.Display()), \(src.Display()))\n"
        case .Idiv(let op):
            return "\tidiv(\(op.Display()))\n"
        case .Cdq:
            return "\tcdq\n"
        case .AllocateStack(let size):
            return "\tStackSize(\(size))\n"
        case .Ret:
            return "\tReturn\n"
        }
    }
}

enum AssemblyBinaryOperator {
    case Add
    case Sub
    case Mult

    func Display() -> String {
        switch self {
        case .Add:
            return "add"
        case .Sub:
            return "sub"
        case .Mult:
            return "imul"
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
    case Dx
    case R10
    case R11

    func Display() -> String {
        switch self {
        case .Ax:
            return "eax"
        case .Dx:
            return "edx"
        case .R10:
            return "r10d"
        case .R11:
            return "r11d"
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
        let stackWaterMark = abs(self.stackWaterMark)
        let stackSize = (stackWaterMark + 4) + ((stackWaterMark + 4) % 16)
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
                    case .Move(AssemblyOperand.Stack(let dest), AssemblyOperand.Stack(let src)):
                        let generatedInstructions = RewriteIllegalStackInstruction(
                            srcValue: src, destValue: dest)
                        result.append(contentsOf: generatedInstructions)
                    case .Idiv(let assemblyOperand):
                        let generatedInstructions = RewriteIllegalIdivInstruction(
                            immediateValue: assemblyOperand)
                        result.append(contentsOf: generatedInstructions)
                    case .Binary(
                        binOp: AssemblyBinaryOperator.Add,
                        dest: AssemblyOperand.Stack(value: let stackDest),
                        src: AssemblyOperand.Stack(value: let stackSrc)):
                        let generatedInstructions = RewriteIllegalAddSubInstruction(
                            binOp: AssemblyBinaryOperator.Add,
                            dest: stackDest, src: stackSrc)
                        result.append(contentsOf: generatedInstructions)
                    case .Binary(
                        binOp: AssemblyBinaryOperator.Sub,
                        dest: AssemblyOperand.Stack(value: let stackDest),
                        src: AssemblyOperand.Stack(value: let stackSrc)):
                        let generatedInstruction = RewriteIllegalAddSubInstruction(
                            binOp: AssemblyBinaryOperator.Sub, dest: stackDest, src: stackSrc)
                        result.append(contentsOf: generatedInstruction)
                    case .Binary(
                        binOp: AssemblyBinaryOperator.Mult,
                        dest: AssemblyOperand.Stack(value: let stackDest), let src):
                        let generatedInstruction = RewriteIllegalMultInstruction(
                            dest: stackDest, src: src)
                        result.append(contentsOf: generatedInstruction)
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

    func RewriteIllegalIdivInstruction(immediateValue: AssemblyOperand) -> [AssemblyInstruction] {
        [
            AssemblyInstruction.Move(
                dest: AssemblyOperand.Register(register: AssemblyRegister.R10), src: immediateValue),
            AssemblyInstruction.Idiv(op: AssemblyOperand.Register(register: AssemblyRegister.R10)),
        ]
    }

    func RewriteIllegalAddSubInstruction(binOp: AssemblyBinaryOperator, dest: Int, src: Int)
        -> [AssemblyInstruction]
    {
        [
            AssemblyInstruction.Move(
                dest: AssemblyOperand.Register(register: AssemblyRegister.R10),
                src: AssemblyOperand.Stack(value: src)),
            AssemblyInstruction.Binary(
                binOp: binOp, dest: AssemblyOperand.Stack(value: dest),
                src: AssemblyOperand.Register(register: AssemblyRegister.R10)),
        ]
    }

    func RewriteIllegalMultInstruction(dest: Int, src: AssemblyOperand) -> [AssemblyInstruction] {
        [
            AssemblyInstruction.Move(
                dest: AssemblyOperand.Register(register: AssemblyRegister.R11),
                src: AssemblyOperand.Stack(value: dest)),
            AssemblyInstruction.Binary(
                binOp: AssemblyBinaryOperator.Mult,
                dest: AssemblyOperand.Register(register: AssemblyRegister.R11),
                src: src),
            AssemblyInstruction.Move(
                dest: AssemblyOperand.Stack(value: dest),
                src: AssemblyOperand.Register(register: AssemblyRegister.R11)),
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

    //TODO: Things are getting messy >_< time for a refactor i think...
    mutating func ReplacePseudo(instruction: AssemblyInstruction) -> AssemblyInstruction {
        switch instruction {
        case .Move(
            AssemblyOperand.Pseudo(let pseudoDestName), AssemblyOperand.Pseudo(let pseudoSrcName)):
            let watermarkDest = InsertPseudoRegister(name: pseudoDestName)
            let watermarkSrc = InsertPseudoRegister(name: pseudoSrcName)
            return AssemblyInstruction.Move(
                dest: AssemblyOperand.Stack(value: watermarkDest),
                src: AssemblyOperand.Stack(value: watermarkSrc))
        case .Move(AssemblyOperand.Pseudo(let pseudoRegName), let src):
            let watermark = InsertPseudoRegister(name: pseudoRegName)
            return AssemblyInstruction.Move(
                dest: AssemblyOperand.Stack(value: watermark),
                src: src)
        case .Move(let dest, AssemblyOperand.Pseudo(let pseudoRegName)):
            let watermark = InsertPseudoRegister(name: pseudoRegName)
            return AssemblyInstruction.Move(
                dest: dest,
                src: AssemblyOperand.Stack(value: watermark))
        case .AllocateStack(_):
            fatalError(
                "ERROR: AllocateStack is not possible yet as we don't know the absolute stack size yet!"
            )
        case .Unary(operator: let op, operand: AssemblyOperand.Pseudo(let pseudoRegName)):
            let watermark = InsertPseudoRegister(name: pseudoRegName)
            return AssemblyInstruction.Unary(
                operator: op, operand: AssemblyOperand.Stack(value: watermark))
        case .Binary(
            binOp: let op, dest: AssemblyOperand.Pseudo(let psuedoDest),
            src: AssemblyOperand.Pseudo(let psuedoSrc)):
            let watermarkDest = InsertPseudoRegister(name: psuedoDest)
            let watermarkSrc = InsertPseudoRegister(name: psuedoSrc)
            return AssemblyInstruction.Binary(
                binOp: op, dest: AssemblyOperand.Stack(value: watermarkDest),
                src: AssemblyOperand.Stack(value: watermarkSrc))
        case .Binary(binOp: let op, dest: AssemblyOperand.Pseudo(let psuedoDest), let src):
            let watermark = InsertPseudoRegister(name: psuedoDest)
            return AssemblyInstruction.Binary(
                binOp: op,
                dest: AssemblyOperand.Stack(value: watermark),
                src: src)
        case .Binary(binOp: let op, let dest, src: AssemblyOperand.Pseudo(let psuedoSrc)):
            let watermark = InsertPseudoRegister(name: psuedoSrc)
            return AssemblyInstruction.Binary(
                binOp: op,
                dest: dest,
                src: AssemblyOperand.Stack(value: watermark))
        case .Idiv(op: AssemblyOperand.Pseudo(let registerName)):
            let watermark = InsertPseudoRegister(name: registerName)
            return AssemblyInstruction.Idiv(op: AssemblyOperand.Stack(value: watermark))

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
            case .Return(AstTackyValue.Constant(let value)):
                result.append(
                    AssemblyInstruction.Move(
                        dest: AssemblyOperand.Register(register: AssemblyRegister.Ax),
                        src: AssemblyOperand.Immediate(value: value)))
                result.append(AssemblyInstruction.Ret)
                break
            case .Return(AstTackyValue.Var(let identifier)):
                result.append(
                    AssemblyInstruction.Move(
                        dest: AssemblyOperand.Register(register: AssemblyRegister.Ax),
                        src: AssemblyOperand.Pseudo(identifier: identifier)))
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
            case .Binary(binaryOperator: AstTackyBinaryOperator.Divide, let opA, let opB, let dest):
                //TODO: Handle me!
                let quotient = GenerateAssemblyOperand(operand: opA)
                let dividend = GenerateAssemblyOperand(operand: opB)
                let dest = GenerateAssemblyOperand(operand: dest)
                result.append(
                    AssemblyInstruction.Move(
                        dest: AssemblyOperand.Register(register: AssemblyRegister.Ax),
                        src: quotient))
                result.append(AssemblyInstruction.Cdq)
                result.append(AssemblyInstruction.Idiv(op: dividend))
                result.append(
                    AssemblyInstruction.Move(
                        dest: dest,
                        src: AssemblyOperand.Register(register: AssemblyRegister.Ax)))
                break
            case .Binary(
                binaryOperator: AstTackyBinaryOperator.Remainder, let opA, let opB, let dest):
                //TODO: The code is confusing dest with src this needs to be fixed next!
                let quotient = GenerateAssemblyOperand(operand: opA)
                let dividend = GenerateAssemblyOperand(operand: opB)
                let dest = GenerateAssemblyOperand(operand: dest)
                result.append(
                    AssemblyInstruction.Move(
                        dest: AssemblyOperand.Register(register: AssemblyRegister.Ax),
                        src: quotient))
                result.append(AssemblyInstruction.Cdq)
                result.append(AssemblyInstruction.Idiv(op: dividend))
                result.append(
                    AssemblyInstruction.Move(
                        dest: dest,
                        src: AssemblyOperand.Register(register: AssemblyRegister.Dx)))
                break
            case .Binary(let op, let argA, let argB, let dest):
                let op = GenerateAssemblyBinaryOperator(operand: op)
                let argA = GenerateAssemblyOperand(operand: argA)
                let argB = GenerateAssemblyOperand(operand: argB)
                let dest = GenerateAssemblyOperand(operand: dest)

                result.append(AssemblyInstruction.Move(dest: dest, src: argA))
                result.append(AssemblyInstruction.Binary(binOp: op, dest: dest, src: argB))
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

    func GenerateAssemblyBinaryOperator(operand: AstTackyBinaryOperator) -> AssemblyBinaryOperator {
        switch operand {
        case .Multiply:
            return .Mult
        case .Add:
            return .Add
        case .Subtract:
            return .Sub
        default:
            fatalError("ERROR: GenerateAssemblyBinaryOperator Cannot handle DIV/REM")
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
