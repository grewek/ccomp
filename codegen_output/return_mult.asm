section .text
global main
main:
	push rbp
	mov rbp, rsp
	sub rsp, 24
	mov dword [rbp - 4], 2
	mov r11d, dword [rbp - 4]
	imul r11d, 3
	mov dword [rbp - 4], r11d
	mov eax, dword [rbp - 4]
	mov rsp, rbp
	pop rbp
	ret
section .note.GNU-stack noexec