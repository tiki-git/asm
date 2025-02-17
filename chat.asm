;===========================================================
; Compilation (exemple) :
; nasm -f elf64 main.asm -o main.o
; ld main.o -lX11 -o main
; ./main
;===========================================================

section .data

; Événement X stocké sur 24 octets, aligné sur 8
event:        times 24 dq 0

x1:           dd 0
x2:           dd 0
y1:           dd 0
y2:           dd 0

; Constantes pour le nombre de foyers et de points
num_foyers:   dd 50      ; Nombre de foyers
num_points:   dd 10000   ; Nombre de points

section .bss

display_name: resq 1
screen:       resd 1
depth:        resd 1
connection:   resd 1
width:        resd 1
height:       resd 1
window:       resq 1
gc:           resq 1

; Tableaux pour stocker les foyers et les points
foyers_x:     resd 1000   ; Tableau pour les coord x des foyers
foyers_y:     resd 1000   ; Tableau pour les coord y des foyers
points_x:     resd 10000  ; Tableau pour les coord x des points
points_y:     resd 10000  ; Tableau pour les coord y des points

section .text
global main

; Déclarations des fonctions externes X11
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

; Déclarations des fonctions externes stdio/stdlib
extern printf
extern exit

; Définition de quelques constantes
%define StructureNotifyMask 131072
%define KeyPressMask         1
%define ButtonPressMask      4
%define MapNotify            19
%define KeyPress             2
%define ButtonPress          4
%define Expose               12
%define ConfigureNotify      22
%define CreateNotify         16

;===========================================================
;                  FONCTION PRINCIPALE
;===========================================================

main:
    xor     rdi,rdi
    call    XOpenDisplay            ; rax = pointeur sur Display*
    mov     [display_name], rax

    ; screen = DefaultScreen(display_name) => simplifié : offset 0xe0
    mov     rax, [display_name]     ; rax = Display*
    mov     eax, [rax + 0xe0]       ; eax = DefaultScreen(display)
    mov     [screen], eax

    ; root = XRootWindow(display, screen)
    mov     rdi, [display_name]
    mov     esi, [screen]
    call    XRootWindow
    mov     rbx, rax                ; rbx = root window

    ; window = XCreateSimpleWindow(display, root, 10,10, 400,400, 1, 0x00FF00, 0xFFFFFF)
    mov     rdi, [display_name]
    mov     rsi, rbx                ; root
    mov     rdx, 10                 ; x
    mov     rcx, 10                 ; y
    mov     r8, 400                 ; width
    mov     r9, 400                 ; height
    push    0xFFFFFF                ; background color (en dernier)
    push    0x00FF00                ; border color
    push    1                       ; border width
    call    XCreateSimpleWindow
    mov     [window], rax

    ; XSelectInput(display, window, StructureNotifyMask | KeyPressMask)
    mov     rdi, [display_name]
    mov     rsi, [window]
    mov     rdx, (StructureNotifyMask | KeyPressMask)
    call    XSelectInput

    ; XMapWindow(display, window)
    mov     rdi, [display_name]
    mov     rsi, [window]
    call    XMapWindow

    ; gc = XCreateGC(display, window, 0, 0)
    mov     rdi, [display_name]
    mov     rsi, [window]
    mov     rdx, 0
    mov     rcx, 0
    call    XCreateGC
    mov     [gc], rax

    ; XSetForeground(display, gc, 0x000000) => noir
    mov     rdi, [display_name]
    mov     rsi, [gc]
    mov     rdx, 0x000000
    call    XSetForeground

    ;--------------------------------------------
    ; Génération aléatoire des foyers
    ;--------------------------------------------
    mov     ecx, [num_foyers]   ; compteur
    lea     rbx, [foyers_x]
    lea     rdx, [foyers_y]

gen_foyers_loop:
    call    random_coordinate
    ; stocke la coordonnée x
    mov     [rbx + rcx*4 - 4], eax

    call    random_coordinate
    ; stocke la coordonnée y
    mov     [rdx + rcx*4 - 4], eax

    loop    gen_foyers_loop

    ;--------------------------------------------
    ; Génération aléatoire des points
    ;--------------------------------------------
    mov     ecx, [num_points]
    lea     rbx, [points_x]
    lea     rdx, [points_y]

gen_points_loop:
    call    random_coordinate
    mov     [rbx + rcx*4 - 4], eax

    call    random_coordinate
    mov     [rdx + rcx*4 - 4], eax

    loop    gen_points_loop

    ;--------------------------------------------
    ; Relier chaque point à son foyer le plus proche
    ;--------------------------------------------
    mov     ecx, [num_points]
    lea     rbx, [points_x]
    lea     rdx, [points_y]

connect_points:
    ; Charger pointX, pointY
    mov     edi, [rbx + rcx*4 - 4]  ; param1 -> EDI
    mov     esi, [rdx + rcx*4 - 4]  ; param2 -> ESI
    call    find_nearest_foyer     ; => EAX = foyerX, EDX = foyerY

    ; On a : EDI, ESI = (pointX, pointY)
    ;        EAX, EDX = (foyerX, foyerY)
    ; On dessine la ligne [point -> foyer]
    mov     [x1], edi              ; point.x
    mov     [y1], esi              ; point.y
    mov     [x2], eax              ; foyer.x
    mov     [y2], edx              ; foyer.y
    call    draw_line

    loop    connect_points

    ;--------------------------------------------
    ; Boucle événementielle
    ;--------------------------------------------
boucle_events:
    mov rdi, [display_name]
    mov rsi, event
    call XNextEvent

    ; Si ConfigureNotify => on redessine (ici un flush)
    cmp dword [event], ConfigureNotify
    je  dessin

    ; Si KeyPress => on ferme
    cmp dword [event], KeyPress
    je  closeDisplay

    jmp boucle_events

dessin:
    ; (Ici éventuellement redessiner si besoin)
    jmp flush

flush:
    mov rdi, [display_name]
    call XFlush
    jmp boucle_events

;---------------------------------------------------------
closeDisplay:
    mov rax, [display_name]
    mov rdi, rax
    call XCloseDisplay
    xor rdi, rdi
    call exit

;===========================================================
;       GENERER UNE COORDONNEE ALEATOIRE (0..399)
;===========================================================
random_coordinate:
    ; Utilise l'instruction rdrand (Intel)
    rdrand eax
    jnc random_coordinate     ; si CF=0, on recommence
    and eax, 0x3FF           ; garde 10 bits (0..1023)
    cmp eax, 400
    jge random_coordinate    ; si >= 400, on refait
    ret

;===========================================================
;   TROUVE LE FOYER LE PLUS PROCHE D'UN POINT (pointX,pointY)
;   Entrée : pointX -> EDI, pointY -> ESI
;   Sortie : EAX=foyerX_min, EDX=foyerY_min
;===========================================================
find_nearest_foyer:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    ; Conserver pointX, pointY (EDI, ESI) dans r14d, r15d
    mov     r14d, edi   ; pointX
    mov     r15d, esi   ; pointY

    mov     ecx, [num_foyers]
    cmp     ecx, 0
    jle     .no_foyer

    ; Pointeurs sur foyers_x / foyers_y
    lea     rbx, [foyers_x]
    lea     r12, [foyers_y]

    ; Charger le premier foyer
    mov     edx, [rbx]          ; foyerX
    mov     ecx, [r12]          ; foyerY

    ; calculer la distance initiale
    mov     edi, r14d           ; pointX
    mov     esi, r15d           ; pointY
    ; param3 = foyerX -> EDX
    ; param4 = foyerY -> ECX
    call    calculate_distance
    mov     r13d, eax           ; dist_min

    ; Stocker foyerX/foyerY min dans r8d/r9d
    mov     r8d, [rbx]
    mov     r9d, [r12]

    ; Boucle sur les foyers suivants
    mov     eax, [num_foyers]
    cmp     eax, 1
    jle     .done               ; s'il n'y a qu'un foyer

    xor     r10, r10
    mov     r10d, 1             ; index foyer = 1
.loop_foyers:
    ; charger foyerX, foyerY
    mov     edx, [rbx + r10*4]  ; foyerX
    mov     ecx, [r12 + r10*4]  ; foyerY

    ; calculer distance
    mov     edi, r14d          ; pointX
    mov     esi, r15d          ; pointY
    call    calculate_distance

    cmp     eax, r13d
    jge     .next_foyer
    ; si distance < dist_min, on met à jour
    mov     r13d, eax
    mov     r8d, edx           ; bestFoyerX
    mov     r9d, ecx           ; bestFoyerY

.next_foyer:
    inc     r10
    cmp     r10, [num_foyers]
    jb      .loop_foyers

.done:
    ; On place en EAX et EDX les coordonnées du foyer min
    mov     eax, r8d
    mov     edx, r9d
    jmp .fin

.no_foyer:
    ; Aucun foyer => renvoyer 0,0
    xor     eax, eax
    xor     edx, edx

.fin:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    mov     rsp, rbp
    pop     rbp
    ret

;===========================================================
;    CALCUL DE DISTANCE ENTRE (pointX, pointY) et (x2, y2)
;    Convention :
;       x1 = EDI
;       y1 = ESI
;       x2 = EDX
;       y2 = ECX
;    Retour : EAX = distance entière (sqrt).
;===========================================================
calculate_distance:
    push    rbp
    mov     rbp, rsp

    ; x1 = EDI, y1 = ESI, x2 = EDX, y2 = ECX
    ; distance = sqrt( (x1-x2)^2 + (y1-y2)^2 )

    ; On calcule (x1-x2)^2
    mov     eax, edi       ; eax = x1
    sub     eax, edx       ; eax = x1 - x2
    imul    eax, eax       ; eax = (x1 - x2)^2

    ; On calcule (y1-y2)^2 dans ebx
    mov     ebx, esi       ; y1
    sub     ebx, ecx       ; y1 - y2
    imul    ebx, ebx       ; (y1 - y2)^2

    add     eax, ebx       ; eax = somme
    ; convertir en double, racine, reconvertir en int
    cvtsi2sd xmm0, eax
    sqrtsd   xmm0, xmm0
    cvtsd2si eax, xmm0      ; distance entière dans EAX

    mov     rsp, rbp
    pop     rbp
    ret

;===========================================================
;         DESSINER UNE LIGNE ENTRE (x1,y1) et (x2,y2)
;===========================================================
draw_line:
    push    rbp
    mov     rbp, rsp

    ; XDrawLine(Display* dpy, Drawable d, GC gc,
    ;           int x1, int y1, int x2, int y2)
    ; Convention SysV AMD64 :
    ;   RDI, RSI, RDX, RCX, R8, R9, puis la pile pour le 7e argument

    mov     rdi, [display_name]   ; param1: Display*
    mov     rsi, [window]         ; param2: Drawable (la fenêtre)
    mov     rdx, [gc]             ; param3: GC
    mov     ecx, [x1]             ; param4: int x1
    mov     r8d, [y1]             ; param5: int y1
    mov     r9d, [x2]             ; param6: int x2

    push    qword [y2]            ; param7: int y2 (sur la pile)
    call    XDrawLine

    mov     rsp, rbp
    pop     rbp
    ret
