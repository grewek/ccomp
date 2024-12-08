import Foundation

struct Emitter {
    var repr: AssemblyProgram
    var outputTarget: URL
    var output: String

    init(assembly: AssemblyProgram, path: String) {
        self.repr = assembly
        self.output = ""
        self.outputTarget = URL(filePath: path)
    }

    mutating func EmitProgram() {
        //TODO: Encode these in the Ast Assembly generation!
        self.output += "section .text\n"
        self.output += "global main\n"

        switch self.repr {
        case .Program(let definition):
            EmitFunctionDefinition(definition: definition)
            let stackProtection = "section .note.GNU-stack noexec"
            output += stackProtection
            break
        }

        try? output.write(
            to: outputTarget, atomically: true, encoding: String.Encoding.utf8)
    }

    func EmitAssemblyLabel(name: String) -> String {
        let nameLabel = "\(name):\n"
        return nameLabel
    }

    func EmitStackFrameEntry() -> String {
        let frameEntry = "\tpush rbp\n\tmov rbp, rsp\n"
        return frameEntry
    }

    func EmitStackFrameExit() -> String {
        let frameExit = "\tmov rbp, rsp\n\tpop rbp\n"
        return frameExit
    }

    func EmitStackFrameSize(size: Int) -> String {
        let frameSize = "\tsub rsp, \(size)\n"
        return frameSize
    }
    mutating func EmitFunctionDefinition(definition: AssemblyFunctionDefintion) {
        switch definition {
        case .FunctionDefinition(let name, let instructions):
            output += EmitAssemblyLabel(name: name)
            output += EmitStackFrameEntry()

            for instruction in instructions {
                EmitAssemblyInstructions(instruction: instruction)
            }
            break
        }
    }

    func EmitStackPosition(position: Int) -> String {
        //TODO: We either keep the position in negative and do an abs everywhere
        //or we store the value as a positive value...which sounds more sane
        return "dword [rbp - \(abs(position))]"
    }

    func EmitRegister(register: AssemblyRegister) -> String {
        switch register {
        case .Ax:
            return "eax"
        case .R10:
            return "r10d"
        case .Dx:
            return "edx"
        case .R11:
            return "r11d"
        }
    }

    func EmitUnaryOperation(op: AssemblyUnaryOperator, operand: AssemblyOperand) -> String {
        switch op {
        case .Neg:
            return "\tneg \(EmitOperand(operand: operand))\n"
        case .Not:
            return "\tnot \(EmitOperand(operand: operand))\n"
        }
    }

    func EmitBinaryOperation(
        op: AssemblyBinaryOperator, dest: AssemblyOperand, src: AssemblyOperand
    ) -> String {
        switch op {
        case .Add:
            return "\tadd \(EmitOperand(operand: dest)), \(EmitOperand(operand: src))\n"
        case .Sub:
            return "\tsub \(EmitOperand(operand: dest)), \(EmitOperand(operand: src))\n"
        case .Mult:
            return "\timul \(EmitOperand(operand: dest)), \(EmitOperand(operand: src))\n"
        }
    }

    func EmitOperand(operand: AssemblyOperand) -> String {
        switch operand {
        case .Immediate(let value):
            return "\(value)"
        case .Register(let register):
            return EmitRegister(register: register)
        case .Pseudo(_):
            fatalError("Found a pseudo register at emission phase")
            break
        case .Stack(let stack):
            return EmitStackPosition(position: stack)

        }
    }

    mutating func EmitAssemblyInstructions(instruction: AssemblyInstruction) {
        switch instruction {

        case .Move(let dest, let src):
            let moveInstruction =
                "\tmov \(EmitOperand(operand: dest)), \(EmitOperand(operand: src))\n"
            output += moveInstruction
        case .Unary(let op, let dest):
            //TODO: Fill this out!
            output += EmitUnaryOperation(op: op, operand: dest)
            break
        case .Binary(let operation, let dest, let src):
            let binaryInstruction = EmitBinaryOperation(op: operation, dest: dest, src: src)
            output += binaryInstruction
        case .Idiv(op: let arg):
            let divInstruction = "\tidiv \(EmitOperand(operand: arg))\n"
            output += divInstruction
        case .Cdq:
            let cdqInstruction = "\tcdq\n"
            output += cdqInstruction
        case .AllocateStack(let size):
            //TODO: Fill this out!
            output += EmitStackFrameSize(size: size)
            break
        case .Ret:
            output += EmitStackFrameExit()
            let retInstruction = "\tret\n"
            output += retInstruction
        }
    }
}
