;              rax ; rdi  ; rsi  ; rdx   ; returns
%define READ   0x0 ; fd   ; buff ; count 
%define WRITE  0x1 ; fd   ; buff ; count 

%define STDIN  0x0
%define STDOUT 0x1

%define TRUE  1
%define FALSE 0

section 	.data
nline 	db 	0xA
truet 	db  "TRUE",0xA
falst 	db  "FALSE",0xA

section 	.text
extern  	heap_init
extern  	heap_allocate
extern  	heap_free

extern  	memcpy
extern 		memset
extern	 	memcmp

global  	std_print_dnum
global  	std_print_xnum
global 		std_print_bool
global 		std_print_str
global 		std_get_str

global  	std_strlen
global 		std_reverse

;dla should be generalized with template implemented via macro

global  	std_dla_16B_create
global  	std_dla_16B_destroy 
global  	std_dla_16B_push
global  	std_dla_16B_pop
global  	std_dla_16B_get
global   	std_dla_16B_get_size

global  	nline

; decimal number to print in rsi
std_print_dnum:
	push 	rbx

	mov 	rax, rdi ; because div uses rax
	mov 	rcx, 0xA ; used to divide
	
	;add '\n' 
	dec 	rsp
	mov 	BYTE [rsp], 0xA 
	mov 	rbx, 0x1        ; at the end used to know how many chars

	;while number is not zero, push its last digit to stack
std_pdn_loop:
	;set rdx to 0 since we dont want garbage to interfere
	xor 	rdx, rdx
	; divides contents of rdx:rax
	div 	rcx ; rax quotient ; rdx remainder
	
	inc 	rbx

	add 	dl, 0x30 ; we only care about last byte 
	;manual push
	dec 	rsp
	mov 	BYTE [rsp], dl
	
	;if number is not zero, repeat
	cmp 	rax, 0x0
	jne 	std_pdn_loop
	
	mov 	rax, WRITE
	mov 	rdi, STDOUT
	mov 	rsi, rsp
	mov 	rdx, rbx
	syscall
	
	;clear stack
	add 	rsp, rbx

	pop 	rbx
	ret

;takes hexadecimal number in rdi
std_print_xnum:
	push 	rbx
	
	;add '\n' 
	dec 	rsp
	mov 	BYTE [rsp], 0xA 
	mov 	rbx, 0x1        ; at the end used to know how many chars
	
std_pxn_num:
	inc 	rbx
	mov 	cl, dil
	and 	cl, 0xF
	shr 	rdi, 0x4

;if less than 10, add decimal digit
	cmp 	cl, 0xA
	jge 	std_pxn_add_hex
	
	add 	cl, '0' 
	dec 	rsp
	mov 	BYTE [rsp], cl 
	
	jmp 	std_pxn_num_next
std_pxn_add_hex:
;else add some letter
	add 	cl, 'A' - 0xa
	dec 	rsp
	mov 	BYTE [rsp], cl 

std_pxn_num_next:
	cmp 	rdi, 0x0
	jne 	std_pxn_num

	sub 	rsp, 0x2
	mov 	WORD [rsp], "0x"
	add 	rbx, 0x2

	mov 	rax, WRITE
	mov 	rdi, STDOUT
	mov 	rsi, rsp
	mov 	rdx, rbx
	syscall

	add 	rsp, rbx

	pop 	rbx
	ret

;takes str ptr in rdi
;takes len in rsi
std_print_str:
	mov 	rax, WRITE
	mov 	rdx, rsi 
	mov 	rsi, rdi
	mov 	rdi, STDOUT
	syscall
	ret

;takes bool in rdi
std_print_bool:
	mov 	rax, WRITE
	test 	rdi, rdi
	jnz 	std_print_bool_true

	mov 	rsi, falst
	mov 	rdx, 0x6

	jmp 	std_print_bool_call
std_print_bool_true:
	mov 	rsi, truet
	mov 	rdx, 0x5

std_print_bool_call:
	mov 	rdi, STDOUT
	syscall
	ret


;allocates char array with input
;firstly on stack then when figures the size, on the heap
;returns ptr  in rax
;returns size in rdi
std_get_str:
	push 	rbx
	xor 	rbx, rbx
	xor 	rcx, rcx

std_get_str_loop:
	sub	 	rsp, 0x100
	
	push 	rcx
	
	mov 	rax, READ 
	mov 	rdi, STDIN
	lea 	rsi, [rsp + 0x8]
	mov 	rdx, 0x100
	syscall
	
	;reverse block 
	push 	rax
	lea 	rdi, [rsp + 0x10]
	mov 	rsi, 0x100
	call 	std_reverse
	pop 	rax
	pop 	rcx

	add 	rbx, rax
	add 	rcx, 0x100
	;if size less than 0x100, then no more input
	cmp 	rax, 0x100
	je  	std_get_str_loop

	;reverse entire input
	;this way we are sure the beg of data is at rsp

	push	rcx
	lea 	rdi, [rsp + 0x8]
	mov 	rsi, rcx
	call 	std_reverse

	mov 	rdi, rbx
	call 	heap_allocate
	push 	rax
	lea 	rdi, [rsp + 0x10]
	mov 	rsi, rax
	mov 	rdx, rbx
	call 	memcpy

	pop 	rax
	pop 	rcx
	add 	rsp, rcx
	mov 	rdi, rbx
	pop 	rbx
	ret


;
; NOT CHECKED
;
;takes ptr in rdi
;assumes it is NULL terminated
;returns len in rax
std_strlen:
	xor 	rcx, rcx
std_strlen_loop:
	inc 	rcx
	cmp 	BYTE [rdi + rcx - 0x1], 0x0
	jne 	std_strlen_loop
	dec 	rcx	
	mov 	rax, rcx
	ret


;takes ptr in rdi
;takes size in rsi
std_reverse:
	lea 	rsi, [rdi + rsi - 0x1]
	
std_reverse_loop:
	mov 	BYTE cl, [rdi]
	xchg 	BYTE cl, [rsi]
	mov 	BYTE [rdi], cl

	inc 	rdi
	dec 	rsi
	cmp 	rdi, rsi
	jl 		std_reverse_loop 	

	ret

;dla structure
;size (capacity is in block)
;data


;takes size in rdi
;returns ptr
std_dla_16B_create:
	shl 	rdi, 0x4 ; times 16
	add 	rdi, 0x8 ; 8bytes for size
	call 	heap_allocate
	
	;set size to zero
	mov 	QWORD [rax], 0x0

	ret

;takes ptr in rdi
std_dla_16B_destroy:
	call 	heap_free
	ret

;these two can be changed into macros
;takes ptr in rdi
;takes index in rsi
std_dla_16B_get:
	shl 	rsi, 0x4
	lea 	rax, [rdi + rsi + 0x8]
	ret
std_dla_16B_get_size:
	mov 	DWORD eax, [rdi]
	ret

;takes ptr in rdi
;takes val1 in rsi
;takes val2 in rdx
;return ptr to dla
std_dla_16B_push:
	push 	rbx
	mov 	rbx, rdi
	inc 	DWORD [rdi]
	mov 	DWORD ecx, [rdi]
	;change size to be expressed in bytes and include size
	shl	 	rcx, 0x4
	add 	rcx, 0x8

	;if capacity can fit, add
	;else realocate
	cmp 	DWORD [rdi - 0x8], ecx
	jge		std_dla_16B_push_add

	push	rcx
	push 	rsi
	push 	rdx
	push 	rdi
	push 	rcx	
	mov 	rdi, rcx
	shl 	rdi, 0x1 ;alocate twice as much memory as needed
	sub  	rcx, 0x8
	call 	heap_allocate
	mov 	rbx, rax
	pop 	rcx
	mov 	QWORD rdi, [rsp] ;load from top of the stack
	mov 	rsi, rax
	mov 	rdx, rcx
	call 	memcpy

	pop 	rdi
	call	heap_free

	pop 	rdx
	pop 	rsi
	pop 	rcx

std_dla_16B_push_add:
	mov 	QWORD [rbx + rcx - 0x10], rsi
	mov 	QWORD [rbx + rcx - 0x8],  rdx
	mov 	rax, rbx
	pop 	rbx
	ret

;takes ptr in rdi
std_dla_16B_pop:
	dec 	DWORD [rdi]
	ret
