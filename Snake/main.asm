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
.DEF rX            = r24 // Argument till drawDot + temporär huvudposition
.DEF rY            = r25

.EQU NUM_COLUMNS   = 8
.EQU MAX_LENGTH    = 4
.EQU UPDATE_INTERVAL = 128


.DSEG

matrix:   .BYTE 8 
snakeX:   .BYTE MAX_LENGTH
snakeY:   .BYTE MAX_LENGTH

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

     ldi    rJoyX, 0x80
     ldi    rJoyY, 0x80

     ldi    rTemp, 0x04
     sts    snakeY + 0, rTemp
     sts    snakeY + 1, rTemp
     sts    snakeY + 2, rTemp
     sts    snakeY + 3, rTemp
     sts    snakeX + 0, rTemp
     sts    snakeX + 1, rTemp
     sts    snakeX + 2, rTemp
     sts    snakeX + 3, rTemp

/*     sts    snakeX + 0, rTemp
     ldi    rTemp, 0x03
     sts    snakeX + 1, rTemp
     ldi    rTemp, 0x02
     sts    snakeX + 2, rTemp
     ldi    rTemp, 0x01
     sts    snakeX + 3, rTemp*/

     ldi    rUpdate, 0x00

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
    jmp     waitJoyX // Ovillorligt hopp till waitJoyX

    lds     rTemp2, ADCH
    cpi     rTemp2, 0xe0 // Jämnför rTemp2 med konstanten 224
    brsh    loadJoyX // Hoppar till loadJoyX om rTemp2 är högre eller lika med 224
    cpi     rTemp2, 0x20
    brsh    readjoyY
loadJoyX:
    mov     rJoyX, rTemp2
    ldi     rJoyY, 0x80

readJoyY:
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

    lds     rTemp2, ADCH
    cpi     rTemp2, 0xe0
    brsh    loadJoyY
    cpi     rTemp2, 0x20
    brsh    readJoyDone
loadJoyY:
    mov     rJoyY, rTemp2
    ldi     rJoyX, 0x80
readJoyDone:

// Kolla om det är dags att uppdatera
    cpi     rUpdate, UPDATE_INTERVAL
    brlo    loop
    ldi     rUpdate, 0x00

// Flytta huvud
    lds     rX, snakeX
testLeft:
    cpi     rJoyX, 0xe0
    brlo    testRight
    cpi     rX, 0x01
    brlo    testRight
    subi    rX, 1
    jmp     testXDone
testRight:
    cpi     rJoyX, 0x20
    brsh    testXDone
    cpi     rX, 0x07
    brsh    testXDone
    subi    rX, -1
testXDone:

    lds     rY, snakeY
testUp:
    cpi     rJoyY, 0xe0
    brlo    testDown
    cpi     rY, 0x01
    brlo    testDown
    subi    rY, 1
    jmp     testYDone
testDown:
    cpi     rJoyY, 0x20
    brsh    testYDone
    cpi     rY, 0x07
    brsh    testYDone
    subi    rY, -1
testYDone:

// Flytta inte svans om inte huvudet rört på sig
    lds     rTemp2, snakeX
    cp      rTemp2, rX  // Jämnför rTemp2 med rX
    brne    moveTail // Hoppar till moveTail om rTemp2 inte är lika med rX
    lds     rTemp2, snakeY
    cp      rTemp2, rY
    breq    moveTailDone // Hoppar till moveTailDone om rTemp2 är lika med rY (om Z bit:en i statusregistret är 1)

// Flytta svans
moveTail:
    ldi     YL, LOW(snakeX + MAX_LENGTH - 2)
    ldi     YH, HIGH(snakeX + MAX_LENGTH - 2)
    ldi     ZL, LOW(snakeY + MAX_LENGTH - 2)
    ldi     ZH, HIGH(snakeY + MAX_LENGTH - 2)
    ldi     rTemp, 0x00
tailLoop:
    ld      rTemp2, Y
    std     Y + 1, rTemp2
    ld      rTemp2, Z
    std     Z + 1, rTemp2

    dec     YL
    dec     ZL
    inc     rTemp
    cpi     rTemp, MAX_LENGTH - 1
    brlo    tailLoop

moveTailDone:
    sts     snakeX, rX
    sts     snakeY, rY

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
    lds     rX, snakeX
    lds     rY, snakeY
    call    drawDot

    lds     rX, snakeX + 1
    lds     rY, snakeY + 1
    call    drawDot

    lds     rX, snakeX + 2
    lds     rY, snakeY + 2
    call    drawDot

    lds     rX, snakeX + 3
    lds     rY, snakeY + 3
    call    drawDot

    jmp     loop

drawDot:
    ldi     rMask, 0x01
findXMask:
    cpi     rX, 0x00
    breq    findXMaskDone
    lsl     rMask // Skiftar bit:arna i rMask ett steg åt vänster
    dec     rX
    jmp     findXMask
findXMaskDone:

    ldi     YL, LOW(matrix)
    ldi     YH, HIGH(matrix)
    add     YL, rY

    ld      rTemp2, Y
    or      rTemp2, rMask
    st      Y, rTemp2

    ret

timer:
    in      rStatus, SREG
    push    rTemp // Sänker SP och sätter rTemp på toppen av stacken
    
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
    bst     rTemp, 0 // Kopierar bit 0 i rTemp till bit T i statusregistret
    brtc    testCol1 // Hoppar till testCol1 om T är 0
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
    
    pop     rTemp // Sätter rTemp till elementet i toppen av stacken och ökar SP
    out     SREG, rStatus
    reti