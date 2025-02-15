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
    
    ; Ouvrir la connexion au serveur X11
    xor     rdi, rdi          ; NULL pour l'affichage par défaut
    call    XOpenDisplay
    test    rax, rax          ; Vérifier si l'affichage est ouvert
    jz      closeDisplay      ; Quitter si l'affichage n'est pas ouvert
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
    mov     r8, [width]      ; largeur
    mov     r9, [height]     ; hauteur
    push    0x000000         ; background  0xRRGGBB
    push    0x00FF00
    push    1
    call    XCreateSimpleWindow
    mov     [window], rax

    ; Configurer les événements de la fenêtre
    mov     rdi, [display_name]
    mov     rsi, [window]
    mov     rdx, 131077      ; StructureNotifyMask | KeyPressMask | ButtonPressMask
    call    XSelectInput

    ; Afficher la fenêtre
    mov     rdi, [display_name]
    mov     rsi, [window]
    call    XMapWindow

    ; Créer le contexte graphique
    mov     rdi, [display_name]
    mov     rsi, [window]
    xor     rdx, rdx         ; No mask
    xor     rcx, rcx         ; No values
    call    XCreateGC
    test    rax, rax         ; Vérifier si le GC est créé
    jz      closeDisplay     ; Quitter si le GC n'est pas créé
    mov     [gc], rax

    ; Définir la couleur du crayon
    mov     rdi, [display_name]
    mov     rsi, [gc]
    mov     edx, 0xFF0000    ; Couleur rouge
    call    XSetForeground

    ; Générer les foyers
    call    generate_foyers

    ; Boucle principale de gestion des événements
boucle:
    mov     rdi, [display_name]
    mov     rsi, event
    call    XNextEvent

    cmp     dword[event], ConfigureNotify ; Si la fenêtre est configurée
    je      dessin

    cmp     dword[event], KeyPress        ; Si une touche est pressée
    je      closeDisplay
    jmp     boucle

dessin:
    ; Relier les points aux foyers
    call    relier_points
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
    ; Générer une coordonnée x aléatoire
    mov     ecx, [width]
    call    generate_random
    mov     [tableau_x_foyers + r14 * 4], r12d

    ; Générer une coordonnée y aléatoire
    mov     ecx, [height]
    call    generate_random
    mov     [tableau_y_foyers + r14 * 4], r12d

    ; Incrémenter le compteur
    inc     r14

    ; Vérifier si tous les foyers sont générés
    cmp     r14d, [nb_foyers]
    jl      boucle_foyers
    ret

; Relier les points aux foyers
relier_points:
    xor     r14, r14
boucle_points:
    ; Vérifier si tous les points sont traités
    cmp     r14d, [nb_points]
    jge     flush

    ; Générer une coordonnée x aléatoire
    mov     ecx, [width]
    call    generate_random
    mov     [x1], r12d

    ; Générer une coordonnée y aléatoire
    mov     ecx, [height]
    call    generate_random
    mov     [y1], r12d

    ; Trouver le foyer le plus proche
    call    trouver_foyer_proche

    ; Dessiner la ligne
    mov     rdi, [display_name]
    mov     rsi, [window]
    mov     rdx, [gc]
    mov     ecx, [x1]
    mov     r8d, [y1]
    mov     r9d, [x2]
    sub     rsp, 16
    mov     eax, [y2]
    mov     [rsp], rax
    call    XDrawLine
    add     rsp, 16

    ; Passer au point suivant
    inc     r14
    jmp     boucle_points

; Trouver le foyer le plus proche
trouver_foyer_proche:
    xor     r15d, r15d
    mov     dword [distance_min], 0x7FFFFFFF
boucle_foyers_point:
    ; Vérifier si tous les foyers sont parcourus
    cmp     r15d, [nb_foyers]
    jge     suite_boucle_foyers_point

    ; Calculer la distance au carré
    mov     rdi, [tableau_x_foyers + r15d * 4]
    mov     rsi, [tableau_y_foyers + r15d * 4]
    mov     rdx, [x1]
    mov     rcx, [y1]
    call    calc_squared_distance

    ; Comparer avec la distance minimale
    cmp     r12d, [distance_min]
    jl      sauvegarde_distance

suite_boucle_foyers_point:
    ; Passer au foyer suivant
    inc     r15d
    jmp     boucle_foyers_point

sauvegarde_distance:
    ; Sauvegarder la distance et l'identifiant du foyer
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

; Gestion des erreurs
erreur:
    ; Afficher un message d'erreur
    mov     rdi, error_message
    xor     eax, eax
    call    printf
    jmp     closeDisplay