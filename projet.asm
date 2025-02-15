; external functions from X11 library
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

; external functions from stdio library (ld-linux-x86-64.so.2)    
extern printf
extern exit

%define	StructureNotifyMask	131072
%define KeyPressMask		1
%define ButtonPressMask		4
%define MapNotify		19
%define KeyPress		2
%define ButtonPress		4
%define Expose			12
%define ConfigureNotify		22
%define CreateNotify 16
%define QWORD	8
%define DWORD	4
%define WORD	2
%define BYTE	1

global main

section .bss
display_name:	resq	1
screen:			resd	1
depth:         	resd	1
connection:    	resd	1
width:         	resd	1
height:        	resd	1
window:		resq	1
gc:		resq	1

; Tableaux pour stocker les coordonnées des foyers et des points
foyers_x: resd 100     ; Tableau pour les coordonnées x des foyers (max 100 foyers)
foyers_y: resd 100     ; Tableau pour les coordonnées y des foyers
points_x: resd 10000   ; Tableau pour les coordonnées x des points (max 10000 points)
points_y: resd 10000   ; Tableau pour les coordonnées y des points

section .data
event:		times	24 dq 0

; Variables pour les coordonnées des points et des foyers
x1:	dd	0
x2:	dd	0
y1:	dd	0
y2:	dd	0

; Paramètres pour la génération des points
num_foyers: dd 5       ; Nombre de foyers (réduit pour le débogage)
num_points: dd 100      ; Nombre de points (réduit pour le débogage)

section .text
	
;##################################################
;########### PROGRAMME PRINCIPAL ##################
;##################################################

main:
    ; Initialisation de la fenêtre
    xor     rdi, rdi
    call    XOpenDisplay	; Création de display
    mov     qword[display_name], rax	; rax = nom du display

    ; display_name structure
    ; screen = DefaultScreen(display_name);
    mov     rax, qword[display_name]
    mov     eax, dword[rax+0xe0]
    mov     dword[screen], eax

    mov rdi, qword[display_name]
    mov esi, dword[screen]
    call XRootWindow
    mov rbx, rax

    mov rdi, qword[display_name]
    mov rsi, rbx
    mov rdx, 10
    mov rcx, 10
    mov r8, 400	; largeur
    mov r9, 400	; hauteur
    push 0xFFFFFF	; background  0xRRGGBB
    push 0x00FF00
    push 1
    call XCreateSimpleWindow
    mov qword[window], rax

    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, 131077 ;131072
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
    mov rdx, 0x000000	; Couleur du crayon
    call XSetForeground

    ; Génération des foyers et des points
    call generate_points

    ; Relier les points aux foyers les plus proches
    call relier_points

    ; Boucle principale pour gérer les événements
    boucle:
        mov rdi, qword[display_name]
        mov rsi, event
        call XNextEvent

        cmp dword[event], ConfigureNotify	; à l'apparition de la fenêtre
        je dessin							; on saute au label 'dessin'

        cmp dword[event], KeyPress			; Si on appuie sur une touche
        je closeDisplay						; on saute au label 'closeDisplay' qui ferme la fenêtre
        jmp boucle

    ;#########################################
    ;#		DEBUT DE LA ZONE DE DESSIN		 #
    ;#########################################
    dessin:
        ; Dessin des points et des lignes (déjà fait dans relier_points)
        jmp flush

    flush:
        mov rdi, qword[display_name]
        call XFlush
        jmp boucle
        mov rax, 34
        syscall

    closeDisplay:
        mov     rax, qword[display_name]
        mov     rdi, rax
        call    XCloseDisplay
        xor	    rdi, rdi
        call    exit

;##################################################
;########### FONCTIONS PERSONNALISÉES #############
;##################################################

; Fonction pour générer un nombre aléatoire entre 0 et x
; Entrée : rdi = x (valeur maximale)
; Sortie : rax = nombre aléatoire entre 0 et x
random:
    rdrand ax          ; Génère un nombre aléatoire de 16 bits dans ax
    jnc random         ; Si CF = 0, recommence (nombre non valide)
    xor rdx, rdx       ; Clear rdx pour la division
    div di             ; Divise ax par di (x), reste dans dx
    movzx rax, dx      ; Retourne le reste (nombre entre 0 et x-1)
    ret

; Fonction pour générer les foyers et les points
generate_points:
    ; Génération des foyers
    mov ecx, [num_foyers]  ; Nombre de foyers
    lea rsi, [foyers_x]    ; Adresse du tableau des x des foyers
    lea rdi, [foyers_y]    ; Adresse du tableau des y des foyers
generate_foyers_loop:
    mov rdi, 400           ; Génère x entre 0 et 399
    call random
    mov [rsi], eax         ; Stocke x dans foyers_x
    mov rdi, 400           ; Génère y entre 0 et 399
    call random
    mov [rdi], eax         ; Stocke y dans foyers_y
    add rsi, 4             ; Passe à l'élément suivant dans foyers_x
    add rdi, 4             ; Passe à l'élément suivant dans foyers_y
    loop generate_foyers_loop

    ; Génération des points
    mov ecx, [num_points]  ; Nombre de points
    lea rsi, [points_x]    ; Adresse du tableau des x des points
    lea rdi, [points_y]    ; Adresse du tableau des y des points
generate_points_loop:
    mov rdi, 400           ; Génère x entre 0 et 399
    call random
    mov [rsi], eax         ; Stocke x dans points_x
    mov rdi, 400           ; Génère y entre 0 et 399
    call random
    mov [rdi], eax         ; Stocke y dans points_y
    add rsi, 4             ; Passe à l'élément suivant dans points_x
    add rdi, 4             ; Passe à l'élément suivant dans points_y
    loop generate_points_loop
    ret

; Fonction pour relier les points aux foyers les plus proches
relier_points:
    mov ecx, [num_points]  ; Nombre de points
    lea rsi, [points_x]    ; Adresse du tableau des x des points
    lea rdi, [points_y]    ; Adresse du tableau des y des points
relier_points_loop:
    mov eax, [rsi]         ; x du point
    mov ebx, [rdi]         ; y du point
    call trouver_foyer_plus_proche  ; Trouve le foyer le plus proche
    ; Dessine une ligne entre le point et le foyer
    mov rdi, [display_name]
    mov rsi, [window]
    mov rdx, [gc]
    mov ecx, eax           ; x du foyer
    mov r8d, ebx           ; y du foyer
    mov r9d, [rsi]         ; x du point
    push qword [rdi]       ; y du point
    call XDrawLine
    add rsi, 4             ; Passe au point suivant
    add rdi, 4
    loop relier_points_loop
    ret

; Fonction pour trouver le foyer le plus proche
trouver_foyer_plus_proche:
    ; Initialisation des variables
    mov edx, 0x7FFFFFFF    ; Initialise la distance minimale à une grande valeur
    mov r8d, 0             ; Index du foyer le plus proche
    mov r9d, [num_foyers]  ; Nombre de foyers
    lea r10, [foyers_x]    ; Adresse du tableau des x des foyers
    lea r11, [foyers_y]    ; Adresse du tableau des y des foyers

trouver_foyer_loop:
    ; Charge les coordonnées du foyer courant
    mov esi, [r10 + r8 * 4]  ; x du foyer
    mov edi, [r11 + r8 * 4]  ; y du foyer

    ; Calcule la distance entre le point et le foyer
    sub esi, eax           ; x1 - x2
    imul esi, esi          ; (x1 - x2)^2
    sub edi, ebx           ; y1 - y2
    imul edi, edi          ; (y1 - y2)^2
    add esi, edi           ; (x1 - x2)^2 + (y1 - y2)^2

    ; Compare avec la distance minimale
    cmp esi, edx
    jge next_foyer         ; Si la distance est plus grande, passe au foyer suivant
    mov edx, esi           ; Sinon, met à jour la distance minimale
    mov r8d, ecx           ; Met à jour l'index du foyer le plus proche

next_foyer:
    inc ecx                ; Passe au foyer suivant
    cmp ecx, r9d           ; Vérifie si tous les foyers ont été parcourus
    jl trouver_foyer_loop

    ; Retourne les coordonnées du foyer le plus proche
    mov eax, [r10 + r8 * 4]  ; x du foyer le plus proche
    mov ebx, [r11 + r8 * 4]  ; y du foyer le plus proche
    ret