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
%define NB_FOYERS            100
%define NB_POINTS            500000
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

tableau_x_foyers: resd NB_FOYERS+1
tableau_y_foyers: resd NB_FOYERS+1
drawing_done:   resb 1 ; Flag to indicate if drawing is done


section .data

; Format strings

affichage_indice db "Indice : %d", 10, 0 ; Format string for printf
error_message db "Erreur : indice hors limites ou accès invalide.", 0xA, 0  ; Message d'erreur avec saut de ligne
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
    mov     byte [drawing_done], 0
    
    ; Save registers before printf
    push    rbp
    mov     rbp, rsp
    
    ; Get display name
    xor     rdi, rdi          ; NULL for default display
    call    XDisplayName
    
    ; Print display name
    test    rax, rax          ; Check if display name is NULL
    jz      closeDisplay

    ; Try to open display
    xor     rdi, rdi          ; NULL for default display
    call    XOpenDisplay
    test    rax, rax          ; Check if display opened successfully
    jz      closeDisplay
    
    ; Display opened successfully
    mov     [display_name], rax
    
    ; Restore stack frame
    mov     rsp, rbp
    pop     rbp
    
    ; Continue with the rest of your code
    mov     [display_name],rax
    mov     eax,dword[rax+0xe0]
    mov     dword[screen],eax
    
    mov rdi,qword[display_name]
    mov esi,dword[screen]
    call XRootWindow
    mov rbx,rax

    mov rdi,qword[display_name]
    mov rsi,rbx
    mov rdx,10
    mov rcx,10
    mov r8,[width]	; largeur
    mov r9,[height]	; hauteur
    push 0x000000	; background  0xRRGGBB
    push 0x00FF00
    push 1
    call XCreateSimpleWindow
    mov qword[window],rax

    mov rdi,qword[display_name]
    mov rsi,qword[window]
    mov rdx,131077 ;131072
    call XSelectInput

    mov rdi,qword[display_name]
    mov rsi,qword[window]
    call XMapWindow

    ; Create graphics context with proper error checking
    mov rdi, qword[display_name]
    test rdi, rdi
    jz closeDisplay
    
    mov rsi, qword[window]
    test rsi, rsi
    jz closeDisplay
    
    xor rdx, rdx        ; No mask
    xor rcx, rcx        ; No values
    call XCreateGC
    test rax, rax       ; Check if GC creation failed
    jz closeDisplay
    
    mov qword[gc], rax

boucle: ; Event handling loop
    mov     rdi, qword[display_name]
    cmp     rdi, 0              ; Check if display is NULL
    je      closeDisplay        ; Exit if display is NULL
    mov     rsi, event
    call    XNextEvent

    cmp     dword[event], ConfigureNotify ; On window appearance
    je      foyers                        ; Jump to 'foyers' label

    cmp     dword[event], KeyPress        ; On key press
    je      closeDisplay                  ; Jump to 'closeDisplay'
    jmp     boucle

;#########################################
;# BEGIN GENERATION OF FOYERS            #
;#########################################
    

foyers:

    cmp     byte [drawing_done], 1
    je      boucle ; If drawing is done, skip the drawing process

    ; r14 est à 0 il servira de compteur
    xor r14, r14

    boucle_foyers:
        mov ecx, [width] 
        call generate_random

        ; Sauvegarder le nombre aléatoire
        mov [tableau_x_foyers + r14 * 4], r12

        mov ecx, [height] 
        call generate_random

        ; Sauvegarder le nombre aléatoire
        mov [tableau_y_foyers + r14 * 4], r12


        ; Incrémenter le compteur
        inc r14

        ; Si le compteur est inférieur au nombre de foyers, on boucle
        cmp r14d, [nb_foyers]
        jl boucle_foyers
        ;dec r14d
        ;mov [nb_foyers], r14d

;#########################################
;# END GENERATION OF FOYERS              #
;#########################################

;#########################################
;# BEGIN DRAWING ZONE                    #
;#########################################


    xor r14, r14

    jmp boucle_points

; generation aléatoire de 10000 points
; pas besoin de sauvegarder les points il seron traités un à un
; r14 a 0 il servira de compteur

boucle_points:

    
    mov ecx, [width]
    call generate_random


    ; Sauvegarder le nombre aléatoire dans x1
    mov [x1], r12d

    mov ecx, [height]
    call generate_random

    ;sauvegarder le nombre aléatoire dans y1
    mov [y1], r12


    ; trouver de quelle foyer le point est le plus proche
    ; r15d est à 0 il servira de compteur

    xor r15d, r15d ; indice du foyer
    ; boucle qui parcourt les foyers et calcule la distance entre le points et les foyers

    ; initialiser la distance à la plus grande valeur possible
    mov dword [distance_min], 0xffffff

    boucle_foyers_point:

        ; calcul de la distance entre le point et le foyer

        ; récupérer les coordonnées du foyer
        ; et les stocker dans rcx et rdx
        mov rdi, [tableau_x_foyers + r15d * 4]
        mov rsi, [tableau_y_foyers + r15d * 4]
        mov rdx, [x1]
        mov rcx, [y1]
        call calc_squared_distance

        ; si aex est inférieur à distance_min, on sauvegarde la distance et l'identifiant du foyer

        cmp r12d,[distance_min]
        jl sauvegarde_distance

        suite_boucle_foyers_point:

        ; incrementer le compteur
        inc r15d

        ; si le compteur est inférieur au nombre de foyers, on boucle