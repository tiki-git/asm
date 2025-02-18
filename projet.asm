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
%define KeyPressMask        1
%define ButtonPressMask     4
%define MapNotify           19
%define KeyPress            2
%define ButtonPress         4
%define Expose              12
%define ConfigureNotify     22
%define CreateNotify        16
%define QWORD               8
%define DWORD               4
%define WORD                2
%define BYTE                1

global main

section .bss
display_name:   resq    1
screen:         resd    1
depth:          resd    1
connection:     resd    1
width:          resd    1
height:         resd    1
window:         resq    1
gc:             resq    1

; Tableaux pour stocker les foyers et les points
foyers_x:       resd    1000    ; Coordonnées x des foyers
foyers_y:       resd    1000    ; Coordonnées y des foyers
points_x:       resd    10000   ; Coordonnées x des points
points_y:       resd    10000   ; Coordonnées y des points

section .data
event:          times   24 dq 0
x1:             dd      0
x2:             dd      0
y1:             dd      0
y2:             dd      0

; Constantes configurables
num_foyers:     dd      50      ; Nombre de foyers (max 1000)
num_points:     dd      10000   ; Nombre de points (max 10000)

section .text

;##################################################
;########### PROGRAMME PRINCIPAL ##################
;##################################################

main:
    xor     rdi, rdi
    call    XOpenDisplay            ; Création du display X11
    mov     qword[display_name], rax

    ; Configuration de la fenêtre
    mov     rax, qword[display_name]
    mov     eax, dword[rax + 0xe0]
    mov     dword[screen], eax

    mov     rdi, qword[display_name]
    mov     esi, dword[screen]
    call    XRootWindow
    mov     rbx, rax

    mov     rdi, qword[display_name]
    mov     rsi, rbx
    mov     rdx, 10
    mov     rcx, 10
    mov     r8, 400                 ; Largeur de la fenêtre
    mov     r9, 400                 ; Hauteur de la fenêtre
    push    0xFFFFFF                ; Couleur de fond
    push    0x00FF00
    push    1
    call    XCreateSimpleWindow
    mov     qword[window], rax

    ; Configuration des événements
    mov     rdi, qword[display_name]
    mov     rsi, qword[window]
    mov     rdx, 131077             ; Masque d'événements
    call    XSelectInput

    ; Affichage de la fenêtre
    mov     rdi, qword[display_name]
    mov     rsi, qword[window]
    call    XMapWindow

    ; Création du contexte graphique
    mov     rsi, qword[window]
    mov     rdx, 0
    mov     rcx, 0
    call    XCreateGC
    mov     qword[gc], rax

    ; Définition de la couleur par défaut (noir)
    mov     rdi, qword[display_name]
    mov     rsi, qword[gc]
    mov     rdx, 0x000000
    call    XSetForeground

    ; Génération aléatoire des foyers
    call    generate_foyers

    ; Génération aléatoire des points
    call    generate_points

    ; Relier chaque point au foyer le plus proche
    call    connect_points

    ; Boucle principale de gestion des événements
event_loop:
    mov     rdi, qword[display_name]
    mov     rsi, event
    call    XNextEvent

    cmp     dword[event], ConfigureNotify
    je      dessin
    cmp     dword[event], KeyPress
    je      close_display
    jmp     event_loop

dessin:
    jmp     flush

flush:
    mov     rdi, qword[display_name]
    call    XFlush
    jmp     event_loop

close_display:
    mov     rax, qword[display_name]
    mov     rdi, rax
    call    XCloseDisplay
    xor     rdi, rdi
    call    exit

;---------------------------------------------------------------------
; Fonctions utilitaires
;---------------------------------------------------------------------

; Génère une coordonnée aléatoire entre 0 et 399
random_coordinate:
    rdrand  eax
    jnc     random_coordinate      ; Réessayer si CF=0
    and     eax, 0x3FF             ; Masque pour 0-1023
    cmp     eax, 400
    jge     random_coordinate      ; Limiter à 399
    ret

; Génération aléatoire des foyers
generate_foyers:
    mov     ecx, dword[num_foyers]
    lea     rbx, [foyers_x]
    lea     rdx, [foyers_y]
.generate_foyers_loop:
    call    random_coordinate
    mov     dword[rbx + rcx*4 - 4], eax  ; Stockage x
    call    random_coordinate
    mov     dword[rdx + rcx*4 - 4], eax  ; Stockage y
    loop    .generate_foyers_loop
    ret

; Génération aléatoire des points
generate_points:
    mov     ecx, dword[num_points]
    lea     rbx, [points_x]
    lea     rdx, [points_y]
.generate_points_loop:
    call    random_coordinate
    mov     dword[rbx + rcx*4 - 4], eax  ; Stockage x
    call    random_coordinate
    mov     dword[rdx + rcx*4 - 4], eax  ; Stockage y
    loop    .generate_points_loop
    ret

; Relier chaque point au foyer le plus proche
connect_points:
    mov     r15d, dword[num_points]       ; r15d pour la boucle externe
    lea     rbx, [points_x]
    lea     rdx, [points_y]
.connect_loop:
    mov     eax, dword[rbx + r15*4 - 4]  ; x du point
    mov     edi, dword[rdx + r15*4 - 4]  ; y du point
    call    find_nearest_foyer
    mov     dword[x1], eax
    mov     dword[y1], edi
    mov     dword[x2], esi
    mov     dword[y2], edx
    call    draw_line
    dec     r15d
    jnz     .connect_loop
    ret

; Trouve le foyer le plus proche d'un point (x = eax, y = edi)
find_nearest_foyer:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    r10              ; Sauvegarde r10 pour l'indice du meilleur foyer

    mov     r12d, eax        ; Sauvegarde x du point
    mov     r13d, edi        ; Sauvegarde y du point
    mov     r14d, dword[num_foyers]
    lea     rbx, [foyers_x]
    lea     r15, [foyers_y]

    ; Initialisation avec le premier foyer
    mov     esi, dword[rbx]      ; x du premier foyer
    mov     edi, dword[r15]      ; y du premier foyer
    call    calculate_distance
    mov     ecx, eax           ; Distance minimale
    mov     r10d, 0            ; Meilleur indice initial = 0

    ; Parcourir les autres foyers
    mov     r9d, 1
.search_loop:
    cmp     r9d, r14d
    jge     .done

    mov     esi, dword[rbx + r9d*4]  ; x du foyer courant
    mov     edi, dword[r15 + r9d*4]  ; y du foyer courant
    call    calculate_distance
    cmp     eax, ecx
    jge     .next
    mov     ecx, eax           ; Nouvelle distance minimale
    mov     r10d, r9d          ; Sauvegarde l'indice du foyer le plus proche
.next:
    inc     r9d
    jmp     .search_loop

.done:
    mov     eax, r12d          ; Restaurer x du point
    mov     edi, r13d          ; Restaurer y du point
    mov     esi, dword[rbx + r10*4]  ; x du foyer le plus proche
    mov     edx, dword[r15 + r10*4]  ; y du foyer le plus proche

    pop     r10
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    mov     rsp, rbp
    pop     rbp
    ret

; Calcule la distance entre deux points 
; (point1 : x1=eax, y1=edi) et (point2 : x2=esi, y2=edx)
calculate_distance:
    sub     eax, esi
    imul    eax, eax              ; (x1 - x2)^2
    sub     edi, edx
    imul    edi, edi              ; (y1 - y2)^2
    add     eax, edi              ; Somme des carrés
    cvtsi2sd xmm0, eax
    sqrtsd  xmm0, xmm0            ; Racine carrée
    cvtsd2si eax, xmm0
    ret

; Dessine une ligne entre (x1,y1) et (x2,y2)
draw_line:
    push    rdi
    push    rsi
    push    rdx
    push    rcx
    push    r8
    push    r9

    mov     rdi, qword[display_name]
    mov     rsi, qword[window]
    mov     rdx, qword[gc]
    mov     ecx, dword[x1]
    mov     r8d, dword[y1]
    mov     r9d, dword[x2]
    push    qword[y2]
    call    XDrawLine

    pop     r9
    pop     r8
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi
    ret
