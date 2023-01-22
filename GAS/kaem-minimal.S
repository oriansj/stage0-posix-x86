# SPDX-FileCopyrightText: 2020 Jeremiah Orians
# SPDX-FileCopyrightText: 2022 Andrius Štikonas
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Build with:
# as --32 kaem-minimal.S -o kaem-minimal.o
# ld -melf_i386 kaem-minimal.o -o kaem-optional

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
	test ebx, ebx               # Check for missing output
	jne _start_out              # Have real input
	push eax                    # Need to adjust stack
	mov ebx, OFFSET default_file # Use "kaem.x86"

_start_out:
	xor ecx, ecx                # prepare read_only
	push 5
	pop eax                     # the syscall number for open()
	int 0x80                    # Now open that damn file

	test eax, eax               # IF NULL We couldn't open the file
	jle Exit_Failure            # Abort hard
	mov [script], eax           # Set input pointer

	pop eax                     # Get start of envp
	mov ebp, esp                # Protect envp

	push 45
	pop eax                     # the Syscall # for SYS_BRK
	xor ebx, ebx                # Get current brk
	int 0x80                    # Let the kernel do the work
	mov [MALLOC], eax           # Set our malloc pointer

	# Where the main work gets done
	# Using EBX for tokens and ECX for tokens[i]
main_loop:
	mov eax, [max_args]         # Using 256 char* of space
	call malloc                 # get it
	mov ebx, eax                # set tokens

	mov ecx, ebx                # I = 0
	xor eax, eax                # Using 0
	mov [status], eax           # status = 0
	mov [command_done], eax     # command_done = 0

	# Using EAX for result and EBX for tokens[i]
collect_command:
	call collect_token          # Get another token
	test eax, eax               # if NULL == result
	je collect_command_comment  # It is a comment, don't store

	mov [ecx], eax              # tokens[i] = result
	add ecx, 4                  # i = i + 1 (adjusted for char* size)

collect_command_comment:
	mov eax, [command_done]     # Using command_done
	test eax, eax               # IF 0 == command_done
	je collect_command          # keep looping

	# Deal with line comments
	cmp ebx, ecx                # if 0 < i
	je main_loop                # It was a comment

	call print_command          # print the command
	mov eax, [ebx]              # program = tokens[0]
	test eax, eax               # IF NULL == program
	je Exit_Failure             # Some shit went down, abort

	push ebx                    # Protect Tokens
	push 2
	pop eax                     # FORKing
	int 0x80                    # int f = FORK()
	pop ebx                     # Restore Tokens

	test eax, eax               # Check fork
	jl Exit_Failure             # IF f == -1 abort hard
	jne collect_command_parent  # IF f == 0 it is child

	# Deal with child case
	push 11
	pop eax                     # EXECVE
	mov edx, ebp                # third arg = envp
	mov ecx, ebx                # second arg = tokens
	mov ebx, [ebx]              # program = tokens[0]
	int 0x80                    # execve(program, tokens, envp)
	                            # return error

# Exit_Failure function
# Receives nothing
# And aborts hard
# Does NOT return
Exit_Failure:
	push 1
	pop ebx                     # All is wrong
	mov eax, ebx                # put the exit syscall number in eax
	int 0x80                    # Call it a bad day

collect_command_parent:
	mov ebx, eax                # first arg = f
	mov ecx, OFFSET status      # second arg = &status
	xor edx, edx                # third arg = NULL
	push 7
	pop eax                     # WAITPID
	int 0x80                    # waitpid(f, &status, 0)

	mov eax, [status]           # Using status
	test eax, eax               # IF 0 == status
	je main_loop                # Loop forever

	# Deal with very unhappy case
	mov eax, OFFSET hard        # Using "Subprocess error\nABORTING HARD\n"
	call File_Print             # Print it
	jmp Exit_Failure            # return error

Done:
	# program completed Successfully
	xor ebx, ebx                # All is well
	push 1
	pop eax                     # put the exit syscall number in eax
	int 0x80                    # Call it a good day

# print_command function
# Receives tokens[j] in EBX and tokens[i] in ECX
# Modifies EAX
print_command:
	push ebx                    # Protect EBX
	mov eax, OFFSET prefix      # using " +> "
	call File_Print             # print it
print_command_loop:
	mov eax, [ebx]              # using tokens[j]
	call File_Print             # print it
	add ebx, 4                  # j = j + 1
	push 32
	pop eax                     # using ' '
	call fputc                  # print it
	cmp ebx, ecx                # IF j < i
	jne print_command_loop      # otherwise keep looping

	push 10
	pop eax                     # using '\n'
	call fputc                  # print it
	pop ebx                     # Restore EBX
	ret


# collect_token function
# Receives nothing
# Overwrites EAX
# Uses EAX as C, EBX as token and ECX as token[i]
collect_token:
	push ebx                    # Protect EBX
	push ecx                    # Protect ECX
	mov eax, [max_string]       # Using max_string
	call malloc                 # allocate space
	mov ebx, eax                # token = malloc(max_string)
	mov ecx, eax                # i = 0; set token[i]

collect_token_loop:
	call fgetc                  # c = fgetc(input)
	cmp al, -4                  # if C == EOF
	je Done                     # We are done

	cmp al, 32                  # IF C == ' '
	je collect_token_done       # Space terminates token

	cmp al, 9                   # IF C == '\t'
	je collect_token_done       # tab terminates token

	cmp al, 10                  # IF C == '\n'
	jne collect_token_string    # otherwise check next

	# It is a newline
	push 1
	pop eax                     # Using 1
	mov [command_done], eax     # Set command_done = TRUE
	jmp collect_token_done      # Be done

collect_token_string:
	cmp al, 34                  # IF C == '"'
	jne collect_token_comment   # otherwise check next

	# It is a RAW STRING
	call collect_string         # Get the rest of the string
	jmp collect_token_done      # Be done

collect_token_comment:
	cmp al, 35                  # IF C == '#'
	jne collect_token_escape    # otherwise check next

	# It is a line comment
	call collect_comment        # Read it all
	push 1
	pop eax                     # Using 1
	mov [command_done], eax     # Set command_done = TRUE
	jmp collect_token_done      # Be done

collect_token_escape:
	cmp al, 92                  # IF C == '\\'
	jne collect_token_other     # otherwise just store it

	# It is an escape char
	call fgetc                  # Read the char to drop
	jmp collect_token_done      # Be done

collect_token_other:
	mov [ecx], al               # token[i] = C
	add ecx, 1                  # i = i + 1
	jmp collect_token_loop      # Keep going

collect_token_done:
	cmp ebx, ecx                # IF i == 0
	jne collect_token_good      # otherwise return the token
	xor ebx, ebx                # token = NULL

collect_token_good:
	mov eax, ebx                # Return token
	pop ecx                     # Restore ECX
	pop ebx                     # Restore EBX
	ret


# collect_string function
# Receives target[index] in ECX
# Modifies EAX
# Uses EAX as C
collect_string:
	call fgetc                  # C = fgetc(input)
	cmp al, -4                  # if C == EOF
	je Exit_Failure             # Something went horribly wrong

	cmp al, 34                  # IF C == '"'
	je collect_string_done      # be done

	# deal with inside of string
	mov [ecx], al               # target[index] = C
	add ecx, 1                  # index = index + 1
	jmp collect_string          # Keep going

collect_string_done:
	ret


# collect_comment function
# Receives nothing
# Modifies EAX
# uses EAX as Int C
# Just throws away everything it reads
collect_comment:
	call fgetc                  # C = fgetc(input)
	cmp al, -4                  # IF C == EOF
	je Exit_Failure             # abort hard

	cmp al, 10                  # IF C == '\n'
	jne collect_comment         # otherwise keep looping
	ret


# Malloc isn't actually required if the program being built fits in the initial memory
# However, it doesn't take much to add it.
# Requires [MALLOC] to be initialized and EAX to have the number of desired bytes
malloc:
	push ebx                    # Protect EBX
	push ecx                    # Protect ECX
	push edx                    # Protect EDX
	mov ebx, [MALLOC]           # Using the current pointer
	add ebx, eax                # Request the number of desired bytes
	push 45
	pop eax                     # the Syscall # for SYS_BRK
	int 0x80                    # call the Kernel
	mov eax, [MALLOC]           # Return pointer
	mov [MALLOC], ebx           # Update pointer
	pop edx                     # Restore EDX
	pop ecx                     # Restore ECX
	pop ebx                     # Restore EBX
	ret


# fgetc function
# Loads FILE* from [script]
# Returns -4 (EOF) or char in AL
fgetc:
	push ebx                    # Protect EBX
	push ecx                    # Protect ECX
	push edx                    # Protect EDX
	push -4
	pop eax                     # Put EOF in eax
	push eax                    # Assume bad (If nothing read, value will remain EOF)
	lea ecx, [esp]              # Get stack address
	mov ebx, [script]           # Where are we reading from
	push 3
	pop eax                     # the syscall number for read
	push 1
	pop edx                     # set the size of chars we want
	int 0x80                    # call the Kernel
	pop eax                     # Get either char or EOF
	cmp al, -4                  # Check for EOF
fgetc_done:
	pop edx                     # Restore EDX
	pop ecx                     # Restore ECX
	pop ebx                     # Restore EBX
	ret


# File_Print function
# Receives CHAR* in EAX
# calls fputc for every non-null char
File_Print:
	push ebx                    # Protect EBX
	push ecx                    # Protect ECX
	mov ebx, eax                # Protect S
	test eax, eax               # Protect against nulls
	je File_Print_Done          # Simply don't try to print them
File_Print_Loop:
	xor eax, eax                # Zero eax
	mov al, [ebx]               # Read byte
	test eax, eax               # Check for NULL
	je File_Print_Done          # Stop at NULL

	call fputc                  # write it
	add ebx, 1                  # S = S + 1
	jmp File_Print_Loop         # Keep going

File_Print_Done:
	pop ecx                     # Restore ECX
	pop ebx                     # Restore EBX
	ret


# fputc function
# receives CHAR in AL and load FILE* from stdout
# writes char and returns
fputc:
	push ebx                    # Protect EBX
	push ecx                    # Protect ECX
	push edx                    # Protect EDX
	push eax                    # We are writing eax
	lea ecx, [esp]              # Get stack address
	push 1
	pop ebx                     # Write to target file
	push 4
	pop eax                     # the syscall number for write
	mov edx, ebx                # set the size of chars we want
	int 0x80                    # call the Kernel
	pop eax                     # Restore stack
	pop edx                     # Restore EDX
	pop ecx                     # Restore ECX
	pop ebx                     # Restore EBX
	ret


.data

default_file: .asciz "kaem.x86"
prefix: .asciz " +> "
hard: .asciz "Subprocess error\nABORTING HARD\n"
script: .long 0
command_done: .long 0
max_args: .long 1024                # 256 * sizeof(char*)
max_string: .long 4096              # 4096 * sizeof(char)
MALLOC: .long 0
status: .long 0
