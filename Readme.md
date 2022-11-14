very simple interpreter for lisplike language written in x86asm for linux

procedures:
	memory manager 
		allocate
		free
	memory help functions
		memcpy
		memset
		memcmp

	standard library
		print_dnum
		print_xnum
		print_bool
		print_str
		get_str
		strlen
		reverse

		16B dynamic length array

it *should* work but it is very possible there are terrible mistakes

before compilation you have to put .asm files into src/ directory
and create out/ directory

requires nasm and ld

compilation:
```
	make inter
```

example usage:
	> (add (div 4 4) (sub 5 3) (3) (mul 2 2))
	< 10 

all procedures operate on arguments in this way
	arg1 oper arg2 oper arg3 ... argn
except for not which performs boolean negation on arg1 and ignores the rest 
