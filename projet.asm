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
extern XNextEvent

; External functions from stdio library (ld-linux-x86-64.so.2)    
extern printf
extern exit

%define StructureNotifyMask 131072
%define KeyPressMask         1
%define ButtonPressMask      4
%define MapNotify           19
%define KeyPress             2
%define ButtonPress          4
%define Expose              12
%define ConfigureNotify     22
%define CreateNotify        16
%define QWORD                8
%define DWORD                4
%define WORD                 2
%define BYTE                 1
%define NB_FOYERS            50
%define NB_POINTS            10000
%define WIDTH                800
%define HEIGHT               800

global main

section .bss

display_name:   resq 1
screen:         resd 1
depth:          resd 1
connection:     resd 1
window:         resq 1
gc:             resq 1

distance_min:   resd 1
distance_min_id:resd 1

tableau_x_foyers: resd NB_FOYERS
tableau_y_foyers: resd NB_FOYERS

section .data

event:          times 24 dq 0

width          dd WIDTH
height         dd HEIGHT
nb_points      dd NB_POINTS
nb_foyers      dd NB_FOYERS

x1:             dd 0
x2:             dd 0
y1:             dd 0
y2:             dd 0

section .text

;##################################################
;########### PROGRAMME PRINCIPAL ##################
;##################################################

main:
    ; Ouvrir la connexion au serveur X11
    xor     rdi, rdi
    call    XOpenDisplay
    test    rax, rax
    jz      closeDisplay
    mov     [display_name], rax

    ; Obtenir l'écran par défaut
    mov     rax, [display_name]
    mov     eax, dword[rax+0xe0]
    mov     dword[screen], eax

    ; Créer la fenêtre
    mov     rdi, [display_name]
    mov     esi, [screen]
    call    XRootWindow
    mov     rbx, rax

    mov     rdi, [display_name]
    mov     rsi, rbx
    mov     rdx, 10
    mov     rcx, 10
    mov     r8, [width]
    mov     r9, [height]
    push    0xFFFFFF
    push    0x00FF00
    push    1
    call    XCreateSimpleWindow
    mov     [window], rax

    ; Configurer les événements de la fenêtre
    mov     rdi, [display_name]
    mov     rsi, [window]
    mov     rdx, 131077
    call    XSelectInput

    ; Afficher la fenêtre
    mov     rdi, [display_name]
    mov     rsi, [window]
    call    XMapWindow

    ; Créer le contexte graphique
    mov     rdi, [display_name]
    mov     rsi, [window]
    xor     rdx, rdx
    xor     rcx, rcx
    call    XCreateGC
    mov     [gc], rax

    ; Générer les foyers
    call    generate_foyers

    ; Relier les points aux foyers
    call    relier_points

    ; Boucle principale de gestion des événements
boucle:
    mov     rdi, [display_name]
    mov     rsi, event
    call    XNextEvent

    cmp     dword[event], ConfigureNotify
    je      dessin

    cmp     dword[event], KeyPress
    je      closeDisplay
    jmp     boucle

dessin:
    jmp     flush

flush:
    mov     rdi, [display_name]
    call    XFlush
    jmp     boucle

closeDisplay:
    mov     rax, [display_name]
    mov     rdi, rax
    call    XCloseDisplay
    xor     rdi, rdi
    call    exit

;##################################################
;########### FONCTIONS PERSONNALISÉES #############
;##################################################

; Générer les foyers
generate_foyers:
    xor     r14, r14
boucle_foyers:
    mov     ecx, [width]
    call    generate_random
    mov     [tableau_x_foyers + r14 * 4], r12d

    mov     ecx, [height]
    call    generate_random
    mov     [tableau_y_foyers + r14 * 4], r12d

    inc     r14
    cmp     r14d, [nb_foyers]
    jl      boucle_foyers
    ret

; Relier les points aux foyers
relier_points:
    xor     r14, r14
boucle_points:
    mov     ecx, [width]
    call    generate_random
    mov     [x1], r12d

    mov     ecx, [height]
    call    generate_random
    mov     [y1], r12d

    ; Trouver le foyer le plus proche
    xor     r15d, r15d
    mov     dword [distance_min], 0x7FFFFFFF
boucle_foyers_point:
    mov     rdi, [tableau_x_foyers + r15d * 4]
    mov     rsi, [tableau_y_foyers + r15d * 4]
    mov     rdx, [x1]
    mov     rcx, [y1]
    call    calc_squared_distance

    cmp     r12d, [distance_min]
    jl      sauvegarde_distance

suite_boucle_foyers_point:
    inc     r15d
    cmp     r15d, [nb_foyers]
    jl      boucle_foyers_point

    ; Dessiner la ligne
    mov     rdi, [display_name]
    mov     rsi, [window]
    mov     rdx, [gc]
    mov     ecx, [tableau_x_foyers + r15d * 4]
    mov     r8d, [tableau_y_foyers + r15d * 4]
    mov     r9d, [x1]
    push    qword [y1]
    call    XDrawLine

    inc     r14
    cmp     r14d, [nb_points]
    jl      boucle_points
    ret

sauvegarde_distance:
    mov     [distance_min], r12d
    mov     [distance_min_id], r15d
    jmp     suite_boucle_foyers_point

; Générer un nombre aléatoire entre 0 et ecx-1
generate_random:
    rdrand  r12d
    jnc     generate_random
    xor     edx, edx
    mov     eax, r12d
    div     ecx
    mov     r12d, edx
    ret

; Calculer la distance au carré entre deux points
calc_squared_distance:
    sub     rdi, rdx
    imul    rdi, rdi
    sub     rsi, rcx
    imul    rsi, rsi
    add     rdi, rsi
    mov     r12d, edi
    ret