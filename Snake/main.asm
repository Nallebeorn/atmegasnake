.DEF rTemp         = r16
.DEF rDirection    = r23

.EQU NUM_COLUMNS   = 8
.EQU MAX_LENGTH    = 25


.DSEG

matrix:   .BYTE 8 //Tbh f�redrar numret 7 �ver 8 men jag f�rst�r det logiska beslutet bakom det -Chris //�rligt talat (ljuger inte ens) s� uppskattar jag ordet "f�rst�r" mer �n ordet "logiska" i Chris kommentar. //Vem skrev detta??? Sn�lla l�mna en anm�rkning p� vem som skrev kommentaren n�sta g�ng -Chris //Ah, sorry Chris! Det var jag. -Albin
snake:    .BYTE MAX_LENGTH+1

.CSEG
// Interrupt vector table
.ORG 0x0000
     jmp init  // Reset
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp timer  // Timer 0 overflow

init:
     // S�tt stackpekaren till h�gsta minnesadressen
     ldi	rTemp, HIGH(RAMEND)
     out	SPH, rTemp
     ldi	rTemp, LOW(RAMEND)
     out	SPL, rTemp

	 ldi	rTemp, 0xff

	 //ROWS
	 out	PORTC, rTemp
	 out	PORTD, rTemp
	 //COLUMNS (find how to integrate with the "out" method like the rest -Sebastian)
	 sbi	PORTD, PORTD6
	 sbi	PORTD, PORTD7
	 //BIG BRAIN COLUMNS
	 out	PORTB, rTemp

	 // r0 = 0b00000000
	 // r1 = 0b00000000
	 // r2 = 0b00000000
	 // r3 = 0b00000000
	 // r4 = 0b00000000
	 // r5 = 0b00000000
	 // r6 = 0b00000000
	 // r7 = 0b00000000

	 //Would there be a way to flip single 1 or 0s at will depending on light to turn on? -Sebastian

timer:
	jmp	timer