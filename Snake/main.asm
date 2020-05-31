// We should consider renaming some of these and changing the comments to a different structure. -Sebastian

//////////////////////////////      
//       LEDJOY SNAKE       //        ########
//////////////////////////////      ##__####__##
//                          //      #|  |##|  |#
//       Created  by:       //      #####uu#####
//  Christoffer Cederfeldt  //        ########
//	 Sebastian  Alkstrand   //         |||| |
//	   Amanda Lindqvist     //         ######
//							//
//////////////////////////////

// Interrupt registers
.DEF rStatus       = r3  // Lagra statusregister så de kan återställas efter avbrottet
.DEF rTemp         = r16
.DEF rRow          = r17 // Vilken led-rad som ska tändas härnäst
.DEF rUpdate       = r18 // Räknar upp (till TICK_RATE) tills det är dags att uppdatera spellogiken
// Not interrupt registers
.DEF rJoyX         = r19 // Joystick x-axel
.DEF rJoyY         = r20 // Joystick y-axel
.DEF rMask         = r21 // Används i setPixel, värdet på en matrisrad för att tända en viss pixel i raden
.DEF rTemp2        = r22
.DEF rX            = r23 // Argument till setPixel + temporär huvudposition
.DEF rY            = r24 // -||-

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

	      // Big Smile
     ldi    rTemp, 0x00 
     sts    matrix + 0, rTemp 
     ldi    rTemp, 0x24 
     sts    matrix + 1, rTemp 
     ldi    rTemp, 0x24 
     sts    matrix + 2, rTemp 
     ldi    rTemp, 0x00 
     sts    matrix + 3, rTemp 
 
     ldi    rTemp, 0x42 
     sts    matrix + 4, rTemp 
     ldi    rTemp, 0x3C 
     sts    matrix + 5, rTemp 
     ldi    rTemp, 0x0 
     sts    matrix + 6, rTemp 
     ldi    rTemp, 0x0 
     sts    matrix + 7, rTemp 

	  // sätt alla snake-segment till position (3, 3) "Bättre än Benjamins grupp (4, 4)" -Christoffer
     ldi    rTemp, 0x03        
     sts    snakeX + 0, rTemp
     sts    snakeY + 0, rTemp
     sts    snakeX + 1, rTemp
     sts    snakeY + 1, rTemp
     sts    snakeX + 2, rTemp
     sts    snakeY + 2, rTemp
     sts    snakeX + 3, rTemp
     sts    snakeY + 3, rTemp

	 // Sätt joystickens neutral position (hälften av 256)
	 ldi    rJoyX, 0x80     
     ldi    rJoyY, 0x80

	 // Aktivera och konfigurera A/D-omvandling for joystickavläsning
     ldi    rTemp, 0x60
     sts    ADMUX, rTemp
     ldi    rTemp, 0x87
     sts    ADCSRA, rTemp

     // Aktivera och konfigurera timern
     lds    rTemp, TCCR0B
     ori    rTemp, 0x02
     out    TCCR0B, rTemp
     sei
     lds    rTemp, TIMSK0
     ori    rTemp, 0x01
     sts    TIMSK0, rTemp

	  //nollställ räknaren
	 ldi    rUpdate, 0x00
	 
	 //WAIT!!
	ldi  r16, 41 //16
    ldi  r22, 150 //22
    ldi  r25, 128 //26
L1: dec  r25 //26
    brne L1
    dec  r22 //22
    brne L1
    dec  r16 //16
    brne L1

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
    lds     rX, snakeX  // rX och rY används som argument till setPixel nu
    lds     rY, snakeY
    call    setPixel

    lds     rX, snakeX + 1
    lds     rY, snakeY + 1
    call    setPixel

    lds     rX, snakeX + 2
    lds     rY, snakeY + 2
    call    setPixel

    lds     rX, snakeX + 3
    lds     rY, snakeY + 3
    call    setPixel

// Klar! Loopa och invänta nästa update
    jmp     loop

//////////////////////////////////////////////

setPixel:
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
    
// Clear all col:s
    cbi     PORTD, PORTD6
    cbi     PORTD, PORTD7
    cbi     PORTB, PORTB0
    cbi     PORTB, PORTB1
    cbi     PORTB, PORTB2
    cbi     PORTB, PORTB3
    cbi     PORTB, PORTB4
    cbi     PORTB, PORTB5

// Clear all row:s
	cbi     PORTD, PORTD5
    cbi     PORTC, PORTC0
    cbi     PORTC, PORTC1
    cbi     PORTC, PORTC2
    cbi     PORTC, PORTC3
    cbi     PORTD, PORTD2
    cbi     PORTD, PORTD3
    cbi     PORTD, PORTD4


// Läs in värdet på rätt rad (matrix + rRow)
    ldi     XL, LOW(matrix)
    ldi     XH, HIGH(matrix)
    add     XL, rRow

// Enable correct columns
    ld      rTemp, X

//Check all columns for which should be active during this frame
col0:
    bst     rTemp, 0 // Take bit 0 from rTemp and set it to bit T in the statusReg
    brtc    col1 // Go to col1 if bit 0 is 0
    sbi     PORTD, PORTD6 // else set this col active and fall down to col1 to continue
col1:
    bst     rTemp, 1 // the same as col0, repeated for all columns
    brtc    col2
    sbi     PORTD, PORTD7
col2:
    bst     rTemp, 2
    brtc    col3
    sbi     PORTB, PORTB0
col3:
    bst     rTemp, 3
    brtc    col4
    sbi     PORTB, PORTB1
col4:
    bst     rTemp, 4
    brtc    col5
    sbi     PORTB, PORTB2
col5:
    bst     rTemp, 5
    brtc    col6
    sbi     PORTB, PORTB3
col6:
    bst     rTemp, 6
    brtc    col7
    sbi     PORTB, PORTB4
col7:
    bst     rTemp, 7
    brtc    rowJmpTable
    sbi     PORTB, PORTB5

// Jump to the desired row based on rRow
rowJmpTable:
	//row0
    cpi     rRow, 0x00
    breq    row0
	//row1
    cpi     rRow, 0x01
    breq    row1
	//row2
    cpi     rRow, 0x02
    breq    row2
	//row3
	cpi     rRow, 0x03
    breq    row3
	//row4
	cpi     rRow, 0x04
    breq    row4
	//row5
	cpi     rRow, 0x05
    breq    row5
	//row6
	cpi     rRow, 0x06
    breq    row6
	//row7
	cpi     rRow, 0x07
    breq    row7

row0:
    sbi     PORTC, PORTC0   // Activate Row 0
    jmp     rowsDone
row1:
    sbi     PORTC, PORTC1   // Activate Row 1 etc...
    jmp     rowsDone
row2:
    sbi     PORTC, PORTC2
    jmp     rowsDone
row3:
    sbi     PORTC, PORTC3
    jmp     rowsDone
row4:
    sbi     PORTD, PORTD2
    jmp     rowsDone
row5:
    sbi     PORTD, PORTD3
    jmp     rowsDone
row6:
    sbi     PORTD, PORTD4
    jmp     rowsDone
row7:
    sbi     PORTD, PORTD5
    ldi     rRow, 0x00
    inc     rUpdate
    jmp     lastRow


rowsDone:
    inc     rRow

lastRow:
    
    pop     rTemp // Sätter rTemp till elementet i toppen av stacken och ökar SP
    out     SREG, rStatus // Återställ statusregistret till vad det var innan avbrottet startade
    reti