.286
.model tiny
.code
org 100h

Start:
		Call Main


Main	proc
		mov ax, 4c00h
	again:
		mov bx, 1111h
		mov cx, 2222h
		mov dx, 3333h
		mov si, 4444h
		cmp ax, 4c00h
		je again
		
		ret
		endp


end	Start