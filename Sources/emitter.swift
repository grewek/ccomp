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

    mutating func EmitFunctionDefinition(definition: AssemblyFunctionDefintion) {
        switch definition {
        case .FunctionDefinition(let name, let instructions):
            let nameLabel = "\(name):\n"
            output += nameLabel
            for instruction in instructions {
                EmitAssemblyInstructions(instruction: instruction)
            }
            break
        }
    }

    mutating func EmitAssemblyInstructions(instruction: AssemblyInstruction) {
        switch instruction {

        case .Move(let dest, let src):
            let moveInstruction = "\tmov \(dest.Display()), \(src.Display())\n"
            output += moveInstruction
        case .Ret:
            let retInstruction = "\tret\n"
            output += retInstruction
        }
    }
}
