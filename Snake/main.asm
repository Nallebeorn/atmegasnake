// Interrupt registers
.DEF rTemp         = r16
.DEF rRow          = r17
.DEF rStatus       = r3
.DEF rUpdate       = r22
// Not interrupt registers
.DEF rTemp2        = r18
.DEF rJoyX         = r19
.DEF rJoyY         = r20
.DEF rMask         = r21
.DEF rDirection    = r23

.EQU NUM_COLUMNS   = 8
.EQU MAX_LENGTH    = 25
.EQU UPDATE_INTERVAL = 128


.DSEG

matrix:   .BYTE 8 //Tbh föredrar numret 7 över 8 men jag förstör det logiska beslutet bakom det -Chris //Ärligt talat (ljuger inte ens) så uppskattar jag ordet "förstör" mer än ordet "logiska" i Chris kommentar. //Vem skrev detta??? Snälla lämna en anmärkning på vem som skrev kommentaren nästa gång -Chris //Ah, sorry Chris! Det var jag. -Albin
snakeX:   .BYTE MAX_LENGTH+1
snakeY:   .BYTE MAX_LENGTH+1

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
     ldi    rTemp, 0xfc
     out    DDRD, rTemp
     ldi    rTemp, 0x3f
     out    DDRB, rTemp

     // Initialisera variabler
     ldi    rRow, 0x00
     ldi    rTemp, 0x04
     sts    snakeX, rTemp
     sts    snakeY, rTemp
     ldi    rUpdate, 0x00

     // Fyll matris
/*     ldi    rTemp, 0b00000000
     sts    matrix + 0, rTemp
     ldi    rTemp, 0b00100100
     sts    matrix + 1, rTemp
     ldi    rTemp, 0b00100100
     sts    matrix + 2, rTemp
     ldi    rTemp, 0b00000000
     sts    matrix + 3, rTemp

     ldi    rTemp, 0b01000010
     sts    matrix + 4, rTemp
     ldi    rTemp, 0b00111100
     sts    matrix + 5, rTemp
     ldi    rTemp, 0b00000000
     sts    matrix + 6, rTemp
     ldi    rTemp, 0b00000000
     sts    matrix + 7, rTemp*/

	 // Aktivera och konfigurera A/D-omvandling for joystickavläsning
     ldi    rTemp, 0b01100000
     sts    ADMUX, rTemp
     ldi    rTemp, 0b10000111
     sts    ADCSRA, rTemp

     // Aktivera och konfigurera timern
     lds    rTemp, TCCR0B
     ori    rTemp, 0x02
     out    TCCR0B, rTemp
     sei
     lds    rTemp, TIMSK0
     ori    rTemp, 0x01
     sts    TIMSK0, rTemp

loop:
    cpi     rUpdate, UPDATE_INTERVAL
    brlo    loop
    ldi     rUpdate, 0x00

// A/D-omvandling
// X-axel
	lds     rTemp2, ADMUX
    andi    rTemp2, 0xf0
    ori     rTemp2, 0x05
    sts     ADMUX, rTemp2
    lds     rTemp2, ADCSRA
    ori     rTemp2, 1 << ADSC
    sts     ADCSRA, rTemp2
waitJoyX:
    lds     rTemp2, ADCSRA
    sbrc    rTemp2, ADSC
    jmp     waitJoyX
    lds     rJoyX, ADCH

	lds     rTemp2, ADMUX
    andi    rTemp2, 0xf0
    ori     rTemp2, 0x04
    sts     ADMUX, rTemp2
    lds     rTemp2, ADCSRA
    ori     rTemp2, 1 << ADSC
    sts     ADCSRA, rTemp2
waitJoyY:
    lds     rTemp2, ADCSRA
    sbrc    rTemp2, ADSC
    jmp     waitJoyY

    lds     rJoyY, ADCH

// Flytta snake
    lds     rTemp2, snakeX
testLeft:
    cpi     rJoyX, 0xe0
    brlo    testRight
    cpi     rTemp2, 0x01
    brlo    testRight
    subi    rTemp2, 1
    jmp     testXDone
testRight:
    cpi     rJoyX, 0x20
    brsh    testXDone
    cpi     rTemp2, 0x07
    brsh    testXDone
    subi    rTemp2, -1
testXDone:
    sts     snakeX, rTemp2

    lds     rTemp2, snakeY
testUp:
    cpi     rJoyY, 0xe0
    brlo    testDown
    cpi     rTemp2, 0x01
    brlo    testDown
    subi    rTemp2, 1
    jmp     testYDone
testDown:
    cpi     rJoyY, 0x20
    brsh    testYDone
    cpi     rTemp2, 0x07
    brsh    testYDone
    subi    rTemp2, -1
testYDone:
    sts     snakeY, rTemp2

// Töm matris
    ldi     rTemp2, 0x00
    sts     matrix + 0, rTemp2
    sts     matrix + 1, rTemp2
    sts     matrix + 2, rTemp2
    sts     matrix + 3, rTemp2
    sts     matrix + 4, rTemp2
    sts     matrix + 5, rTemp2
    sts     matrix + 6, rTemp2
    sts     matrix + 7, rTemp2

// Rita snake
    ldi     rMask, 0x01
    lds     rTemp2, snakeX
findXMask:
    cpi     rTemp2, 0x00
    breq    findXMaskDone
    lsl     rMask
    dec     rTemp2
    jmp     findXMask
findXMaskDone:

    ldi     YL, LOW(matrix)
    ldi     YH, HIGH(matrix)
    lds     rTemp2, snakeY
    add     YL, rTemp2

    st      Y, rMask

    jmp     loop



timer:
    in      rStatus, SREG
    push    rTemp
    
// Clear all columns
    cbi     PORTD, PORTD6
    cbi     PORTD, PORTD7
    cbi     PORTB, PORTB0
    cbi     PORTB, PORTB1
    cbi     PORTB, PORTB2
    cbi     PORTB, PORTB3
    cbi     PORTB, PORTB4
    cbi     PORTB, PORTB5

// Enable correct columns
    ldi     XL, LOW(matrix)
    ldi     XH, HIGH(matrix)
    add     XL, rRow

    ld      rTemp, X
testCol0:
    bst     rTemp, 0
    brtc    testCol1
    sbi     PORTD, PORTD6
testCol1:
    bst     rTemp, 1
    brtc    testCol2
    sbi     PORTD, PORTD7
testCol2:
    bst     rTemp, 2
    brtc    testCol3
    sbi     PORTB, PORTB0
testCol3:
    bst     rTemp, 3
    brtc    testCol4
    sbi     PORTB, PORTB1
testCol4:
    bst     rTemp, 4
    brtc    testCol5
    sbi     PORTB, PORTB2
testCol5:
    bst     rTemp, 5
    brtc    testCol6
    sbi     PORTB, PORTB3
testCol6:
    bst     rTemp, 6
    brtc    testCol7
    sbi     PORTB, PORTB4
testCol7:
    bst     rTemp, 7
    brtc    columnsDone
    sbi     PORTB, PORTB5
columnsDone:

// Enable correct row
testRow0:
    cpi     rRow, 0x00
    brne    testRow1
    sbi     PORTC, PORTC0
    cbi     PORTD, PORTD5
    jmp     rowsDone
testRow1:
    cpi     rRow, 0x01
    brne    testRow2
    sbi     PORTC, PORTC1
    cbi     PORTC, PORTC0
    jmp     rowsDone
testRow2:
    cpi     rRow, 0x02
    brne    testRow3
    sbi     PORTC, PORTC2
    cbi     PORTC, PORTC1
    jmp     rowsDone
testRow3:
    cpi     rRow, 0x03
    brne    testRow4
    sbi     PORTC, PORTC3
    cbi     PORTC, PORTC2
    jmp     rowsDone
testRow4:
    cpi     rRow, 0x04
    brne    testRow5
    sbi     PORTD, PORTD2
    cbi     PORTC, PORTC3
    jmp     rowsDone
testRow5:
    cpi     rRow, 0x05
    brne    testRow6
    sbi     PORTD, PORTD3
    cbi     PORTD, PORTD2
    jmp     rowsDone
testRow6:
    cpi     rRow, 0x06
    brne    testRow7
    sbi     PORTD, PORTD4
    cbi     PORTD, PORTD3
    jmp     rowsDone
testRow7:
    sbi     PORTD, PORTD5
    cbi     PORTD, PORTD4
    ldi     rRow, 0x00
    inc     rUpdate
    jmp     lastRow

rowsDone:
    inc     rRow

lastRow:
    
    pop     rTemp
    out     SREG, rStatus
    reti