# SPDX-FileCopyrightText: © 2017 Jeremiah Orians
# SPDX-FileCopyrightText: © 2022 Andrius Štikonas
# SPDX-FileCopyrightText: © 2024 Noah Goldstein
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
	push 5                      # prepare to set eax to 5
	pop eax                     # the syscall number for open()
	cdq                         # Extra sure, edx = 0
	int 0x80                    # Now open that damn file
	pop ebx                     # Get the actual output name
	push eax                    # Preserve the file pointer we were given
	mov cx, 577                 # Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov dx, 448                 # Prepare file as RWX for owner only (700 in octal)
	push 5                      # prepare to set eax to 5
	pop eax                     # the syscall number for open()
	int 0x80                    # Now open that damn file
	cdq                         # edx = 0 since file descriptor is nonnegative
	inc edx                     # edx = 1 (count for read/write)
	xchg eax,edi                # Preserve outfile

loop_reset_all:
	xor ebp, ebp                # ebp = 0 (no prior hex val)

# Comment tracking is done with esi.
# esi is decremented if we hit a
# comment (';' or '#') and reset
# if we hit a new-line.
loop_reset_comment:
	mov esi, edx                # Set no current comment
loop_add_comment:
	dec esi
loop:

	# Read a byte
	pop ebx                     # Get infile
	mov ecx, esp                # Set buffer
	# edx is already set to 1.
	push 3
	pop eax                     # Set read syscall in eax
	int 0x80                    # Do the actual read
	push ebx                    # Re-save infile
	test eax, eax               # Check what we got
	jne cont                    # No EOF

	# Exit successfully
	inc eax                     # Set exit syscall in eax
	xor ebx, ebx                # Set return success (ebx = 0)
	int 0x80                    # Exit

cont:
	mov al,[ecx]                # Move prog byte in eax

	# New line check
	cmp al, 10                  # Check new-line
	je loop_reset_comment       # If new-line, end comment handling

	# In comment check
	test esi, esi               # Skip byte if we are in a comment
	jne loop

	# Start comment check
	cmp al, 35                  # Start of '#' comment
	je loop_add_comment

	cmp al, 59                  # Start of ';' comment
	je loop_add_comment

	# Start of hex str to int
	sub al, 48                  # Subtract ascii '0' from al
	sub al, 10                  # Check for value in '0'-'9'
	jb write                    # We have hex value, write it

	sub al, 7                   # Subtract ('A'-'0') from al
	and al, ~32                 # Remove lower case bit
	cmp al, 7                   # Check for value 'A'-'F'
	jae loop                    # We have hex value, write it

write:
	shl ebp, 4                  # Shift up existing hex digit
	add al, 10                  # Finish converting ascii to raw value
	add ebp, eax                # Combine the hex digits

	# Check if this is first digit in hex val
	neg edi                     # Flip sign of edi to indicate we got a digit
	jl loop                     # Negative -> first digit, get another one

	# We have both digits in low byte of ebp, good to write
	mov [ecx], ebp              # Move edge to buffer
	mov ebx, edi                # Move outfile to ebx
	mov al, 4                   # Set write syscall in eax
	int 0x80                    # Do the write
	jmp loop_reset_all          # Start a fresh byte
ELF_end:
