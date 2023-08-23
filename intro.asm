;  "Waves" - tiny intro for Sony Playstation 1 (PSX). MIPS R3000
;  by frog //ROi, frog@enlight.ru
;
; Plasma-like effect + wave-like sound


GP0 		equ 	$1810            
GP1 		equ 	$1814            
DPCR 		equ 	$10f0            
DICR 		equ 	$10f4
D2_MADR 	equ 	$10a0
D2_BCR 		equ 	$10a4
D2_CHCR 	equ 	$10a8


		org 	$80010000


		addiu	fp,zero,0	; init global [frame] counter



; ========= INIT SPU

		lui k1,$1F80           ; I/O base


		li t0,$ea30		; 1100000100110000 enable noise (no adpcm)
		sh t0,$1DAA(k1)        ; SPU_CONTROL

		li t0,$3fff             ; master volume = 011111111111111

		sh t0,$1d80(k1)        ; master volume left
		sh t0,$1d82(k1)        ; master volume right


		sh t0,$1C00(k1)        ; volume left
		sh t0,$1C02(k1)        ; volume right

		li t0,$1010		; SPU buffer address

		sh t0,$1C06(k1)        ; set SPU buffer address 


		li t0,$bf3f		; 1011111100111111
		sh t0,$1c08(k1)        ; SPU_CH_ADSR1

		li t0,$cfff		; 1100111111111111
		sh t0,$1c0a(k1)        ; SPU_CH_ADSR2

		li t0,1
		sh t0,$1d94(k1)        ; SPU_NOISE_MODE1
		sh t0,$1d88(k1)        ; SPU_KEY_ON1


; ========= INIT GPU

		
		li 	k1, $1f800000            ; set to hardware base

		li 	a0, $0800002f            ; 640x480, PAL, interlaced

		sw 	zero, GP1(k1)            ; reset

		li 	t2, $03000001
		sw 	t2, GP1(k1)              ; disable display
	
		li 	t2, $06c40240            ; horiz start/end (command $06.  c40  240)
		sw 	t2, GP1(k1)
	
		li 	t2, $07049025            ; vert start/end (command $07.  start , end = $490 - $25 = 1131) 
		sw 	t2, GP1(k1)              
                        
; 1110 0001 0000 0000 0000 0110 1000 0101                        
;
		li 	t2, $e10006a5            ; draw mode, texture page = (8bit,320,0)  6e5, 6c5, 6a5
		jal 	WaitGPU
		nop
		sw 	t2, GP0(k1)
					
		jal 	WaitGPU

; bits 0-9 - X, bits $0a-13 - Y            
		li 	t2, $e3000000            ; command $e3 - clip start (set top left corner to draw 0,0)
		sw 	t2, GP0(k1)

; bits 0-9 - X, bits $0a-13 - Y
		li 	t2, $e4077e7f   ; command $e4 - clip end (set bottom right corner ) $e407fd3f for 320x240
		
		jal 	WaitGPU
		nop
		sw 	t2, GP0(k1)
            
; command $05
; bits 0-9: hor. offset (0-1023)
; bits 10-18: vert offset (0-512)

		li 	t2, $05000000            ; display offset ( Upper/left Display source address in VRAM.)
		jal 	WaitGPU
		nop
		sw 	t2, GP0(k1)
		
		li 	t2, $e5000000            ; draw offset 
		jal 	WaitGPU
		nop
		sw 	t2, GP0(k1)
  
; $08000009  =  1000 0000 0000 0000 0000 0000 1001   = 320, PAL
; command $08:
; bits 1,0: h.res: 00 - 256, 01 - 320, 10 - 512, 11 - 640
; bit 2: v.res: 0 - 240, 1 - 480
; bit 3: pal/ntsc: 0 - PAL, 1 - NTSC
; bit 4: color mode: 1 - 24bit, 0 - 15bit
; bit 5: 1 - interlaced, 0 - non-interlaced
; bit 6: if 1 and bits 0,1 = 0,0 then h.res=384.

		sw 	a0, GP1(k1)              ; set display mode       
			
		li 	t2, $03000000
		sw 	t2, GP1(k1)              ; enable display
		




; InitPads - initialize joypads, also necessary for vsync wait routine

InitPads    
		li 	t1, $15        
		li 	a0, $20000001
		li 	t2, $b0
		la 	a1, pad_buf
		jalr 	t2         ; call $b0
		nop



; start from
		addiu	s0,zero,20	
		addiu	s1,zero,0	
		addiu	s2,zero,90	

; initial steps (for each corner)
		addiu	s3,zero,3	
		addiu	s4,zero,1	
		addiu	s5,zero,3	
		addiu	s6,zero,1	


; ===========  MAIN LOOP ===============

loop:

		addu	fp,fp,1		; fp = fp + 1   global counter
	
		addiu	at, zero,$230	; counter value 1
		
		bne	fp,at,skip_restart_counter
		nop

		addiu	fp,zero,0	; reset global counter

; restart noise
		li t0,1
		sh t0,$1d88(k1)        ; SPU_KEY_ON1

skip_restart_counter:



            
;       wait for vertical retrace period
_WaitVSync
		lw 	t0, pad_buf
		lui 	t1, $ffff
		beqz 	t0, _WaitVSync
		ori 	t1, $ffff
		sw 	zero, pad_buf
		xor 	t0,t1                   ; reverse bits
		sw 	t0, pad_data



; SendList - sends a list of primitives to GPU

		li 	t2, $04000002


		lw 	t3, DPCR(k1)
		sw 	zero, DICR(k1)
		ori 	t3, $800
		sw 	t3, DPCR(k1)


		sw 	t2, GP1(k1)

		la 	a0, list    
		sw 	a0, D2_MADR(k1)  ; display list addr
		sw 	zero, D2_BCR(k1)
		li 	t1, $01000401
		sw 	t1, D2_CHCR(k1)
         
	
; CORNER LT
		lw	t0, corner_lt

		jal 	unpack_color	; in: t0  out: s0,s1,s2
		nop

; inc/dec B

		add	a0, s0, zero	; s0 -> a0  value
		add	a1, s3, zero	; s3 -> a1  step
		jal	change
		nop
		add	s3, a1, zero	; a1 -> s3 restore step
		add	s0, a0, zero	; a0 -> s0 restore value



		jal 	pack_color	; in: s0,s1,s2 out: t0
		nop
		
		sw	t0, corner_lt



; CORNER RT
		lw	t0, corner_rt

		jal 	unpack_color	; in: t0  out: s0,s1,s2
		nop

; inc/dec B

		add	a0, s0, zero	; s0 -> a0  value
		add	a1, s4, zero	; s4 -> a1  step
		jal	change
		nop
		add	s4, a1, zero	; a1 -> s4 restore step
		add	s0, a0, zero	; a0 -> s0 restore value


		jal 	pack_color	; in: s0,s1,s2 out: t0
		nop
		
		sw	t0, corner_rt


; CORNER LB
		lw	t0, corner_lb

		jal 	unpack_color	; in: t0  out: s0,s1,s2
		nop

; inc/dec B

		add	a0, s0, zero	; s0 -> a0  value
		add	a1, s5, zero	; s5 -> a1  step
		jal	change
		nop
		add	s5, a1, zero	; a1 -> s5 restore step
		add	s0, a0, zero	; a0 -> s0 restore value



		jal 	pack_color	; in: s0,s1,s2 out: t0
		nop
		
		sw	t0, corner_lb



; CORNER RB
		lw	t0, corner_rb

		jal 	unpack_color	; in: t0  out: s0,s1,s2
		nop

; inc/dec B

		add	a0, s0, zero	; s0 -> a0  value
		add	a1, s6, zero	; s6 -> a1  step
		jal	change
		nop
		add	s6, a1, zero	; a1 -> s6 restore step
		add	s0, a0, zero	; a0 -> s0 restore value



		jal 	pack_color	; in: s0,s1,s2 out: t0
		nop
		
		sw	t0, corner_rb



            	j   	loop
            	nop


; ---------------------------------------------- subroutines ------------------------------------------------


    
            
; WaitGPU - waits until GPU ready to receive commands
            
WaitGPU                     

		lw 	t1, GP1(k1)             
		li 	t0, $10000000
		and 	t1, t1, t0
		beqz 	t1, WaitGPU
		nop
		jr 	ra
		nop  
            
; combine RGB with command to get $CCBBGGRR
;; in: s0,s1,s2 out: t0

pack_color:
;   change colors at corners


	        lui	t0, $3800	; $38 - command gradated poly, non-transparent (3a - transparent)
	

	        sll	at,s0,16
	        or	t0,t0,at
	
	        sll	at,s1,8
	        or	t0,t0,at

	        or	t0,t0,s2	; t0 contains complete CCBBGGRR


		jr	ra
		nop


; unpack $CCBBGGRR to RGB
; in: t0  out: s0,s1,s2
unpack_color:

		and	s2,t0,$000000ff	; RR -> s2
		and	s1,t0,$0000ff00	
		srl	s1,s1,8		; GG -> s1
		srl	s0,t0,16		
		and	s0,s0,$000000ff	; BB -> s0


		jr	ra
		nop


; on every call inc reg until $ff then dec until $00 (so, value always within 00-ff to use as correct color channel value)

; in: a0 - what to change, a1 - step

change:

; inc w

		addu	a0,a0,a1	; B = B + a1

		li	at, $ff		; count to
		bne 	a0,at,skip1		
		nop

		 
		 
		sub	a1,zero,a1	; negate a1 (change counting direction)

skip1:		 

		bne	a0,zero,skip2	; count from (0)
		nop

		sub	a1,zero,a1	; negate a1 (change counting direction)

		addiu	a1,zero,1	; fix

skip2:		
		jr	ra
		nop


; ----------------------------------------------- data -----------------------------------------

align 4

; display list

; header { size(hi byte), pointer to next element (other bytes. $ffffff if last) }
; packet { type (hi byte), ... }

list




; gouraud shaded 4 point polygon

poly4_g:
    		db $ff, $ff, $ff, $8   ; link to next list element ($ff - last element), size of current element

corner_lt:    
	    	dw $38000000    ; $38 - gradated 4p poly ($3A with transparency, $38 w/o transparency). CCBBGGRR (C - command, b,g,r - color0)
    		dw $10000000    ; y0 x0
corner_rt:    
    		dw $30400000    ; color 1
    		dw $0000027f    ; y1 x1
corner_lb:    
    		dw $30c00000    ; color 2
    		dw $01e00000    ; y2 x2
corner_rb:    
    		dw $30800000    ; color 3
    		dw $01e0027f    ; y3 x3



pad_buf 	dw 0    	; pad data is automatically stored here every frame
pad_data 	dw 0   		; pad data copied here (read it from here if using the WaitVSync routine)


