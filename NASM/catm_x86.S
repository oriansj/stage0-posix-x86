;; Copyright (C) 2019 Jeremiah Orians
;; This file is part of mescc-tools.
;;
;; mescc-tools is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; mescc-tools is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with mescc-tools. If not, see <http://www.gnu.org/licenses/>.

	section .text
	global _start

	;; Register usage:
	;; EBP => OUTPUT
	;; EDI => Buffer
	;; ESI => INPUT

; Where the ELF Header is going to hit
; Simply jump to _start
; Our main function
_start:
	pop eax                     ; Get the number of arguments
	pop ebx                     ; Get the program name
	pop ebx                     ; Get the actual output name
	mov cx, 577                 ; Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov dx, 384                 ; Prepare file as RW for owner only (600 in octal)
	push 5                      ; prepare to set eax to 5
	pop eax                     ; the syscall number for open()
	int 0x80                    ; Now open that file
	mov ebp, eax                ; Preserve the file pointer we were given

	push 45
	pop eax                     ; the Syscall # for SYS_BRK
	xor ebx, ebx                ; Get current brk
	int 0x80                    ; Let the kernel do the work
	mov edi, eax                ; Set our malloc pointer

	push 45
	pop eax                     ; the Syscall # for SYS_BRK
	mov ebx, edi                ; Using current pointer
	add ebx, 0x100000           ; Allocate 1MB
	int 0x80                    ; Let the kernel do the work

core:
	pop ebx                     ; Get the actual input name
	test ebx, ebx               ; Check for null string
	je done                     ; Hit null be done

	xor ecx, ecx                ; prepare read_only
	xor edx, edx                ; prevent any interactions
	push 5
	pop eax                     ; the syscall number for open()
	int 0x80                    ; Now open that damn file
	mov esi, eax                ; Protect INPUT
keep:
	mov edx, 0x100000           ; set the size of chars we want
	mov ecx, edi                ; Where to put it
	mov ebx, esi                ; Where are we reading from
	push 3
	pop eax                     ; the syscall number for read
	int 0x80                    ; call the Kernel
	push eax                    ; Protect the number of bytes read

	mov edx, eax                ; Number of bytes to write
	mov ecx, edi                ; What we are writing
	mov ebx, ebp                ; Write to target file
	push 4
	pop eax                     ; the syscall number for write
	int 0x80                    ; call the Kernel

	pop eax                     ; Get bytes read
	cmp eax, 0x100000           ; Check if buffer was fully used
	je keep                     ; Keep looping if was full
	jmp core                    ; Otherwise move to next file

done:
	; program completed Successfully
	xor ebx, ebx                ; All is well
	push 1
	pop eax                     ; put the exit syscall number in eax
	int 0x80                    ; Call it a good day
