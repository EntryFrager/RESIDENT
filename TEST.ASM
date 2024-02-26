.286
.model tiny
.code
org 100h


STOP_SYMBOL equ 1


Start:
		push cs
		pop dx

		Call DrawRegNumber
		
		mov bx, 1111h
		mov cx, 2222h
		mov dx, 3333h
		mov si, 4444h
	
	@@cycle:
		in al, 60h
		cmp al, STOP_SYMBOL
		jne @@cycle

		mov ax, 4c00h
		int 21h


DrawRegNumber	proc
		mov cx, 0								; reset the register

		mov cl, dh								; save dh

		shr cl, 4								; get the most significant digit of register dh
		Call DrawHexNumber

		mov cl, dh								; update the value
	
		and cl, 0Fh								; get the least significant bit of register dh
		Call DrawHexNumber

		mov cl, dl								; save dl

		shr cl, 4								; get the most significant digit of register dl
		Call DrawHexNumber

		mov cl, dl								; update the value

		and cl, 0Fh								; get the least significant bit of register dl
		Call DrawHexNumber
		
		ret
		endp


DrawHexNumber	proc
		push dx

		mov bx, offset hex_alphabet						; address per line with text representations of hexadecimal symbols
		
		add bx, cx								; get the text representation of the output character
		mov dl, cs:[bx]

		mov ah, 02h
		int 21h
		
		pop dx

		ret
		endp


.data


hex_alphabet db "0123456789ABCDEF"							; text representations of hexadecimal symbols


end	Start