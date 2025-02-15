section .data
    foyers times 100 dd 0  ; Tableau pour stocker les coordonnées des foyers
    points times 10000 dd 0 ; Tableau pour stocker les coordonnées des points
    num_foyers dd 50       ; Nombre de foyers
    num_points dd 10000    ; Nombre de points

section .bss
    nearest_foyer resd 1   ; Pour stocker l'indice du foyer le plus proche

section .text
    global main

; External functions from X11 library
extern XOpenDisplay
extern XDisplayName
extern XCloseDisplay
extern XCreateSimpleWindow
extern XMapWindow
extern XRootWindow
extern XSelectInput
extern XFlush
extern XCreateGC
extern XSetForeground
extern XDrawLine
extern XDrawPoint
extern XNextEvent

; External functions from stdio library
extern printf
extern exit

%define StructureNotifyMask 131072
%define KeyPressMask 1
%define ButtonPressMask 4
%define MapNotify 19
%define KeyPress 2
%define ButtonPress 4
%define Expose 12
%define ConfigureNotify 22
%define CreateNotify 16
%define QWORD 8
%define DWORD 4
%define WORD 2
%define BYTE 1

section .bss
    display_name: resq 1
    screen: resd 1
    depth: resd 1
    connection: resd 1
    width: resd 1
    height: resd 1
    window: resq 1
    gc: resq 1

section .data
    event: times 24 dq 0
    x1: dd 0
    x2: dd 0
    y1: dd 0
    y2: dd 0

section .text

main:
    ; Initialisation de l'affichage X11
    xor rdi, rdi
    call XOpenDisplay
    mov qword[display_name], rax

    mov rax, qword[display_name]
    mov eax, dword[rax+0xe0]
    mov dword[screen], eax

    mov rdi, qword[display_name]
    mov esi, dword[screen]
    call XRootWindow
    mov rbx, rax

    mov rdi, qword[display_name]
    mov rsi, rbx
    mov rdx, 10
    mov rcx, 10
    mov r8, 400
    mov r9, 400
    push 0xFFFFFF
    push 0x00FF00
    push 1
    call XCreateSimpleWindow
    mov qword[window], rax

    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, 131077
    call XSelectInput

    mov rdi, qword[display_name]
    mov rsi, qword[window]
    call XMapWindow

    mov rsi, qword[window]
    mov rdx, 0
    mov rcx, 0
    call XCreateGC
    mov qword[gc], rax

    mov rdi, qword[display_name]
    mov rsi, qword[gc]
    mov rdx, 0x000000
    call XSetForeground

    ; Générer les coordonnées des foyers
    mov ecx, [num_foyers]
    lea esi, [foyers]
generate_foyers:
    call rand_coord
    mov [esi], eax
    add esi, 4
    loop generate_foyers

    ; Générer les coordonnées des points
    mov ecx, [num_points]
    lea esi, [points]
generate_points:
    call rand_coord
    mov [esi], eax
    add esi, 4
    loop generate_points

    ; Boucle principale de gestion des événements
boucle:
    mov rdi, qword[display_name]
    mov rsi, event
    call XNextEvent

    cmp dword[event], ConfigureNotify
    je dessin

    cmp dword[event], KeyPress
    je closeDisplay
    jmp boucle

dessin:
    ; Dessiner les foyers
    mov ecx, [num_foyers]
    lea esi, [foyers]
draw_foyers:
    mov eax, [esi]
    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, qword[gc]
    mov rcx, eax
    shr eax, 16
    mov r8, rax
    call XDrawPoint
    add esi, 4
    loop draw_foyers

    ; Relier chaque point au foyer le plus proche
    mov ecx, [num_points]
    lea esi, [points]
process_points:
    mov eax, [esi]
    call find_nearest_foyer
    mov edi, eax
    mov eax, [esi]
    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, qword[gc]
    mov rcx, eax
    shr eax, 16
    mov r8, rax
    call XDrawPoint
    add esi, 4
    loop process_points

    jmp flush

flush:
    mov rdi, qword[display_name]
    call XFlush
    jmp boucle

closeDisplay:
    mov rax, qword[display_name]
    mov rdi, rax
    call XCloseDisplay
    xor rdi, rdi
    call exit

rand_coord:
    rdrand eax
    and eax, 0x1FF
    ret

find_nearest_foyer:
    mov ebx, [num_foyers]
    lea esi, [foyers]
    mov edx, 0xFFFFFFFF
    mov ecx, 0
find_loop:
    mov edi, [esi]
    sub edi, eax
    jns skip_neg
    neg edi
skip_neg:
    cmp edi, edx
    jge next_foyer
    mov edx, edi
    mov ecx, esi
next_foyer:
    add esi, 4
    dec ebx
    jnz find_loop
    mov [nearest_foyer], ecx
    ret