section .text
global main
main:
	push rbp
	mov rbp, rsp
	sub rsp, 16
	mov eax, 0
	mov rsp, rbp
	pop rbp
	ret
section .note.GNU-stack noexec