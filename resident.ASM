.286
.model tiny
.code
org 100h


SAVE_REG_PUSH	macro									; macro that stores the values of all registers on the stack
		push ss es ds sp bp di si dx cx bx ax

		endm


SAVE_REG_POP	macro									; macro that returns registers to their stored values
		pop ax bx cx dx si di bp sp ds es ss

		endm


PUSH_ALL_REG	macro									; macro that pushes the values of all registers onto the stack
		push cs ss es ds sp bp di si dx cx bx ax

		endm 


ADD_2		macro t:REQ								; macro that increments a number by 2
		inc t									; 2 * inc ... is faster than add ..., 2
		inc t

		endm


VIDEO_PTR 	equ 0b800h								; Contains video memory address

START_SYMBOL 	equ 09d									; '8'
STOP_SYMBOL 	equ 10d									; '9'

X0 equ 10d			                  					; Initial x-coordinate of the left corner of the frame
Y0 equ 05d			                  					; Initial y-coordinate of the left corner of the frame

WIDTH_FRAME  equ 09d                							; Frame width
HEIGHT_FRAME equ 14d                							; Frame height

COLOR equ 0Ch                       							; Frame color

WIDTH_WINDOW equ 80d									; Window width

COUNT_REG equ 12d									; Number of registers


Start:
		Call Main


Main	proc
		Call InitInterrupt							; call a function that replaces the interrupt

;;-----------------Terminate and stay resident--------------------------

		mov dx, offset EndOfProgramm						; get the address of the end of the program
		shr dx, 4								; 2^4 = 16 = paragraph length
		inc dx									; + 1, beacuse so that it's definitely enough

		mov ax, 3100h								; terminate and stay resident
		int 21h

		ret
		endp


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; Function that replaces the system interrupt
; Info:
;	Old09Ofs - stores system function offset 09h
;	Old09Seg - stores system function segment 09h
;	Old08Ofs - stores system function offset 09h
;	Old08Seg - stores system function segment 08h
; Destr:
; 	AX
; 	BX
; 	DX
; 	ES
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


InitInterrupt	proc

;;-----------------------------09-Interrupt-----------------------------

		mov ax, 3509h
		int 21h
		mov Old09Ofs, bx							;
		mov bx, es								; save segment and offset for old addres for 09h interrupt
		mov Old09Seg, bx							;

		push 0
		pop es									; es = 0 - system interrupt address

		mov bx, 4 * 09h								; 09h = interrupt addres
											; 4 because offset = 2 byte and segment = 2 byte

		cli									; disable interrupts

		mov es:[bx], offset FrameInterruptFunc					; new interrupt address (offset)

		push cs
		pop ax									; get a segment of our code

		mov es:[bx + 2], ax							; write the segment after the offset (offset = 2 byte)

		sti									; enable interrupts

;;-----------------------------08-Interrupt-----------------------------

		mov ax, 3508h
		int 21h
		mov Old08Ofs, bx							;
		mov bx, es								; save segment and offset for old addres for 09h interrupt
		mov Old08Seg, bx							;

		push 0
		pop es									; es = 0 - system interrupt address

		mov bx, 4 * 08h								; 09h = interrupt addres
											; 4 because offset = 2 byte and segment = 2 byte

		cli									; disable interrupts

		mov es:[bx], offset TimerInterruptFunc					; new interrupt address (offset)

		push cs									; get a segment of our code
		pop ax

		mov es:[bx + 2], ax							; write the segment after the offset (offset = 2 byte)

		sti									; enable interrupts

		ret
		endp


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; Our function replacing interrupt 09h
; Info:
;	reg_flag - register update flag
;	START_SYMBOL - scan code of the starting symbol
;	STOP_SYMBOL - scan code of the stop character to stop register updating
; Destr:
;	AX
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


FrameInterruptFunc	proc
		push ax

		in al, 60h								; get the scan code of the entered character
		
		cmp al, START_SYMBOL							; compare it with the start character to start drawing the frame
		jne @@not_start_symbol

		mov reg_flag, 1								; set the register update flag to 1
		Call InitFrame								; Drawing a frame

		jmp @@status_keyboard

	@@not_start_symbol:

		cmp al, STOP_SYMBOL							; compare the scan code with the stop symbol
		jne @@not_stop_symbol

		mov reg_flag, 0								; set the register update flag to 0

	@@status_keyboard:

		in al, 61h								; get status of keyboard
		or al, 80h								; 1000 0000b (1 - disable keyboard)
		out 61h, al								; put the value back

		and al, not 80h								; 0111 1111b (0 - enable keyboard)
		out 61h, al								; put the value back

		mov al, 20h								; 20h = 001 = End Of Interrupt
		out 20h, al								

		pop ax

		iret									; returns IP, CS and flags from the stack

	@@not_stop_symbol:

		pop ax

		db 0EAh									; long jump Old09Seg:[Old09Ofs]
	Old09Ofs dw 0									; give control to the system interrupt
	Old09Seg dw 0
		
		endp


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; Our function replacing interrupt 08h
; Info:
;	reg_flag - register update flag
; Destr:
;	SP
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


TimerInterruptFunc	proc
		cmp reg_flag, 1								; push all registersя
		jne @@dont_draw_reg

		PUSH_ALL_REG								; push all registers

		Call DrawRegisterValue							; drawing register values

		SAVE_REG_POP								; return saved register values

		ADD_2 sp

	@@dont_draw_reg:
		db 0EAh									; long jump Old08Seg:[Old08Ofs]
	Old08Ofs dw 0									; give control to the system interrupt
	Old08Seg dw 0

		endp


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; A function that specifies the basic parameters of the frame
; Info:
;	AH - stores the color value
;	BX - address on frame outline symbols
;	ES - video memory address where we will draw the frame
;	DI - video memory offset
;	COLOR - color meaning
; Destr:
;	AH
;	BX
;	ES
;	DI
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


InitFrame	proc
		SAVE_REG_PUSH

      		mov ah, COLOR								; color value
		push VIDEO_PTR
		pop es									; video memory segment
		mov di, 0								; initial offset
		mov bx, offset CONTROL_STR_ARRAY					; address to a string storing frame outline characters

      		Call DrawFrame								; draw a frame

		SAVE_REG_POP
      ret
      endp


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; Drawing a frame
; Entry:
;	AH - color attr
; 	AL - symbol
; 	BX - pointer to string
; 	CX - number of lines
; 	DI - offset to mem
; Info:
; 	X0 - the initial x-coordinate of the left corner of the frame
; 	Y0 - the initial y-coordinate of the left corner of the frame
; 	WIDTH_FRAME - frame width
; 	HEIGHT_FRAME - frame height
; 	WIDTH_WINDOW - window width
; Assum:
;	ES = 0b800h
; Destr: 
; 	BX
; 	CX
; 	DI
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


DrawFrame	proc
		Call DrawLine								; Drawing the first line		
		Call MoveLine

		mov cx, HEIGHT_FRAME
		sub cx, 02d								; Number of center lines
		add bx, 03d

	@@y1_to_y2:									; Drawing the center lines
		sub bx, 03d

		mov bp, cx
		Call DrawLine
		Call MoveLine
		mov cx, bp

		loop @@y1_to_y2

		Call DrawLine								; Drawing the last line

		Call DrawRegisterLine							; Drawing name register
		
		ret
		endp


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; Writes a string to video mem
; Entry:
;	AH - color attr
; 	BX - pointer to string
; 	DI - offset to mem
; Info:
; 	AL - symbol
; 	WIDTH_FRAME - frame width
; Assum:	
;	ES = 0b800h
; Destr: 
;	AX
; 	BX
; 	CX
; 	DI
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


DrawLine	proc
		mov al, cs:[bx]
		Stosw			            					; Print first symbol

		inc bx
		mov al, cs:[bx]
		mov cx, WIDTH_FRAME
		sub cx, 02d

		rep Stosw		         					; Print second symbol

		inc bx
		mov al, cs:[bx]
		Stosw			           					; Print third symbol
		
		inc bx

		ret
		endp


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; Calculating the address of the beginning of a new frame line
; Entry: 
;	AH - color attr
; 	AL - symbol	
;	DI - offset to mem
; Info:
; 	WIDTH_FRAME - frame width
; 	WIDTH_WINDOW - window width
; Destr: 
;	CX
; 	DI
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


MoveLine	proc
		mov cx, WIDTH_WINDOW
		
		sub cx, WIDTH_FRAME							; We count the coordinates of the beginning of a new line
		shl cx, 1								; (WIDTH_WINDOW - WIDTH_FRAME) * 2 + di
		add di, cx

		ret
		endp


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; A function that draws the names of all registers
; Info:
;	BX - address to register names written without a space
;	CX - number of registers (COUNT_RET)
;	DI - video memory offset
;	WIDTH_WINDOW - window width
; Assum:	
;	ES = 0b800h
; Destr:
;	BX
;	CX
;	DI
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


DrawRegisterLine	proc
		mov bx, offset text_register						; write the address to the names of all registers written sequentially, without spaces
		mov di, (WIDTH_WINDOW + 1) * 2						; initial offset
		mov cx, COUNT_REG							; write down the number of registers

	@@y1_to_y2_reg:									; display the names of all registers

		push cx									; save cx
		Call DrawNameRegister							; drawing the name of one register
		pop cx									; return cx
		
		add di, (WIDTH_WINDOW - 3) * 2						; go to the next line

		loop @@y1_to_y2_reg

		ret
		endp


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; A function that draws the name of a single register
; Entry:
;	BX - address to register names written without a space
;	CS - code segment
;	DI - video memory offset
; Info:
;	AL - output character
;	CX - register name length
; Assum:	
;	ES = 0b800h
; Destr:
;	AL
;	BX
;	CX
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


DrawNameRegister	proc
		mov cx, 2								; write down the length of the register name

	@@x1_to_x2_reg:									; display the register name character by character

		mov al, cs:[bx]
		Stosw
		inc bx

		loop @@x1_to_x2_reg

		mov al, '='								; output equal to
		Stosw

		ret
		endp


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; Function that prints the values ​​of all registers
; Info:
;	CX - number of registers (COUNT_RET)
;	BP - address to register values ​​on the stack
;	DI - video memory offset
;	ES - video memory segment
; Destr:
;	CX
;	BP
;	DI
;	ES
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


DrawRegisterValue	proc
		push VIDEO_PTR								; write address on video memory
		pop es
		
		mov di, (WIDTH_WINDOW + 4) * 2						; write down the initial offset
		mov cx, COUNT_REG							; save the number of registers
		
		push sp
		pop bp
		add bp, 2								; write the address pointing to the register values ​​on the stack

	@@y1_to_y2_value_reg:								; display the value of all registers

		mov dx, [bp]								; get the register value from the stack

		push cx									; save cx
		Call DrawRegNumber							; call a function that prints the value of one register
		pop cx									; return cx

		add di, (WIDTH_WINDOW - 4) * 2						; go to new line

		ADD_2 bp

		loop @@y1_to_y2_value_reg

		ret
		endp


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; Function that prints the value of one register
; Entry:
;	DX - stores the value of the output register
;	DI - video memory offset
; Info:
;	AH - stores the color value
; Assum:	
;	ES = 0b800h
; Destr:
;	AH
;	CX
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


DrawRegNumber	proc
		mov cx, 0								; reset the register
		mov ah, COLOR								; color value

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


;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; Function that prints a hexadecimal number symbol
; Entry:
;	CX - output number
;	DI - video memory offset
; Info:
;	AL - output character
;	BX - address per line with text representations of hexadecimal symbols
; Assum:	
;	ES = 0b800h
; Destr:
;	BX
;;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


DrawHexNumber	proc
		mov bx, offset hex_alphabet						; address per line with text representations of hexadecimal symbols
		
		add bx, cx								; get the text representation of the output character
		mov al, cs:[bx]

		Stosw									; display the symbol

		ret
		endp


.data


text_register db "axbxcxdxsidibpspdsessscs"						; register names written sequentially, without spaces

hex_alphabet db "0123456789ABCDEF"							; text representations of hexadecimal symbols

reg_flag db 0										; flag responsible for updating registers (1 - enable, 0 - disable)

CONTROL_STR_ARRAY db " "				


EndOfProgramm:


end	Start