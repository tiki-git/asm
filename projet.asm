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

; Tableaux pour stocker les foyers et les points
foyers_x:	resd	1000	; Tableau pour les coordonnées x des foyers
foyers_y:	resd	1000	; Tableau pour les coordonnées y des foyers
points_x:	resd	10000	; Tableau pour les coordonnées x des points
points_y:	resd	10000	; Tableau pour les coordonnées y des points

section .data

event:		times	24 dq 0

x1:	dd	0
x2:	dd	0
y1:	dd	0
y2:	dd	0

; Constantes pour le nombre de foyers et de points
num_foyers:	dd	50	; Nombre de foyers
num_points:	dd	10000	; Nombre de points

section .text
	
;##################################################
;########### PROGRAMME PRINCIPAL ##################
;##################################################

main:
xor     rdi,rdi
call    XOpenDisplay	; Création de display
mov     qword[display_name],rax	; rax=nom du display

; display_name structure
; screen = DefaultScreen(display_name);
mov     rax,qword[display_name]
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
mov r8,400	; largeur
mov r9,400	; hauteur
push 0xFFFFFF	; background  0xRRGGBB
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

mov rsi,qword[window]
mov rdx,0
mov rcx,0
call XCreateGC
mov qword[gc],rax

mov rdi,qword[display_name]
mov rsi,qword[gc]
mov rdx,0x000000	; Couleur du crayon
call XSetForeground

; Génération aléatoire des foyers
mov ecx, dword[num_foyers]
lea rbx, [foyers_x]
lea rdx, [foyers_y]
generate_foyers:
    call random_coordinate
    mov dword[rbx + rcx*4 - 4], eax  ; Stocke la coordonnée x
    call random_coordinate
    mov dword[rdx + rcx*4 - 4], eax  ; Stocke la coordonnée y
    loop generate_foyers

; Génération aléatoire des points
mov ecx, dword[num_points]
lea rbx, [points_x]
lea rdx, [points_y]
generate_points:
    call random_coordinate
    mov dword[rbx + rcx*4 - 4], eax  ; Stocke la coordonnée x
    call random_coordinate
    mov dword[rdx + rcx*4 - 4], eax  ; Stocke la coordonnée y
    loop generate_points

; Relier chaque point au foyer le plus proche
mov ecx, dword[num_points]
lea rbx, [points_x]
lea rdx, [points_y]
connect_points:
    mov eax, dword[rbx + rcx*4 - 4]  ; Coordonnée x du point
    mov edi, dword[rdx + rcx*4 - 4]  ; Coordonnée y du point
    call find_nearest_foyer
    ; Dessiner une ligne entre le point et le foyer le plus proche
    mov dword[x1], eax
    mov dword[y1], edi
    mov dword[x2], esi
    mov dword[y2], edx
    call draw_line
    loop connect_points

boucle: ; boucle de gestion des évènements
mov rdi,qword[display_name]
mov rsi,event
call XNextEvent

cmp dword[event],ConfigureNotify	; à l'apparition de la fenêtre
je dessin							; on saute au label 'dessin'

cmp dword[event],KeyPress			; Si on appuie sur une touche
je closeDisplay						; on saute au label 'closeDisplay' qui ferme la fenêtre
jmp boucle

;#########################################
;#		DEBUT DE LA ZONE DE DESSIN		 #
;#########################################
dessin:

; ############################
; # FIN DE LA ZONE DE DESSIN #
; ############################
jmp flush

flush:
mov rdi,qword[display_name]
call XFlush
jmp boucle
mov rax,34
syscall

closeDisplay:
    mov     rax,qword[display_name]
    mov     rdi,rax
    call    XCloseDisplay
    xor	    rdi,rdi
    call    exit

; Fonction pour générer une coordonnée aléatoire entre 0 et 399
random_coordinate:
    rdrand eax
    jnc random_coordinate  ; Si CF=0, on recommence
    and eax, 0x3FF         ; On garde les 10 bits de poids faible (0-1023)
    cmp eax, 400
    jge random_coordinate  ; Si >= 400, on recommence
    ret

; Fonction pour trouver le foyer le plus proche
find_nearest_foyer:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    mov rbp, rsp

    mov ecx, dword[num_foyers]
    lea rbx, [foyers_x]
    lea rdx, [foyers_y]
    mov esi, dword[rbx]  ; Premier foyer
    mov edi, dword[rdx]
    call calculate_distance
    mov ebp, eax  ; Distance minimale

    mov r8d, esi  ; Coordonnées du foyer le plus proche
    mov r9d, edi

    dec ecx
    jz .done

.find_loop:
    mov esi, dword[rbx + rcx*4]
    mov edi, dword[rdx + rcx*4]
    call calculate_distance
    cmp eax, ebp
    jge .next
    mov ebp, eax
    mov r8d, esi
    mov r9d, edi
.next:
    loop .find_loop

.done:
    mov eax, r8d
    mov edi, r9d
    mov rsp, rbp
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Fonction pour calculer la distance entre deux points
calculate_distance:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    mov rbp, rsp

    sub eax, esi
    imul eax, eax
    sub edi, edx
    imul edi, edi
    add eax, edi
    cvtsi2sd xmm0, eax
    sqrtsd xmm0, xmm0
    cvtsd2si eax, xmm0

    mov rsp, rbp
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Fonction pour dessiner une ligne entre deux points
draw_line:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    mov rbp, rsp

    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, qword[gc]
    mov ecx, dword[x1]
    mov r8d, dword[y1]
    mov r9d, dword[x2]
    push qword[y2]
    call XDrawLine

    mov rsp, rbp
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret