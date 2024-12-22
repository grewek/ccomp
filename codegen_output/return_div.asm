section .text
global main
main:
	push rbp
	mov rbp, rsp
	sub rsp, 24
	mov eax, 3
	cdq
	mov r10d, 3
	idiv r10d
	mov dword [rbp - 4], eax
	mov eax, dword [rbp - 4]
	mov rsp, rbp
	pop rbp
	ret
section .note.GNU-stack noexec