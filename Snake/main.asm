.DEF rTemp         = r16
.DEF rDirection    = r23

.EQU NUM_COLUMNS   = 8
.EQU MAX_LENGTH    = 25


.DSEG

matrix:   .BYTE 8 //Tbh föredrar numret 7 över 8 men jag förstår det logiska beslutet bakom det -Chris //Ärligt talat (ljuger inte ens) så uppskattar jag ordet "förstår" mer än ordet "logiska" i Chris kommentar. //Vem skrev detta??? Snälla lämna en anmärkning på vem som skrev kommentaren nästa gång -Chris //Ah, sorry Chris! Det var jag. -Albin
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
     // Sätt stackpekaren till högsta minnesadressen
     ldi	rTemp, HIGH(RAMEND)
     out	SPH, rTemp
     ldi	rTemp, LOW(RAMEND)
     out	SPL, rTemp

	 sbi	PORTC, PORTC0
	 sbi	PORTD, PORTD6
	 sbi	PORTD, PORTD7
	 ldi	rTemp, 0x3f
	 out	PORTB, rTemp

timer:
	jmp	timer