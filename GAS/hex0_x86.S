# SPDX-FileCopyrightText: 2017 Jeremiah Orians
# SPDX-FileCopyrightText: 2022 Andrius Štikonas
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Build with:
# as --32 hex0_x86.S -o hex0_x86.o
# ld -melf_i386 hex0_x86.o -o hex0

.intel_syntax noprefix
.global _start
.text

# Where the ELF Header is going to hit
# Simply jump to _start
# Our main function
_start:
	pop eax                     # Get the number of arguments
	pop ebx                     # Get the program name
	pop ebx                     # Get the actual input name
	xor ecx, ecx                # prepare read_only, ecx = 0
	xor edx, edx                # Extra sure, edx = 0
	push 5                      # prepare to set eax to 5
	pop eax                     # the syscall number for open()
	int 0x80                    # Now open that damn file
	mov esi, eax                # Preserve the file pointer we were given

	pop ebx                     # Get the actual output name
	mov cx, 577                 # Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov dx, 448                 # Prepare file as RWX for owner only (700 in octal)
	push 5                      # prepare to set eax to 5
	pop eax                     # the syscall number for open()
	int 0x80                    # Now open that damn file
	mov edx, eax                # Preserve the file pointer we were given

	# Our flag for byte processing
	push -1
	pop ebp                     # mov ebp, -1

	# temp storage for the sum
	xor edi, edi                # edi = 0

loop:
	# Read a byte
	call Read_byte

	# process byte
	call hex

	# Deal with -1 values
	test eax, eax
	jl loop

	# deal with toggle
	test ebp, ebp               # jump if ebp >= 0
	jge print

	# process first byte of pair
	mov edi, eax
	xor ebp, ebp                # ebp = 0
	jmp loop

# process second byte of pair
print:
	# update the sum and store in output
	shl edi, 4
	add eax, edi

	# flip the toggle
	dec ebp                     # ebp = -1

	call write_byte

	jmp loop

hex:
	# Purge Comment Lines (#)
	cmp al, 35
	je purge_comment

	# Purge Comment Lines (;)
	cmp al, 59
	je purge_comment

	# deal all ascii less than 0
	cmp al, 48
	jl ascii_other

	# deal with 0-9
	cmp al, 58
	jl ascii_num

	# deal with all ascii less than A
	cmp al, 65
	jl ascii_other

	# deal with A-F
	cmp al, 71
	jl ascii_high

	# deal with all ascii less than a
	cmp al, 97
	jl ascii_other

	# deal with a-f
	cmp al, 103
	jl ascii_low

	# The rest that remains needs to be ignored
	jmp ascii_other

purge_comment:
	# Read a byte
	call Read_byte

	# Loop if not LF
	cmp al, 10
	jne purge_comment

	# Otherwise return -1

ascii_other:
	push -1
	pop eax                     # return -1
	ret

ascii_num:
	sub al, 48
	ret

ascii_low:
	sub al, 32                  # convert to uppercase

ascii_high:
	sub al, 55
	ret

# Writes byte stored in al
write_byte:
	# Print our Hex
	mov ebx, edx                # Where are we writing to
	push edx                    # protect fout
	push 1                      # prepare to set edx to 1
	pop edx                     # set the size of chars we want
	push eax                    # Move output to stack
	mov ecx, esp                # What we are writing
	push 4                      # prepare to set eax to 4
	pop eax                     # the syscall number for write
	int 0x80                    # call the Kernel
	pop ebx                     # deallocate stack
	pop edx                     # restore fout
	ret

Read_byte:
	# Attempt to read 1 byte from STDIN
	push edx                    # protect fout
	push 1                      # prepare to set edx to 1
	pop edx                     # set the size of chars we want
	push ebx                    # allocate stack
	mov ecx, esp                # Where to put it
	mov ebx, esi                # Where are we reading from
	push 3                      # prepare to set eax to 3
	pop eax                     # the syscall number for read
	int 0x80                    # call the Kernel

	test eax, eax               # check what we got
	je Done                     # Got EOF call it done

	# load byte
	pop eax                     # load char
	pop edx                     # restore fout
	ret

Done:
	# program completed Successfully
	xor ebx, ebx                # All is well, ebx = 0
	push 1
	pop eax                     # put the exit syscall number in eax
	int 0x80                    # Call it a good day

ELF_end:
