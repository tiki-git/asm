; ##################################################
; # EXTERNES
; ##################################################

; --- X11 ---
extern XOpenDisplay
extern XDefaultScreen
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

; --- stdio (via glibc) ---
extern printf
extern exit

; ##################################################
; # DEFINES
; ##################################################

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

; ##################################################
; # BSS
; ##################################################
section .bss

display_name:         resq 1     ; Stocke le pointeur vers Display*
screen:               resd 1
depth:                resd 1
connection:           resd 1
window:               resq 1
gc:                   resq 1

distance_min:         resd 1
distance_min_id:      resd 1

tableau_x_foyers:     resd NB_FOYERS
tableau_y_foyers:     resd NB_FOYERS

; ##################################################
; # DATA
; ##################################################
section .data

event:                times 24 dq 0  ; Espace pour un XEvent (128 bits)

width:                dd WIDTH
height:               dd HEIGHT
nb_points:            dd NB_POINTS
nb_foyers:            dd NB_FOYERS

x1:                   dd 0
y1:                   dd 0

format_printf:        db "Foyer %d: (%d, %d)", 10, 0
error_message:        db "Erreur : indice hors limites ou accès invalide.", 0xA, 0

; ##################################################
; # CODE
; ##################################################
section .text

; --------------------------------------------------
; main
; --------------------------------------------------
main:
    ; 1) Ouvrir la connexion au serveur X
    xor     rdi, rdi
    call    XOpenDisplay
    test    rax, rax
    jz      closeDisplay         ; Si rax == NULL => erreur

    mov     [display_name], rax  ; Sauvegarde du Display*

    ; 2) Écran par défaut via XDefaultScreen(display)
    mov     rdi, [display_name]
    call    XDefaultScreen
    mov     [screen], eax        ; Sauvegarde du screen (int)

    ; 3) Récupérer la root window
    mov     rdi, [display_name]  ; Display*
    mov     rsi, [screen]        ; int screen_number
    call    XRootWindow
    mov     rbx, rax             ; RootWindow renvoyée

    ; 4) Créer la fenêtre
    ;    Window XCreateSimpleWindow(Display* display, Window parent,
    ;       int x, int y, unsigned int width, unsigned int height,
    ;       unsigned int border_width,
    ;       unsigned long border,
    ;       unsigned long background)
    mov     rdi, [display_name]  ; 1er param: Display*
    mov     rsi, rbx             ; 2e param: parent = root
    mov     rdx, 10              ; 3e param: x = 10
    mov     rcx, 10              ; 4e param: y = 10
    mov     r8, [width]          ; 5e param: width
    mov     r9, [height]         ; 6e param: height

    ; On doit passer les 7e, 8e, 9e params sur la pile (border_width, border, background)
    ; Tout en respectant l'alignement 16 octets avant l'appel.
    sub     rsp, 24
    ; 9e param (background)
    push    qword 0x00FF00
    ; 8e param (border)
    push    qword 0xFFFFFF
    ; 7e param (border_width)
    push    qword 1

    call    XCreateSimpleWindow

    add     rsp, 24
    mov     [window], rax

    ; 5) Configurer les événements de la fenêtre (StructureNotifyMask + KeyPressMask)
    mov     rdi, [display_name]
    mov     rsi, [window]
    mov     rdx, (StructureNotifyMask or KeyPressMask)
    call    XSelectInput

    ; 6) Afficher la fenêtre
    mov     rdi, [display_name]
    mov     rsi, [window]
    call    XMapWindow

    ; 7) Créer le contexte graphique
    xor     rdx, rdx
    xor     rcx, rcx
    mov     rdi, [display_name]
    mov     rsi, [window]
    call    XCreateGC
    mov     [gc], rax

    ; 8) Générer les foyers
    call    generate_foyers

    ; 9) Relier les points aux foyers
    call    relier_points

    ; 10) Boucle d'événements
boucle:
    mov     rdi, [display_name]
    mov     rsi, event
    call    XNextEvent

    ; event->type est dans dword [event]
    cmp     dword [event], ConfigureNotify
    je      dessin

    cmp     dword [event], KeyPress
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

; --------------------------------------------------
; generate_foyers
; Génère les NB_FOYERS coordonnées aléatoires
; --------------------------------------------------
generate_foyers:
    xor     r14d, r14d           ; r14d = 0
boucle_foyers:
    mov     ecx, [width]
    call    generate_random
    mov     [tableau_x_foyers + r14d*4], r12d

    mov     ecx, [height]
    call    generate_random
    mov     [tableau_y_foyers + r14d*4], r12d

    ; Afficher "Foyer %d: (%d, %d)"
    mov     rdi, format_printf
    mov     rsi, r14d                       ; index foyer
    mov     rdx, [tableau_x_foyers + r14d*4]
    mov     rcx, [tableau_y_foyers + r14d*4]
    call    printf

    inc     r14d
    cmp     r14d, [nb_foyers]
    jl      boucle_foyers

    ret

; --------------------------------------------------
; relier_points
; Génère NB_POINTS points aléatoires et les relie
; au foyer le plus proche (ligne XDrawLine)
; --------------------------------------------------
relier_points:
    xor     r14d, r14d
boucle_points:
    ; Générer un point (x1,y1)
    mov     ecx, [width]
    call    generate_random
    mov     [x1], r12d

    mov     ecx, [height]
    call    generate_random
    mov     [y1], r12d

    ; On trouve le foyer le plus proche
    xor     r15d, r15d
    mov     dword [distance_min], 0x7FFFFFFF

boucle_foyers_point:
    mov     rdi, [tableau_x_foyers + r15d*4]
    mov     rsi, [tableau_y_foyers + r15d*4]
    mov     rdx, [x1]
    mov     rcx, [y1]
    call    calc_squared_distance

    cmp     r12d, [distance_min]
    jl      sauvegarde_distance

suite_boucle_foyers_point:
    inc     r15d
    cmp     r15d, [nb_foyers]
    jl      boucle_foyers_point

    ; === ICI r15d == nb_foyers (50). On DOIT lire l'indice sauvegardé ===
    mov     r15d, [distance_min_id]

    ; Dessiner la ligne vers le foyer min
    mov     rdi, [display_name]
    mov     rsi, [window]
    mov     rdx, [gc]
    mov     ecx, [tableau_x_foyers + r15d*4]
    mov     r8d, [tableau_y_foyers + r15d*4]
    mov     r9d, [x1]
    push    qword [y1]  ; 7e param
    call    XDrawLine

    inc     r14d
    cmp     r14d, [nb_points]
    jl      boucle_points

    ret

sauvegarde_distance:
    mov     [distance_min], r12d
    mov     [distance_min_id], r15d
    jmp     suite_boucle_foyers_point

; --------------------------------------------------
; generate_random
;   Génère un nombre < ecx
;   via rdrand (dans r12d)
; --------------------------------------------------
generate_random:
    rdrand  r12d
    jnc     generate_random   ; si CF=0 => échec => refaire
    xor     edx, edx
    mov     eax, r12d
    div     ecx               ; eax=quotient, edx=reste
    mov     r12d, edx
    ret

; --------------------------------------------------
; calc_squared_distance(rdi, rsi, rdx, rcx) => r12d
;   calcule (rdi - rdx)^2 + (rsi - rcx)^2
; --------------------------------------------------
calc_squared_distance:
    sub     rdi, rdx
    imul    rdi, rdi
    sub     rsi, rcx
    imul    rsi, rsi
    add     rdi, rsi
    mov     r12d, edi
    ret
