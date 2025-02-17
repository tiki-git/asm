; External functions from X11 library
extern XOpenDisplay
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

; External functions from stdio and system libraries
extern printf
extern exit

%define StructureNotifyMask 131072
%define KeyPressMask 1
%define ConfigureNotify 22
%define KeyPress 2
%define QWORD 8
%define DWORD 4

global main

section .bss
display_name: resq 1
screen: resd 1
window: resq 1
gc: resq 1

num_foyers: resd 1
num_points: resd 1
foyers: resq 100  ; Stocker jusqu'à 100 foyers (x, y)
points: resq 10000 ; Stocker jusqu'à 10000 points (x, y)

section .data
event: times 24 dq 0
x1: dd 0
y1: dd 0
x2: dd 0
y2: dd 0

; Couleurs
color_red:    dd 0xFF0000
color_green:  dd 0x00FF00
color_blue:   dd 0x0000FF
color_yellow: dd 0xFFFF00
color_white:  dd 0xFFFFFF
color_black:  dd 0x000000

section .text

main:
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
    mov r8, 500  ; Largeur
    mov r9, 500  ; Hauteur
    push 0xFFFFFF
    push 0x00FF00
    push 1
    call XCreateSimpleWindow
    mov qword[window], rax

    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, StructureNotifyMask
    call XSelectInput

    mov rdi, qword[display_name]
    mov rsi, qword[window]
    call XMapWindow

    mov rsi, qword[window]
    mov rdx, 0
    mov rcx, 0
    call XCreateGC
    mov qword[gc], rax

boucle:
    mov rdi, qword[display_name]
    mov rsi, event
    call XNextEvent

    cmp dword[event], ConfigureNotify
    je dessin

    cmp dword[event], KeyPress
    je closeDisplay
    jmp boucle

; #############################
; ##  Génération aléatoire  ##
; #############################
tirage_aleatoire:
    rdrand rax
    jc .valid_random
    jmp tirage_aleatoire
.valid_random:
    ret

; #####################################
; ##    Fonction de calcul de distance  ##
; #####################################
calcul_distance:
    mov eax, [rsi] 
    sub eax, [rdi] 
    imul eax, eax 
    mov ebx, eax

    mov eax, [rsi+4]  
    sub eax, [rdi+4]  
    imul eax, eax   
    add eax, ebx

    sqrt eax, eax  
    ret

; #####################################
; ##    Génération et affichage      ##
; #####################################
dessin:
    mov rdi, 10  
    call tirage_aleatoire
    and eax, 0xF  ; max 15 foyers
    add eax, 5    ; Min 5 foyers
    mov [num_foyers], eax

    mov rdi, 100  
    call tirage_aleatoire
    and eax, 0x1FFF  ; max 8191 points
    add eax, 5000    ; Min 5000 points
    mov [num_points], eax

    ; Génération des foyers
    mov rcx, [num_foyers]
    mov rdi, foyers
foyer_loop:
    call tirage_aleatoire
    and eax, 0x1FF
    mov [rdi], eax
    call tirage_aleatoire
    and eax, 0x1FF
    mov [rdi+4], eax
    add rdi, 8
    loop foyer_loop

    ; Génération et connexion des points aux foyers
    mov rcx, [num_points]
    mov rdi, points
point_loop:
    call tirage_aleatoire
    and eax, 0x1FF
    mov [rdi], eax
    call tirage_aleatoire
    and eax, 0x1FF
    mov [rdi+4], eax

    ; Trouver le foyer le plus proche
    mov rsi, foyers
    mov rbx, -1
    mov rdx, 0xFFFFFFFF
    mov r8, [num_foyers]
find_closest:
    push rcx
    call calcul_distance
    cmp eax, edx
    jl update_closest
    jmp next_foyer
update_closest:
    mov rdx, eax
    mov rbx, rsi
next_foyer:
    add rsi, 8
    dec r8
    jnz find_closest
    pop rcx

    ; Tracé du segment
    mov dword[x1], [rdi]
    mov dword[y1], [rdi+4]
    mov dword[x2], [rbx]
    mov dword[y2], [rbx+4]

    mov rdi, qword[display_name]
    mov rsi, qword[gc]
    mov edx, 0x0000FF   ; Couleur bleue
    call XSetForeground

    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, qword[gc]
    mov ecx, dword[x1]
    mov r8d, dword[y1]
    mov r9d, dword[x2]
    push qword[y2]
    call XDrawLine

    add rdi, 8
    loop point_loop

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
