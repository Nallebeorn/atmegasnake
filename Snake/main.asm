.DEF rTemp         = r16
.DEF rRow          = r17
.DEF rDirection    = r23

.EQU NUM_COLUMNS   = 8
.EQU MAX_LENGTH    = 25


.DSEG

matrix:   .BYTE 8 //Tbh föredrar numret 7 över 8 men jag förstör det logiska beslutet bakom det -Chris //Ärligt talat (ljuger inte ens) så uppskattar jag ordet "förstör" mer än ordet "logiska" i Chris kommentar. //Vem skrev detta??? Snälla lämna en anmärkning på vem som skrev kommentaren nästa gång -Chris //Ah, sorry Chris! Det var jag. -Albin
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

     // Sätt lamppins till output
     ldi    rTemp, 0x0f
     out    DDRC, rTemp
     ldi    rTemp, 0xf0
     out    DDRD, rTemp
     ldi    rTemp, 0x3f
     out    DDRB, rTemp

     // Initialisera variabler
     ldi    rRow, 0x00

     // Aktivera och konfigurera timern
     lds    rTemp, TCCR0B
     ori    rTemp, 0x05
     out    TCCR0B, rTemp
     sei
     lds    rTemp, TIMSK0
     ori    rTemp, 0x01
     sts    TIMSK0, rTemp

loop:
     jmp    loop

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
    cpi     rRow, 0x01
    breq    row2
row1:
    // Sätt på första raden, släck andra
    sbi     PORTC, PORTC0
    cbi     PORTC, PORTC1
    // Sätt på första kolumnen, släck andra
    sbi     PORTD, PORTD6
    cbi     PORTD, PORTD7
    ldi     rRow, 0x01
    
    reti
row2:
	// Sätt på andra raden, släck första
    cbi     PORTC, PORTC0
    sbi     PORTC, PORTC1
    // Sätt på andra kolumnen, släck första
    cbi     PORTD, PORTD6
    sbi     PORTD, PORTD7
    ldi     rRow, 0x00

    reti