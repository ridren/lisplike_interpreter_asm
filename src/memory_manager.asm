;TO DO
;1. CHANGE HEAP TO ACTUALLY USE HEAP AND NOT BE LINEAR SEARCH
;   IT IS VERY BAD
; 	pretty hard
;2. allow heap to extend
;	fairly easy
;3. fragmentation, 3 blocks A B C, free B A then C 
;   	B will merge with A but not with C 
;   	so instead of one block ABC we have AB C
;	medium, requires keeping ptr to next block
;4. allocate should allocate in multiples of 8 
;	to be nice to alignment
;5. global error variable

;blocks are in the form 
; first 4 bytes denote size of data part 
; next  4 bytes denote status (free / occupied) 
;	only care about one but due to alignment
; next size bytes are data


;
; 	IF AN OF THE ASSUMPTIONS OF PROCEDURE ARE NOT MET
;	THE BEHAVIOR IS UNDEFINED
;
;heap_init
; 	void : void
;	initializes the heap
; 	should be called before any heap procedures
;
;heap_allocate
; 	ptr : size
; 	allocates block of size blocks on heap
; 	on failure returns 0x0 
; 	blocks allocated with this procedure should be cleared with heap_free
;	assumes size is POSITIVE integer
;
;
;heap_free
;	void : ptr
; 	frees block of heap memory pointed to by ptr
;	assumes ptr is valid ptr that points to memory allocated by heap_allocate
;
;memcpy
;	void : src : dst : len
;	copies len bytes from src to dst
;	assumes src and dest are valid memory addr
;	assumes dst can fit len bytes
; 	assumes len is POSITIVE integer
;
;memset
;	void : src : len : val
;	assigns val to len bytes in src
;	val is 1B value	
;	assumes src is valid memory addr
;	assumes src can fit len bytes
; 	assumes len is POSITIVE integer
;
;memcmp
;	bool : adr1 : adr2 : len
;	returns true if len bytes of adr1 are equal to len bytes of adr2
;	 else returns false
;	assumes adr1 and adr2 are valid mem adrs
;	assumes len is POSITIVE ingere
;


;                 rax ; rdi  ; rsi  ; rdx   ; returns
%define BRK       0xC ; size                ; program brk
%define EXIT     0x3C ; ret 

%define TRUE      0x1
%define FALSE     0x0

%define FREE      0x1
%define OCCUPIED  0x0

section 	.data
;heap bottom/top
hbtp 	   dq	0x0
htpp 	   dq	0x0
;first heap block ptr
hfbp 	   dq	0x0


section 	.text
global  	heap_init
global 		heap_allocate
global 		heap_free

global  	memcpy
global 		memset
global  	memcmp


%define HEAP_GET_BLOCK_SIZE(b, d)   mov 	DWORD d, [b - 0x8]
%define HEAP_GET_BLOCK_STATUS(b, d) mov 	DWORD d, [b - 0x4]

%define HEAP_SET_BLOCK_SIZE(b, v)   mov 	DWORD [b - 0x8], v
%define HEAP_SET_BLOCK_STATUS(b, v) mov 	DWORD [b - 0x4], v

%define HEAP_CMP_BLOCK_SIZE(b, v)   cmp 	DWORD [b - 0x8], v
%define HEAP_CMP_BLOCK_STATUS(b, v) cmp 	DWORD [b - 0x4], v



; =================================


heap_init:
	;get current break
	mov 	rax, BRK
	mov 	rdi, 0x0
	syscall

	mov 	[hbtp], rax

	;allocate 64KiB by adding 64Ki to program break
%define SIZE 0x10000
	add 	rax, SIZE
	mov 	rdi, rax
	mov 	rax, BRK
	syscall

	mov 	[htpp], rax

	;create first free block
	mov 	QWORD rax, [hbtp]
	add 	rax, 0x8

	HEAP_SET_BLOCK_SIZE(rax, SIZE - 0x8)
	HEAP_SET_BLOCK_STATUS(rax, FREE)

	mov 	[hfbp], rax
	
	ret

;takes  size in rdi
;return ptr in rax
heap_allocate:
	push 	rbx

	mov 	rax, [hfbp]
heap_all_search:
	HEAP_GET_BLOCK_SIZE(rax, ebx)

	;if not free goto next block
	HEAP_CMP_BLOCK_STATUS(rax, FREE)
	jne 	heap_all_find_next_block
	
	;if size too small goto next block
	cmp 	rdi, rbx
	jg  	heap_all_find_next_block

	jmp 	heap_all_allocation

heap_all_find_next_block:
	;move to next block that is size + next_blockdata away
	lea 	rax, [rax + rbx + 0x8]
	
	;if next address is equal to heap top
	;cannot allocate memory
	cmp 	QWORD rax, [htpp]
	jb  	heap_all_search
	
	pop 	rbx
	
	mov 	rax, 0x0
	ret
	
heap_all_allocation:
	;split size
	sub 	rbx, rdi	
	sub 	rbx, 0x8 ;because blockdata

	HEAP_SET_BLOCK_STATUS(rax, OCCUPIED)
	
	;if splitted size less than or equal to 0, continue
	cmp 	rbx, 0x0
	jle 	heap_all_ret
	
	HEAP_SET_BLOCK_SIZE(rax, edi)

	;move to next block
	lea 	rsi, [rax + rdi + 0x8]
	
	;if cannot move to next block, return
	cmp 	QWORD rsi, [htpp]
	jge 	heap_all_ret

	HEAP_SET_BLOCK_SIZE(rsi, ebx)
	HEAP_SET_BLOCK_STATUS(rsi, FREE)

heap_all_ret:
	pop 	rbx
	ret

;takes ptr in rdi
heap_free:
	HEAP_SET_BLOCK_STATUS(rdi, FREE)

	HEAP_GET_BLOCK_SIZE(rdi, eax)
	
	;get next block
	lea 	QWORD rcx, [rdi + rax + 0x8]

	;if next block does not exist, goto end
	cmp 	QWORD rcx, [htpp]
	jge 	heap_fr_end

	;if next block not free, goto end
	HEAP_CMP_BLOCK_STATUS(rcx, FREE)
	jne 	heap_fr_end

	;else merge them
	;get size of next
	;add two sizes, and add 0x8 for block info
	HEAP_GET_BLOCK_SIZE(rcx, ecx)
	add 	ecx, 0x8
	add 	DWORD [rdi - 0x8], ecx

heap_fr_end:
	ret


;takes src in rdi
;takes dst in rsi
;takes len in rdx
;assumes src and dest are valid memory addresses
;assumes dst has sufficient space
;assumes len is at least 1
;
;it will probably break
;check for corrupting own block
memcpy:
	;try to move whole words first
	
	cmp 	rdx, 0x8
	jl 		memcpy_loop_bytes
	
	;check if can fix alignment to 8B
	;if their last 3b are the same, then yes
;	mov 	rcx, rdi
;	and 	rcx, 0x7
;	mov 	rax, rsi
;	and 	rax, 0x7
;	cmp 	rcx, rax
;	jne 	memcpy_loop_words
;	
;	neg 	rax
;	add 	rax, 0x8
;	sub 	rdx, rax
;
;	test 	rax, rax
;	jz  	memcpy_loop_words
;
;memcpy_alig_correct:
;	mov 	BYTE cl, [rdi + rax - 0x1]
;	mov 	BYTE [rsi + rax - 0x1], cl
;
;	dec 	rax
;	jnz 	memcpy_alig_correct
;
;	cmp 	rdx, 0x8
;	jl 		memcpy_loop_bytes
	

memcpy_loop_words:
	mov 	QWORD rax, [rdi + rdx - 0x8]
	mov 	QWORD [rsi + rdx - 0x8], rax

	sub 	rdx, 0x8
	cmp 	rdx, 0x8
	jge  	memcpy_loop_words
	test 	rdx, rdx
	jnz 	memcpy_loop_bytes

	ret

memcpy_loop_bytes:
	mov 	BYTE al, [rdi + rdx - 0x1]
	mov 	BYTE [rsi + rdx - 0x1], al 

	dec 	rdx
	jnz 	memcpy_loop_bytes
	ret
;takes src in rdi
;takes len in rsi
;takes val in dl
memset:
	mov 	BYTE [rdi + rsi - 0x1], dl

	dec 	rsi
	jnz 	memset
	ret

;takes one ptr in rdi
;takes scn ptr in rsi
;takes len val in rdx
;assumes len is at least 1
;returns TRUE if equal, FALSE otherwise
memcmp:
	test 	rdx, rdx
	jz 		memcmp_true

	dec 	rdx
	mov 	BYTE cl, [rsi + rdx]
	cmp 	BYTE [rdi + rdx], cl
	je 		memcmp

	mov 	rax, FALSE
	ret

memcmp_true:
	mov 	rax, TRUE
	ret



