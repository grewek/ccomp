# ccomp

My C Compiler for the dielectric_dreams CPU and x86_64 Intel, this project will be based on the book "Writing a C Compiler" by Nora Sandler.
Will be written in Swift want to see if the language has good enough linux support!

## Necessary Tools

To use this compiler for __x86_64__ you need the following things available on your system:

- NASM (For assembling the generated output)
- GCC (For linking with the c runtime library)

## Instructions

Currently the steps to obtaining a executable includes a bit of manual labor but nothing to horrorfying...

Compile any valid C-Program (In the boundaries of our currently supported subset)
then compile it with nasm:

```
nasm -felf64 ${name_of_output}.asm
```

This should give you a valid object file which then __must__ be linked with gcc like this (failure of doing so will result in a segfaulting binary!):

```
gcc -o ${name_of_executable} ${name_of_output}.o
```

where ${name_of_executable} is to be replaced with the actual output name

