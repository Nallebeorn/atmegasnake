// We should consider renaming some of these and changing the comments to a different structure. -Sebastian

//////////////////////////////
//       LEDJOY SNAKE       //
//////////////////////////////
//       Created  by:       //
//  Christoffer Cederfeldt  //
//	 Sebastian  Alkstrand   //
//	  Amanda  Lindqvist     //
//////////////////////////////

// Interrupt registers
.DEF rTemp         = r16
.DEF rRow          = r17 // Vilken led-rad som ska tändas härnäst
.DEF rStatus       = r3  // Lagra statusregister så de kan återställas efter avbrottet
.DEF rUpdate       = r22 // Räknar upp (till TICK_RATE) tills det är dags att uppdatera spellogiken
// Not interrupt registers
.DEF rTemp2        = r18
.DEF rJoyX         = r19 // Joystick x-axel
.DEF rJoyY         = r20 // Joystick y-axel
.DEF rMask         = r21 // Används i drawDot, värdet på en matrisrad för att tända en viss pixel i raden
.DEF rX            = r24 // Argument till drawDot + temporär huvudposition
.DEF rY            = r25 // -||-

.EQU NUM_COLUMNS   = 8   // This variable does not seem to be used in the code? -Sebastian
.EQU SNAKE_LENGTH  = 4
.EQU TICK_RATE	   = 128


.DSEG

matrix:   .BYTE 8            // Varje byte är en rad. MSB = kolumn längst till höger. LSB = kolumn längst till vänster.
snakeX:   .BYTE SNAKE_LENGTH // Array av x-positioner (första är huvudets x)
snakeY:   .BYTE SNAKE_LENGTH // Array av y-positioner (första är huvudets y)

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

     ldi    rJoyX, 0x80     // 128 är neutral joystick-position (hälften av 256)
     ldi    rJoyY, 0x80

     ldi    rTemp, 0x04         // sätt alla snake-segment till position (4, 4)

     sts    snakeX + 0, rTemp
     sts    snakeY + 0, rTemp

     sts    snakeX + 1, rTemp
     sts    snakeY + 1, rTemp

     sts    snakeX + 2, rTemp
     sts    snakeY + 2, rTemp

     sts    snakeX + 3, rTemp
     sts    snakeY + 3, rTemp

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
	lds     rTemp2, ADMUX   // ADMUX använd för att välja rätt analogingång
    andi    rTemp2, 0xf0    // Sätt bit 0-3 till 0
    ori     rTemp2, 0x05    // Sätt bit 0-3 till rätt värde för x-axelns analogingång
    sts     ADMUX, rTemp2
    lds     rTemp2, ADCSRA
    ori     rTemp2, 1 << ADSC
    sts     ADCSRA, rTemp2      // Sätt bit "ADSC" i ADCSRA till 1 för att starta A/D-omvandlaren
waitJoyX:                   // Vänta tills A/D-omvandlare är klar (= bit "ADSC" i ADCSRA är 0)
    lds     rTemp2, ADCSRA
    sbrc    rTemp2, ADSC    // Hoppa över nästa instruktion om bit "ADSC" i ADCSRA är noll
    jmp     waitJoyX // Ovillkorligt hopp till waitJoyX

// Uppdatera inte variabeln om joysticken är i neutralt läge (gör att det känns bättre att spela med piltangenterna)
    lds     rTemp2, ADCH
    cpi     rTemp2, 0xe0 // Jämnför rTemp2 med konstanten 224
    brsh    loadJoyX // Hoppar till loadJoyX om rTemp2 är högre eller lika med 224
    cpi     rTemp2, 0x20
    brsh    readjoyY
loadJoyX:
    mov     rJoyX, rTemp2
    ldi     rJoyY, 0x80

// Y-axel (samma process som för y)
readJoyY:
	lds     rTemp2, ADMUX
    andi    rTemp2, 0xf0
    ori     rTemp2, 0x04    // Ny analogingång
    sts     ADMUX, rTemp2
    lds     rTemp2, ADCSRA
    ori     rTemp2, 1 << ADSC
    sts     ADCSRA, rTemp2
waitJoyY:
    lds     rTemp2, ADCSRA
    sbrc    rTemp2, ADSC
    jmp     waitJoyY

// Uppdatera inte variabeln om joysticken är i neutralt läge (gör att det känns bättre att spela med piltangenterna)
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
    cpi     rUpdate, TICK_RATE
    brlo    loop                        // Om nej, loopa för att fortsätta vänta
    ldi     rUpdate, 0x00               // Om ja, nollställ räknaren

// Flytta huvud
    lds     rX, snakeX
testLeft:
    cpi     rJoyX, 0xe0
    brlo    testRight
    cpi     rX, 0x01    // Flytta inte utanför kanten på banan
    brlo    testRight
    subi    rX, 1
    jmp     testXDone
testRight:
    cpi     rJoyX, 0x20
    brsh    testXDone
    cpi     rX, 0x07    // Flytta inte utanför kanten på banan
    brsh    testXDone
    subi    rX, -1
testXDone:

    lds     rY, snakeY
testUp:
    cpi     rJoyY, 0xe0
    brlo    testDown
    cpi     rY, 0x01    // Flytta inte utanför kanten på banan
    brlo    testDown
    subi    rY, 1
    jmp     testYDone
testDown:
    cpi     rJoyY, 0x20
    brsh    testYDone
    cpi     rY, 0x07    // Flytta inte utanför kanten på banan
    brsh    testYDone
    subi    rY, -1
testYDone:

// Flytta inte svans om inte huvudet rört på sig
    lds     rTemp2, snakeX
    cp      rTemp2, rX  // Jämnför rTemp2 (huvudets gamla x) med rX (huvudets nya x)
    brne    moveTail // Hoppar till moveTail om rTemp2 inte är lika med rX
    lds     rTemp2, snakeY
    cp      rTemp2, rY
    breq    moveTailDone // Hoppar till moveTailDone om rTemp2 är lika med rY (om Z bit:en i statusregistret är 1)

// Flytta svans
// Gå igenom snake-arrayerna bakifrån och flytta ned varje element ett steg
moveTail:
    ldi     YL, LOW( snakeX + SNAKE_LENGTH - 2)
    ldi     YH, HIGH(snakeX + SNAKE_LENGTH - 2)
    ldi     ZL, LOW( snakeY + SNAKE_LENGTH - 2)
    ldi     ZH, HIGH(snakeY + SNAKE_LENGTH - 2)
    ldi     rTemp, 0x00
tailLoop:
    ld      rTemp2, Y
    std     Y + 1, rTemp2
    ld      rTemp2, Z
    std     Z + 1, rTemp2

    dec     YL
    dec     ZL
    inc     rTemp
    cpi     rTemp, SNAKE_LENGTH - 1
    brlo    tailLoop

moveTailDone:
// Skriv huvudets nya position till RAM
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
// (loopar är överskattade)
    lds     rX, snakeX  // rX och rY används som argument till drawDot nu
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

// Klar! Loopa och invänta nästa update
    jmp     loop

//////////////////////////////////////////////

drawDot:
// Sätter på en viss pixel i matrisen
// rX = x-position att rita till (förstörs)
// rY = y-position att rita till (förstörs)

// Beräkna 1 << rX
    ldi     rMask, 0x01
findXMask:
    cpi     rX, 0x00
    breq    findXMaskDone   // Loopa tills rX == 0
    lsl     rMask // Skiftar bit:arna i rMask ett steg åt vänster
    dec     rX
    jmp     findXMask
findXMaskDone:

// Hitta rätt rad (matrix + rY)
    ldi     YL, LOW(matrix)
    ldi     YH, HIGH(matrix)
    add     YL, rY

// Kombinera 1 << rX med radens gamla värde
    ld      rTemp2, Y
    or      rTemp2, rMask
    st      Y, rTemp2

    ret

//////////////////////////////////////////////

timer:
    in      rStatus, SREG   // Spara statusregistret så det kan återställas senare
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

// Läs in värdet på rätt rad (matrix + rRow)
    ldi     XL, LOW(matrix)
    ldi     XH, HIGH(matrix)
    add     XL, rRow

// Enable correct columns
    ld      rTemp, X
testCol0:
    bst     rTemp, 0 // Kopierar bit 0 (första kolumnen) i rTemp till bit T i statusregistret
    brtc    testCol1 // Hoppar till testCol1 om T är 0
    sbi     PORTD, PORTD6 // Om T är 1, aktivera första kolumnen i ledmatrisen
testCol1:
    bst     rTemp, 1 // Etc.
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
rowJmpTable:
	//Row0
    cpi     rRow, 0x00
    breq    testRow0
	//Row1
    cpi     rRow, 0x01
    breq    testRow1
	//Row2
    cpi     rRow, 0x02
    breq    testRow2
	//Row3
	cpi     rRow, 0x03
    breq    testRow3
	//Row4
	cpi     rRow, 0x04
    breq    testRow4
	//Row5
	cpi     rRow, 0x05
    breq    testRow5
	//Row6
	cpi     rRow, 0x06
    breq    testRow6
	//Row7
	cpi     rRow, 0x07
    breq    testRow7

testRow0:
    sbi     PORTC, PORTC0   // Om nuvarande rad är rad 0, sätt på första raden i ledmatrisen...
    cbi     PORTD, PORTD5   // ...och stäng av föregående rad (sista raden i det här fallet).
    jmp     rowsDone
testRow1:
    sbi     PORTC, PORTC1   // Etc.
    cbi     PORTC, PORTC0
    jmp     rowsDone
testRow2:
    sbi     PORTC, PORTC2
    cbi     PORTC, PORTC1
    jmp     rowsDone
testRow3:
    sbi     PORTC, PORTC3
    cbi     PORTC, PORTC2
    jmp     rowsDone
testRow4:
    sbi     PORTD, PORTD2
    cbi     PORTC, PORTC3
    jmp     rowsDone
testRow5:
    sbi     PORTD, PORTD3
    cbi     PORTD, PORTD2
    jmp     rowsDone
testRow6:
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
    out     SREG, rStatus // Återställ statusregistret till vad det var innan avbrottet startade
    reti