section .text
global main
main:
	push rbp
	mov rbp, rsp
	sub rsp, 24
	mov dword [rbp - 4], 1
	add dword [rbp - 4], 1
	mov eax, dword [rbp - 4]
	mov rsp, rbp
	pop rbp
	ret
section .note.GNU-stack noexec
