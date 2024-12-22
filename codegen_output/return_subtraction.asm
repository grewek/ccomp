section .text
global main
main:
	push rbp
	mov rbp, rsp
	sub rsp, 24
	mov dword [rbp - 4], 4
	sub dword [rbp - 4], 3
	mov eax, dword [rbp - 4]
	mov rsp, rbp
	pop rbp
	ret
section .note.GNU-stack noexec