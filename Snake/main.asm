
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
.DEF rStatus       = r3  //Store status register so that it may be restored post  "code-break?"
.DEF rITemp         = r16
.DEF rRow          = r17 // LED Row Iterator
.DEF rUpdate       = r18 // Update gamelogic at TICK_RATE rate
// Non-Interrupt registers
.DEF rJoyX         = r19 // Joystick X-axis
.DEF rJoyY         = r20 // Joystick Y-axis
.DEF rMask         = r21  //Mask specific bit-values to enable certain LEDs
.DEF rTemp        = r22
.DEF rX            = r23 // Argument for setPixel to store the snake's temporary head position in the X-Axis
.DEF rY            = r24 // Argument for setPixel to store the snake's temporary head position in the Y-Axis
.EQU SNAKE_LENGTH  = 5
.EQU TICK_RATE	   = 128


.DSEG

matrix:   .BYTE 8            // Each byte represents a row. MSB represents kolumns to the right and LSB represents those to the left.
snakeX:   .BYTE SNAKE_LENGTH // Array of the X-Positions
snakeY:   .BYTE SNAKE_LENGTH // Array of the Y-Positions

.CSEG
//Interrupt vector table (from school material!)
.ORG 0x0000
     jmp init 
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
     jmp timer

init:
    // Set the stack pointer to the highest memAdress
    ldi	rITemp, HIGH(RAMEND)
    out	SPH, rITemp
    ldi	rITemp, LOW(RAMEND)
    out	SPL, rITemp

    // Set the LED pins to OUTPUT
    ldi    rITemp, 0x0f
    out    DDRC, rITemp
    ldi    rITemp, 0xfc
    out    DDRD, rITemp
    ldi    rITemp, 0x3f
    out    DDRB, rITemp

    // Init rRow!
    ldi    rRow, 0x00

	// Big Smile for a cool start!
    ldi    rITemp, 0x00 
    sts    matrix + 0, rITemp 
    ldi    rITemp, 0x24 
    sts    matrix + 1, rITemp 
    ldi    rITemp, 0x24 
    sts    matrix + 2, rITemp 
    ldi    rITemp, 0x00 
    sts    matrix + 3, rITemp 
 
    ldi    rITemp, 0x42 
    sts    matrix + 4, rITemp 
    ldi    rITemp, 0x3C 
    sts    matrix + 5, rITemp 
    ldi    rITemp, 0x0 
    sts    matrix + 6, rITemp 
    ldi    rITemp, 0x0 
    sts    matrix + 7, rITemp 

	 // Set the snake to 3, 3 to center the player (can't center it since it's an even number of LEDs) -Sebastian
    ldi    rITemp, 0x03        
    sts    snakeX + 0, rITemp
    sts    snakeY + 0, rITemp
    sts    snakeX + 1, rITemp
    sts    snakeY + 1, rITemp
    sts    snakeX + 2, rITemp
    sts    snakeY + 2, rITemp
    sts    snakeX + 3, rITemp
    sts    snakeY + 3, rITemp
	sts    snakeX + 4, rITemp
    sts    snakeY + 4, rITemp

	// Set the Joystick to a middle position (128 to be extra cool)
	ldi    rJoyX, 0x80     
    ldi    rJoyY, 0x80

	// Init an config of the Analogue to Digital converter for the joystick
    ldi    rITemp, 0x60
    sts    ADMUX, rITemp
    ldi    rITemp, 0x87
    sts    ADCSRA, rITemp

    // Timer setup
    lds    rITemp, TCCR0B
    ori    rITemp, 0x02
    out    TCCR0B, rITemp
    sei
    lds    rITemp, TIMSK0
    ori    rITemp, 0x01
    sts    TIMSK0, rITemp

	// Reset the update counter
	ldi    rUpdate, 0x00
	 
	// This part waits for 1 second. Based on "http://www.bretmulvey.com/avrdelay.html"
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
// X-AXIS
readJoyX:
	lds     rTemp, ADMUX		// Using ADMUX to get the right input
    andi    rTemp, 0xf0			// Set bit 0-3 to 0 ("Thanks Benny!")
    ori     rTemp, 0x05			// Set bit 0-3 to the right value for the X-Axis
    sts     ADMUX, rTemp
    lds     rTemp, ADCSRA
    ori     rTemp, 1 << ADSC
    sts     ADCSRA, rTemp		// Set "ADSC" to 1 to start analogue to digital converter
waitJoyX:						// When analogue to digital converter is done ("ADSC" = 0)
    lds     rTemp, ADCSRA
    sbrc    rTemp, ADSC			// Skip instruction if "ADSC" is 0
    jmp     waitJoyX			// Jump to waitJoyX!

// Don't update direction if joystick is in neutral pos!
    lds     rTemp, ADCH
    cpi     rTemp, 0xe0 // Jämnför rTemp med konstanten 224
    brsh    loadJoyX // Hoppar till loadJoyX om rTemp är högre eller lika med 224
    cpi     rTemp, 0x20
    brsh    readjoyY
loadJoyX:
    mov     rJoyX, rTemp
    ldi     rJoyY, 0x80

// Y-AXIS
readJoyY:
	lds     rTemp, ADMUX
    andi    rTemp, 0xf0
    ori     rTemp, 0x04
    sts     ADMUX, rTemp
    lds     rTemp, ADCSRA
    ori     rTemp, 1 << ADSC
    sts     ADCSRA, rTemp
waitJoyY:
    lds     rTemp, ADCSRA
    sbrc    rTemp, ADSC
    jmp     waitJoyY

// Don't update direction if joystick is in neutral pos!
    lds     rTemp, ADCH
    cpi     rTemp, 0xe0
    brsh    loadJoyY
    cpi     rTemp, 0x20
    brsh    readJoyDone
loadJoyY:
    mov     rJoyY, rTemp
    ldi     rJoyX, 0x80

readJoyDone:
// VIBE CHECK (Actually just an update check!)
    cpi     rUpdate, TICK_RATE			// check if update timer has reached the TICK_RATE!
    brlo    loop                        // loop again to wait another tick if not
    ldi     rUpdate, 0x00               // reset counter if true

// Move the first snake part!
    lds     rX, snakeX
goL:
    cpi     rJoyX, 0xe0
    brlo    goR
    cpi     rX, 0x01    // CHECK FOR WORLD END!!!
    brlo    goR
    subi    rX, 1
    jmp     finishedX
goR:
    cpi     rJoyX, 0x20
    brsh    finishedX
    cpi     rX, 0x07    // CHECK FOR WORLD END!!!
    brsh    finishedX
    subi    rX, -1

finishedX:
    lds     rY, snakeY

goU:
    cpi     rJoyY, 0xe0
    brlo    goD
    cpi     rY, 0x01    // CHECK FOR WORLD END!!!
    brlo    goD
    subi    rY, 1
    jmp     finishedY
goD:
    cpi     rJoyY, 0x20
    brsh    finishedY
    cpi     rY, 0x07    // CHECK FOR WORLD END!!!
    brsh    finishedY
    subi    rY, -1
finishedY:

// If head did not update position, skip moving body!
    lds     rTemp, snakeX
    cp      rTemp, rX		// compare the old X with new X
    brne    moveBody		// move body if not equal!
    lds     rTemp, snakeY	
    cp      rTemp, rY		// compare the old Y with new Y
    breq    moveBodyDone	// jumps to moveBodyDone if old Y and new Y is equal. Else it falls down into moveBody!

// Move the rest of the snake!
// Iterate snake body array to move snake!
moveBody:
    ldi     YL, LOW( snakeX + SNAKE_LENGTH - 2)
    ldi     YH, HIGH(snakeX + SNAKE_LENGTH - 2)
    ldi     ZL, LOW( snakeY + SNAKE_LENGTH - 2)
    ldi     ZH, HIGH(snakeY + SNAKE_LENGTH - 2)
    ldi     rITemp, 0x00
iterateBody:
    ld      rTemp, Y
    std     Y + 1, rTemp
    ld      rTemp, Z
    std     Z + 1, rTemp

    dec     YL
    dec     ZL
    inc     rITemp
    cpi     rITemp, SNAKE_LENGTH - 1
    brlo    iterateBody

moveBodyDone:
// write new head pos to SRAM
    sts     snakeX, rX
    sts     snakeY, rY

// Clear the screen matrix!
    ldi     rTemp, 0x00
    sts     matrix + 0, rTemp
    sts     matrix + 1, rTemp
    sts     matrix + 2, rTemp
    sts     matrix + 3, rTemp
    sts     matrix + 4, rTemp
    sts     matrix + 5, rTemp
    sts     matrix + 6, rTemp
    sts     matrix + 7, rTemp

	//Render Snake

	ldi		rITemp, 0x00	
	ldi     YL, LOW(snakeY)
    ldi     YH, HIGH(snakeY)
	ldi		ZL, LOW(snakeX)
    ldi     ZH, HIGH(snakeX)
	renderSnake:

	ld  rX, Z
	ld  rY, Y

	//setPixel modifies YL and YH so we push them to the stack for later modification
	push YL
	push YH

    call	setPixel

	//here we pull YL and YH from the stack to increment
	pop	YH
	pop YL
	//increment these suckers!
	inc ZL
	inc YL
	inc	rITemp
	cpi	rITemp,  SNAKE_LENGTH
	brne renderSnake
	
// Wait for next Update
    jmp     loop

//----------------------------------------------------------------------//

setPixel:		//Enables a LED based on rX amd rY

// Calc 1 << rX ("Thanks Benny!")
    ldi     rMask, 0x01
findXMask:
    cpi     rX, 0x00
    breq    findXMaskDone   //Loop until rX equals 0
    lsl     rMask			// Bit shifts rMask left by one
    dec     rX
    jmp     findXMask
findXMaskDone:

// Find the desired row! (matrix + rY)
    ldi     YL, LOW(matrix)
    ldi     YH, HIGH(matrix)
    add     YL, rY

// Combine 1 << rX with the row:s old value! ("Thanks Benny!")
    ld      rTemp, Y
    or      rTemp, rMask
    st      Y, rTemp

    ret

//----------------------------------------------------------------------//

timer:
    in      rStatus, SREG   // Save SREG so it can be recovered!
    push    rITemp // lowers SP and puts rITemp on top of the stack!
    
// Clear all columns!!
    cbi     PORTD, PORTD6
    cbi     PORTD, PORTD7
    cbi     PORTB, PORTB0
    cbi     PORTB, PORTB1
    cbi     PORTB, PORTB2
    cbi     PORTB, PORTB3
    cbi     PORTB, PORTB4
    cbi     PORTB, PORTB5

// Clear all rows!!
	cbi     PORTD, PORTD5
    cbi     PORTC, PORTC0
    cbi     PORTC, PORTC1
    cbi     PORTC, PORTC2
    cbi     PORTC, PORTC3
    cbi     PORTD, PORTD2
    cbi     PORTD, PORTD3
    cbi     PORTD, PORTD4


// Read the right value at the right row! (matrix + rRow)
    ldi     XL, LOW(matrix)
    ldi     XH, HIGH(matrix)
    add     XL, rRow

// Enable correct columns
    ld      rITemp, X

//Check all columns for which should be active during this frame
col0:
    bst     rITemp, 0 // Take bit 0 from rITemp and set it to bit T in the statusReg
    brtc    col1 // Go to col1 if bit 0 is 0
    sbi     PORTD, PORTD6 // else set this col active and fall down to col1 to continue
col1:
    bst     rITemp, 1 // the same as col0, repeated for all columns
    brtc    col2
    sbi     PORTD, PORTD7
col2:
    bst     rITemp, 2
    brtc    col3
    sbi     PORTB, PORTB0
col3:
    bst     rITemp, 3
    brtc    col4
    sbi     PORTB, PORTB1
col4:
    bst     rITemp, 4
    brtc    col5
    sbi     PORTB, PORTB2
col5:
    bst     rITemp, 5
    brtc    col6
    sbi     PORTB, PORTB3
col6:
    bst     rITemp, 6
    brtc    col7
    sbi     PORTB, PORTB4
col7:
    bst     rITemp, 7
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
    
    pop     rITemp // set rITemp to stack top value and increases SP
    out     SREG, rStatus // Restore SREG to value before interrupt occured!
    reti