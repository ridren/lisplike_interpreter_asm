;              rax ; rdi  ; rsi  ; rdx    ; r10 ; r8 ; r9  ; returns
%define EXIT  0x3C ; ret

%define TRUE  0x1
%define FALSE 0x0

%define TOKEN_NONE 0x0
%define TOKEN_LPRN 0x1
%define TOKEN_RPRN 0x2
%define TOKEN_NUMB 0x3
%define TOKEN_IDEN 0x4
%define TOKEN_ENOF 0x5

section 	.bss
oneBbuff 	resb 	1

section 	.data
indexp  	dq 	0x0
compadd 	db  "add"
compsub 	db  "sub"
compmul 	db  "mul"
compdiv 	db  "div"
compmod  	db  "mod"
compnot  	db  "not"

scmpadd  	db	"+"
scmpsub  	db	"-"
scmpmul  	db	"*"
scmpdiv 	db	"/" 
scmpmod 	db	"%" 
scmpnot 	db	"!" 

;too many left parens
tmlp    	db 	"not every '(' matched with ')'; adding necessary amount to the end",0xA
tmlpl   	dq	$ - tmlp
;too many right parens
tmrp    	db  "unexpected ')'; ommitting", 0xA
tmrpl   	dq	$ - tmrp

;missing expression
msexp   	db	"missing expression inside (); returning 0", 0xA
msexpl  	dq	$ - msexp

;missing arg 
msarg   	db	"missing argument for command; returning 0", 0xA
msargl  	dq	$ - msarg

invcmp  	db  "command invalid: "
invcmpl   	dq  $ - invcmp

section  	.text
extern 		nline

extern 		heap_init
extern 		heap_allocate
extern 		heap_free

extern 		memcpy
extern 		memset
extern  	memcmp

extern 		std_print_dnum
extern 		std_print_xnum
extern 		std_print_bool
extern 		std_print_str
extern 		std_get_str

extern  	std_strlen
extern 		std_reverse

extern  	std_dla_16B_create
extern  	std_dla_16B_destroy
extern  	std_dla_16B_push
extern  	std_dla_16B_pop
extern  	std_dla_16B_get
extern   	std_dla_16B_get_size

global 		_start

;                       dla val1 val2
%macro DLA_16B_ADD_ELEM 3
	mov 	QWORD rdi, [ %1 ]
	mov 	rsi, %2
	mov 	rdx, %3
	call 	std_dla_16B_push
	mov 	QWORD [ %1 ], rax
%endmacro


;            strptr, len
%macro PRINT 2
	mov 	rdi, %1 
	mov 	rsi, %2
	call 	std_print_str
%endmacro

;                   a, b, label
%macro IF_NOT_EQUAL 3
	cmp 	%1, %2
	jne 	%3
%endmacro
;               a, b, label
%macro IF_EQUAL 3
	cmp 	%1, %2
	je  	%3
%endmacro

;                                what, min, max, label
%macro IF_NOT_IN_RANGE_INCLUSIVE 4
	cmp 	%1 , %2
	jl  	%4
	cmp 	%1 , %3 
	jg  	%4
%endmacro

;                          a, alen, b, blen, label
%macro IF_STRINGS_NOT_SAME 5
	IF_NOT_EQUAL %2, %4, %5 

	mov 	rdi, %1
	mov 	rsi, %3
	mov 	rdx, %2
	call 	memcmp
	test 	rax, rax
	jz   	%5

%endmacro

;               ptr, size
%macro ALLOCATE 2
	mov 	rdi, %2
	call 	heap_allocate
	mov 	%1, rax
%endmacro

%macro FREE 1
	mov 	rdi, %1
	call 	heap_free
%endmacro


;takes dla ptr in rdi
;returns value in rax
;on return increases index by one
evaluate:
	push 	rbx
	push 	r12
	push 	r13
	push 	r14
	mov 	r12, rdi

	;mov 	rdi, r12
	mov 	QWORD rsi, [indexp]
	call 	std_dla_16B_get

	;type in rcx
	;val  in rdx
	mov 	QWORD rcx, [rax]
	mov 	QWORD rdx, [rax + 0x8]

eval_test_1:
	IF_NOT_EQUAL rcx, TOKEN_NUMB, eval_test_2

	mov 	rax, rdx

	jmp 	eval_return

eval_test_2:
	IF_NOT_EQUAL rcx, TOKEN_LPRN, eval_test_3
	
	;evaluate inside expr, so just increase ptr and call eval
	inc 	QWORD [indexp]

	;firstly check the type of inside expr, if RPRN then err
	;mov 	rdi, r12
	mov 	QWORD rsi, [indexp]
	call 	std_dla_16B_get
	
	cmp 	BYTE [rax], TOKEN_RPRN
	je  	eval_test_2_missing_expr

	call 	evaluate

	;value is already in rax
	jmp 	eval_return

eval_test_2_missing_expr:
	PRINT 	msexp, [msexpl]

	mov 	rax, 0x0
	jmp 	eval_return

eval_test_3:
	IF_NOT_EQUAL rcx, TOKEN_IDEN, eval_test_err
	
	;load command into r13
	mov 	r13, rdx

	mov 	rdi, r13
	call 	std_strlen

	;len into r14
	mov 	r14, rax

	;reverse since input gives reversed
	mov 	rdi, r13
	mov 	rsi, rax
	call 	std_reverse

	;first argument will always be default value so 
	inc 	QWORD [indexp]
	
	;check if first arg exists
	mov 	rdi, r12
	mov 	QWORD rsi, [indexp]
	call 	std_dla_16B_get
	
	cmp 	QWORD [rax], TOKEN_ENOF
	je  	eval_test_3_err_misarg
	cmp  	QWORD [rax], TOKEN_RPRN
	je  	eval_test_3_err_misarg

	;mov 	rdx, 0x1
	;call 	std_print_xnum

	mov 	rdi, r12
	call 	evaluate
	mov 	rbx, rax

eval_test_3_opt_1:
	IF_STRINGS_NOT_SAME r13, r14, compadd, 0x3, eval_test_3_opt_1.check2
	jmp 	eval_test_3_opt_1.get_next_val

.check2:
	IF_STRINGS_NOT_SAME r13, r14, scmpadd, 0x1, eval_test_3_opt_2

.get_next_val:
	;if next token is rprn, return
	mov 	rdi, r12
	mov 	QWORD rsi, [indexp]
	call 	std_dla_16B_get

	cmp 	QWORD [rax], TOKEN_RPRN
	je  	eval_test_3_ret
	cmp 	QWORD [rax], TOKEN_ENOF
	je  	eval_test_3_ret

	mov 	rdi, r12
	call 	evaluate
	add 	rbx, rax

	jmp 	.get_next_val

eval_test_3_opt_2:
	IF_STRINGS_NOT_SAME r13, r14, compsub, 0x3, eval_test_3_opt_2.check2
	jmp 	eval_test_3_opt_2.get_next_val

.check2:
	IF_STRINGS_NOT_SAME r13, r14, scmpsub, 0x1, eval_test_3_opt_3

.get_next_val:
	;if next token is rprn, return
	mov 	rdi, r12
	mov 	QWORD rsi, [indexp]
	call 	std_dla_16B_get

	cmp 	QWORD [rax], TOKEN_RPRN
	je  	eval_test_3_ret
	cmp 	QWORD [rax], TOKEN_ENOF
	je  	eval_test_3_ret

	mov 	rdi, r12
	call 	evaluate
	sub 	rbx, rax

	jmp 	.get_next_val	

eval_test_3_opt_3:
	IF_STRINGS_NOT_SAME r13, r14, compmul, 0x3, eval_test_3_opt_3.check2
	jmp 	eval_test_3_opt_3.get_next_val

.check2:
	IF_STRINGS_NOT_SAME r13, r14, scmpmul, 0x1, eval_test_3_opt_4

.get_next_val:
	;if next token is rprn, return
	mov 	rdi, r12
	mov 	QWORD rsi, [indexp]
	call 	std_dla_16B_get

	cmp 	QWORD [rax], TOKEN_RPRN
	je  	eval_test_3_ret
	cmp 	QWORD [rax], TOKEN_ENOF
	je  	eval_test_3_ret

	mov 	rdi, r12
	call 	evaluate
	imul 	rbx, rax

	jmp 	.get_next_val

eval_test_3_opt_4:
	IF_STRINGS_NOT_SAME r13, r14, compdiv, 0x3, eval_test_3_opt_4.check2
	jmp 	eval_test_3_opt_4.get_next_val

.check2:
	IF_STRINGS_NOT_SAME r13, r14, scmpdiv, 0x1, eval_test_3_opt_5
	
.get_next_val:
	;if next token is rprn, return
	mov 	rdi, r12
	mov 	QWORD rsi, [indexp]
	call 	std_dla_16B_get

	cmp 	QWORD [rax], TOKEN_RPRN
	je  	eval_test_3_ret
	cmp 	QWORD [rax], TOKEN_ENOF
	je  	eval_test_3_ret

	mov 	rdi, r12
	call 	evaluate
	xor 	rdx, rdx
	mov 	rcx, rax
	mov 	rax, rbx
	div 	rcx
	mov 	rbx, rax

	jmp 	.get_next_val

eval_test_3_opt_5:
	IF_STRINGS_NOT_SAME r13, r14, compmod, 0x3, eval_test_3_opt_5.check2
	jmp 	eval_test_3_opt_5.get_next_val

.check2:
	IF_STRINGS_NOT_SAME r13, r14, scmpmod, 0x1, eval_test_3_opt_6
	
.get_next_val:
	;if next token is rprn, return
	mov 	rdi, r12
	mov 	QWORD rsi, [indexp]
	call 	std_dla_16B_get

	cmp 	QWORD [rax], TOKEN_RPRN
	je  	eval_test_3_ret
	cmp 	QWORD [rax], TOKEN_ENOF
	je  	eval_test_3_ret

	mov 	rdi, r12
	call 	evaluate
	xor 	rdx, rdx
	mov 	rcx, rax
	mov 	rax, rbx
	div 	rcx
	mov 	rbx, rdx

	jmp 	.get_next_val

eval_test_3_opt_6:
	IF_STRINGS_NOT_SAME r13, r14, compnot, 0x3, eval_test_3_opt_6.check2
	jmp 	eval_test_3_opt_6.get_next_val

.check2:
	IF_STRINGS_NOT_SAME r13, r14, scmpnot, 0x1, eval_test_3_err
	
	;ignores them but has to process 
.get_next_val:
	;if next token is rprn, return
	mov 	rdi, r12
	mov 	QWORD rsi, [indexp]
	call 	std_dla_16B_get

	cmp 	QWORD [rax], TOKEN_RPRN
	je  	eval_test_3_opt_6_ret
	cmp 	QWORD [rax], TOKEN_ENOF
	je  	eval_test_3_opt_6_ret

	mov 	rdi, r12
	call 	evaluate

	jmp 	.get_next_val
	
eval_test_3_opt_6_ret:
	mov 	rax, 0x1
	test 	rbx, rbx
	cmovnz	rbx, rax
	not 	rbx
	and 	rbx, 0x1

eval_test_3_ret:
	mov 	rax, rbx
	dec 	QWORD [indexp]
	jmp 	eval_return

eval_test_3_err:
	PRINT  	invcmp, [invcmpl]
	PRINT 	r13, r14
	PRINT 	nline, 0x1
	jmp 	eval_test_err

eval_test_3_err_misarg:
	PRINT	msarg, [msargl]

eval_test_err:
	mov 	rax, 0x0

eval_return:
	pop 	r14
	pop 	r13
	pop 	r12
	pop 	rbx

	inc 	QWORD [indexp]
	ret


_start:
	call 	heap_init

	mov 	rbx, 0x64
repl_loop:

	mov 	QWORD [indexp], 0x0
	call 	main
	
	dec 	rbx
	jnz 	repl_loop


	mov 	rdi, rax
	mov 	rax, EXIT
	syscall


main:
	push 	rbx
	push 	rbp
	;variables:
	;rbp - 0x8  string ptr
	;rbp - 0xC  string len
	;rbp - 0x18 token arr ptr
	mov 	rbp, rsp
	sub 	rsp, 0x20

	call 	std_get_str
	mov 	QWORD [rbp - 0x8], rax
	mov 	DWORD [rbp - 0xC], edi

;=====LEXER=====
	
	mov 	rdi, 0x1
	call 	std_dla_16B_create
	mov 	QWORD [rbp - 0x18], rax

	xor 	r13, r13 ; depth
	xor 	rcx, rcx
	;str ptr in r12
	mov 	r12, [rbp - 0x8]

lexer_loop:
	;cur char in dl
	mov 	BYTE dl, [r12 + rcx]
	push 	rcx

lex_test_1:
	IF_NOT_EQUAL dl, '(' , lex_test_2

	inc 	r13
	
	DLA_16B_ADD_ELEM rbp - 0x18, TOKEN_LPRN, 0x0

	jmp 	lex_next_iter

lex_test_2:
	IF_NOT_EQUAL dl, ')' , lex_test_3

	dec 	r13
	cmp 	r13, 0x0
	jge  	lex_test_2_add

	inc 	r13
	
	PRINT tmrp, [tmrpl]
	
	jmp 	lex_next_iter

lex_test_2_add:
	DLA_16B_ADD_ELEM rbp - 0x18, TOKEN_RPRN, 0x0

	jmp 	lex_next_iter

;add suport for negative numbers
lex_test_3:
	IF_NOT_IN_RANGE_INCLUSIVE dl, '0' , '9' , lex_test_4

	pop 	rcx
	
	xor 	rax, rax ; rax will be used to store the number
	movzx 	rdx, dl
.loop:
	imul 	rax, 0xA
	add 	rax, rdx
	sub  	rax, '0' 

	inc 	rcx
	mov 	BYTE dl, [r12 + rcx]
	movzx 	rdx, dl
	
	
	IF_NOT_IN_RANGE_INCLUSIVE dl, '0' , '9' , lex_test_3_end

	jmp  	.loop	

lex_test_3_end:
	dec 	rcx
	push 	rcx

	DLA_16B_ADD_ELEM rbp - 0x18, TOKEN_NUMB, rax

	;so that dl definitely DOES NOT CONTAIN 0xA
	xor 	dl, dl 

	jmp 	lex_next_iter
	
lex_test_4:
	IF_NOT_IN_RANGE_INCLUSIVE dl, '!' , '~' , lex_next_iter

	xor 	rax, rax ; count how many chars
	pop 	rcx
	
	dec 	rsp
	mov 	BYTE [rsp], 0x0 ;null terminator
	inc 	rax

.loop:
	inc 	rax
	dec 	rsp
	mov 	BYTE [rsp], dl
	
	inc 	rcx
	mov 	BYTE dl, [r12 + rcx]

	IF_NOT_IN_RANGE_INCLUSIVE dl, '!' , '~' , lex_test_4_end

	;exclude parentheses
	cmp 	dl, '(' 
	je  	lex_test_4_end
	cmp 	dl, ')' 
	je 		lex_test_4_end

	jmp 	.loop

lex_test_4_end:

	dec 	rcx
	push 	rcx
	push 	rax

	mov 	QWORD rdi, [rsp] ;rax
	call 	heap_allocate
	push 	rax

	lea 	rdi, [rsp + 0x18]
	mov 	QWORD rsi, [rsp]
	mov 	QWORD rdx, [rsp + 0x8]
	call 	memcpy

	DLA_16B_ADD_ELEM rbp - 0x18, TOKEN_IDEN, [rsp]

	pop 	rax
	pop 	rax
	pop 	rcx
	add 	rsp, rax
	push 	rcx

	jmp		lex_next_iter

lex_next_iter:
	pop  	rcx
	inc 	rcx	
	cmp 	BYTE dl, 0xa 
	jne  	lexer_loop


	test	r13, r13
	jz  	lex_end

	PRINT tmlp, [tmlpl]

lex_fix_paren_loop:
	
	DLA_16B_ADD_ELEM rbp - 0x18, TOKEN_RPRN, 0x0


	dec 	r13
	jnz 	lex_fix_paren_loop

lex_end:
	DLA_16B_ADD_ELEM rbp - 0x18, TOKEN_ENOF, 0x0

	mov 	QWORD rdi, [rbp - 0x18]
	mov 	QWORD [indexp], 0x0
	call 	evaluate
;
	mov 	rdi, rax
	call 	std_print_dnum
	
	jmp 	print_end


	mov 	rdi, [rbp - 0x18]
	call 	std_dla_16B_get_size
	mov 	rbx, rax
;if size zero do not clear	
	test 	rbx, rbx
	jz 	 	print_end	

	mov 	rcx, [rbp - 0x18]
	add 	rcx, 0x8 ;rcx points to first elem
print_loop:
	push 	rcx
	mov 	QWORD rdi, [rcx]

	;destroy IFF type is identifier, otherwise there is no string
	cmp 	rdi, TOKEN_IDEN
	jne 	print_loop_print_norm
	
	call 	std_print_xnum
	mov 	QWORD rcx, [rsp]
	mov 	QWORD rdi, [rcx + 0x8]
	mov 	rsi, 0x4
	call 	std_print_str
	
	jmp 	print_loop_cont

print_loop_print_norm:
	call 	std_print_xnum
	mov 	QWORD rcx, [rsp]
	mov 	QWORD rdi, [rcx + 0x8]
	call 	std_print_xnum


print_loop_cont:
	pop 	rcx
	add 	rcx, 0x10

	dec 	rbx
	jnz 	print_loop

print_end:

	mov 	rdi, [rbp - 0x18]
	call 	std_dla_16B_get_size
	mov 	rbx, rax
;if size zero do not clear	
	test 	rbx, rbx
	jz 		clear_end

	mov 	rcx, [rbp - 0x18]
	add 	rcx, 0x8 ;rcx points to first elem
clear_loop:
	push 	rcx
	mov 	QWORD rdi, [rcx]

	;destroy IFF type is identifier, otherwise there is no string
	cmp 	rdi, TOKEN_IDEN
	jne 	clear_loop_cont
	
	FREE [rcx + 0x8]


clear_loop_cont:
	pop 	rcx
	add 	rcx, 0x10

	dec 	rbx
	jnz 	clear_loop

clear_end:
	mov 	rdi, [rbp - 0x18]
	call 	std_dla_16B_destroy

	FREE [rbp - 0x8]

	mov 	rsp, rbp
	pop 	rbp
	pop 	rbx
	mov 	rax, 0x0
	ret

