.include "common.s"

.data
.align 2
DISPLAY_CONTROL:	.word 0xFFFF0008
DISPLAY_DATA:		.word 0xFFFF000C
KEYBOARD_CONTROL:	.word 0xFFFF0000
KEYBOARD_DATA:		.word 0xFFFF0004
TIME:			.word 0xFFFF0018
TIMECMP:		.word 0xFFFF0020
PHASE:			.word 0 # keeps track of which game phase is running
LEVEL:			.word 0 # used to set level of the game from user input
CHANGED:		.word 1 # flag to check if anything should be updated in the display
TBUDGET:		.word 60 # timer
BONUS:			.word 12 # bonus points for completing a phase
POINTER:		.word 0 # global pointer to the current phrase
POINTS:			.word 0 # track points
MATCHES:		.word 0 # track matches for progress bar
String:			.asciz "Type 1,2 or 3 to choose difficulty and start game"
cString:		.ascii "placeholder"
aString:		.ascii "another placeholder"
string2:		.asciz "points"
INTERRUPT_ERROR:	.asciz "Error: Unhandled interrupt with exception code: "
INSTRUCTION_ERROR:	.asciz "\n   Originating from the instruction at address: "

.text
typing:
	csrrwi zero, 0x000, 0x01 # enable interrupts
	li	t1, 272
	csrrw zero, 0x004, t1 # enables keyboard and timer interrupts
	la    t1, handler
	csrrw zero, 0x005, t1 # sets adress of the handler

	mv s0, a0 # s0 contains the pointer to the start of array of phrases
	jal choose_phrase
	
	
	la    t0, String
        mv    a0, t0      # a0 <- strAddr
        li    a1, 0        # a1 <- row = i
        li    a2, 0        # a2 <- col = 0
	jal   printStr
	

loop1: # starting phase
	
	lw t1, KEYBOARD_CONTROL
	li t0, 2
	sw t0, 0(t1) # set bit 1 of keyboard control to 1
	lw t0, LEVEL
	li t1, 1
	beq t0, t1, set_param
	li t1, 2
	beq t0, t1, set_param
	li t1, 3
	beq t0, t1, set_param
	j loop1
	
choose_phrase: # calls random and chooses the phrase to be displayed
	# STACK
	addi sp, sp -4
	sw ra, 0(sp)
	
	jal random
	slli a0, a0, 2
	add s1, a0, s0
	lw s1, 0(s1) # s1 now contains the address of the beginning of the current phrase
	sw s1, POINTER, t0
	
	# clear screen
	lw t0, DISPLAY_DATA
	li t1, 12
	sw t1, 0(t0)
	
	# UNSTACK
	lw ra, 0(sp)
	addi sp, sp, 4
	
	jalr zero, ra, 0	
set_param: # sets the paramaters of the game
	lw t0, TBUDGET
	lw t1, LEVEL
	div t0, t0, t1
	sw t0, TBUDGET, t2
	lw t0, BONUS
	div t0, t0, t1
	sw t0, BONUS, t2
	# clear screen
	lw t0, DISPLAY_DATA
	li t1, 12
	sw t1, 0(t0)
	# change phase
	li t0, 1
	sw t0, PHASE, t1
	lw t1, TIME
	lw t1, 0(t1)
	addi t0, t1, 1000 # change timecmp to time + 1000
	lw t1, TIMECMP
	sw t0, 0(t1)
	j start_game
	
start_game:
	lw t1, KEYBOARD_CONTROL
	li t0, 2
	sw t0, 0(t1) # set bit 1 of keyboard control to 1
	lw t0, POINTER # pointer points to the next letter in the phrase that user has to type
	lb t0, 0(t0)
	li t1, 10
	beq t1, t0, change # if newline encountered then change phrase
	
	
display:
	lw t1, TBUDGET
	blez t1, endGame # end game if timer ereaches zero	
	
	# update display if flag is not equal to zero				
	lw t0, CHANGED
	bnez t0, printDisplay
	
	
	j start_game			

#------------------------------------------------------------------------------
# printDisplay
# Args: None
#
# Prints display when something is changed in the output
#------------------------------------------------------------------------------	
printDisplay:
	# clear screen
	lw t0, DISPLAY_DATA
	li t1, 12
	sw t1, 0(t0)
	
	# print points
	lw a0, POINTS
	li a1, 0
	li a2, 0
	jal intToStr
	
	la    t0, string2  # prints "points" part of the string
        mv    a0, t0       # a0 <- strAddr
        li    a1, 0        # a1 <- row = i
        li    a2, 4        # a2 <- col = 0
	jal   printStr
	
	# prints timer
	lw a0, TBUDGET
	li a1, 1
	li a2, 0
	jal intToStr
	
	# prints phrase
	mv a0, s1
	li a1, 4
	li a2, 0
	jal printStr	
	
	# prints progress bar
	jal printBar
	
	# set changed flag to zero
	li t1, 0
	sw t1, CHANGED, t0
	
	
	j start_game #loop
	
#------------------------------------------------------------------------------
# printBar
# Args: None
#	
# creates a progress bar based on the number of matches and prints it
#------------------------------------------------------------------------------		
printBar:
	# stack
	addi sp, sp -12
	sw s0, 4(sp)
	sw s1, 8(sp)
	sw ra, 0(sp)
	
	
	lw s0, MATCHES # number of correct matches
	mv s1, zero    # loop counter
loop_match:
	beq s1, s0 donem
	li a0, 42
	li a1, 5
	mv a2, s1
	jal printChar # print '*' in a loop
	addi s1, s1, 1
	j loop_match
donem:
	# unstack
	lw ra, 0(sp)
	lw s0, 4(sp)
	lw s1, 8(sp)
	addi sp, sp, 12
	jalr zero, ra, 0		
	
#------------------------------------------------------------------------------
# random
# Args: None
#
# generates a random number between 0-24 and returns it in a0
#------------------------------------------------------------------------------												
random:
	lw t0, XiVar
	lw t1, aVar
	lw t2, cVar
	lw t3, mVar
	mul t0, t0, t1 # x * a
	add t0, t0, t2 # (x*a) + c
	rem t0, t0, t3 # ((x*a) + c) % m
	sw t0, XiVar, t1
	mv a0, t0
	jalr zero, ra, 0
	
#------------------------------------------------------------------------------
# intToStr 
# Args: a0 - int: the int to be printed
#	a1 - row : the row to be printed on
#	a2- col: the column to be printed on 

# converts a string into an ASCII string and prints it
#------------------------------------------------------------------------------					
intToStr:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	mv t0, a0
	li t1, 10
	la t4, cString
divide:	

	
	div t3, t0, t1 
	beqz t3, end 
	rem t2, t0, t1
	mv t0, t3
	# add digits to str one by one in reverse
	
	addi t2, t2, 48
	sb t2, 0(t4)
	addi t4, t4, 1
	j divide
	
end:
	# add null terminator
	rem t2, t0, t1
	addi t2, t2, 48
	sb t2, 0(t4)
	addi t4, t4, 1
	sb zero, 0(t4)
	mv t2, zero
	la t0, cString
	
len_string: # counts the len of the string
	la t3, aString
	
	lb t1, 0(t0)
	beq t1, zero, reverse
	addi t2, t2, 1 # count the length of string excluding null
	addi t0, t0, 1
	j len_string
reverse: # reverses the string
	beqz t2, donze
	addi t0, t0, -1
	lb t1, 0(t0)
	sb t1, 0(t3)
	addi t3, t3, 1
	addi t2, t2, -1
	j reverse
	
donze:
	sb zero, 0(t3)				
	
	la    t0, aString
        mv    a0, t0       
	jal   printStr
	
	# unstac
	lw ra, 0(sp)
	addi sp, sp, 4
	jalr zero, ra, 0


handler:
	# stack
	csrrw a0, 0x040, a0 # a0 <- Addr[iTrapData]
	sw    t0, 0(a0)
	sw    t1, 4(a0)
	
	csrrw t1, 66, zero # t1 <- ucause then empty ucause
	# remove bit 31
	li	t0, 0x7FFFFFFF
	and t0, t0, t1
	li t1, 8
	beq t0, t1, keyboard_interrupt # branch if ucause was a user external interrupt
	li t1, 4
	beq t0, t1, timer_interrupt
	#bne t0, t1, handlerTerminate # make it a jump?
	j handlerTerminate
	
	
keyboard_interrupt:
	
	lw t1, KEYBOARD_DATA
	lw t1, 0(t1)
	lw t0, PHASE
	beqz t0, setLevel
	bnez t0, check
	# unstack
	lw t0, 0(a0)
	lw t1, 4(a0)
	csrrw a0, 0x040, a0 # a0 <- program a0
	uret
setLevel: # sets the level of the game
	addi t1, t1, -48
	sw t1, LEVEL, t0
	lw t0, 0(a0)
	lw t1, 4(a0)
	csrrw a0, 0x040, a0 # a0 <- program a0
	uret
check: # checks if user input matches phrase

	lw t0, POINTER # pointer points to the next letter in the phrase that user has to type
	lb t0, 0(t0)
	lw t1, KEYBOARD_DATA
	lb t1, 0(t1)
	beq t1, t0, update # if input matches phrase then update progress
	li t1, 10
	
	# unstack
	lw t0, 0(a0)
	lw t1, 4(a0)
	csrrw a0, 0x040, a0 # a0 <- program a0
	uret
change: # changes phrase and updates timer when phrase is completed
	
	# add time
	lw t0, TBUDGET
	lw t1, BONUS
	add t0, t0, t1
	sw t0, TBUDGET, t1
	
	# reset matches to 0
	li t1, 0
	sw t1, MATCHES, t0 
	jal choose_phrase # choose new phrase
	
	# update flag to 1
	li t0, 1
	sw t0, CHANGED, t1
	
	# print display
	j display

		
update: # updates progress

	# increment pointer
	lw t0, POINTER
	addi t0, t0, 1
	sw t0, POINTER, t1
	
	# increment matches
	lw t0, MATCHES
	addi t0, t0, 1
	sw t0, MATCHES, t1
	
	# update flag
	li t0, 1
	sw t0, CHANGED, t1
	
	# update points
	lw t0, POINTS
	addi t0, t0, 1
	sw t0, POINTS, t1
	
	#unstack
	lw t0, 0(a0)
	lw t1, 4(a0)
	csrrw a0, 0x040, a0 # a0 <- program a0
	uret
	
			
timer_interrupt: # 
	
	lw t1, TIME
	lw t1, 0(t1)
	addi t0, t1, 1000 # change timecmp to time + 1000
	lw t1, TIMECMP
	sw t0, 0(t1)
	
	# decrement time and set flag to 1
	lw t0, TBUDGET
	addi t0, t0, -1
	sw t0, TBUDGET, t1
	li t0, 1
	sw t0, CHANGED, t1
	
	# unstack
	lw t0, 0(a0)
	lw t1, 4(a0)
	csrrw a0, 0x040, a0 # a0 <- program a0
	uret

printStr:
	# Stack
	addi	sp, sp, -16
	sw	ra, 0(sp)
	sw	s0, 4(sp)
	sw	s1, 8(sp)
	sw	s2, 12(sp)
	
	mv	s0, a0
	mv	s1, a1
	mv	s2, a2
	printStrLoop:
		# Check for null-character
		lb	t0, 0(s0)	# t0 <- char = str[i]
		# Loop while(str[i] != '\0')
		beq	t0, zero, printStrLoopEnd
		li	t1, 10
		beq	t0, t1, printStrLoopEnd
		# Print character
		mv	a0, t0		# a0 <- char
		mv	a1, s1		# a1 <- row
		mv	a2, s2		# a2 <- col
		jal	printChar
		
		addi	s0, s0, 1	# i++
		addi	s2, s2, 1	# col++
		j	printStrLoop
	printStrLoopEnd:
	
	# Unstack
	lw	ra, 0(sp)
	lw	s0, 4(sp)
	lw	s1, 8(sp)
	lw	s2, 12(sp)
	addi	sp, sp, 16
	jalr	zero, ra, 0

	
#------------------------------------------------------------------------------
# printChar
# Args:
#	a0: char - The character to print
#	a1: row - The row to print the given character
#	a2: col - The column to print the given character
#
# Prints a single character to the Keyboard and Display MMIO Simulator terminal
# at the given row and column.
#------------------------------------------------------------------------------
printChar:
	# Stack
	addi	sp, sp, -16
	sw	ra, 0(sp)
	sw	s0, 4(sp)
	sw	s1, 8(sp)
	sw	s2, 12(sp)
	
	# Save parameters
	add	s0, a0, zero
	add	s1, a1, zero
	add	s2, a2, zero
	
	jal	waitForDisplayReady	# Wait for display before printing
	
	# Load bell and position into a register
	addi	t0, zero, 7	# Bell ascii
	slli	s1, s1, 8	# Shift row into position
	slli	s2, s2, 20	# Shift col into position
	or	t0, t0, s1
	or	t0, t0, s2	# Combine ascii, row, & col
	
	# Move cursor
	lw	t1, DISPLAY_DATA
	sw	t0, 0(t1)
	
	jal	waitForDisplayReady	# Wait for display before printing
	
	# Print char
	lw	t0, DISPLAY_DATA
	sw	s0, 0(t0)
	
	# Unstack
	lw	ra, 0(sp)
	lw	s0, 4(sp)
	lw	s1, 8(sp)
	lw	s2, 12(sp)
	addi	sp, sp, 16
	jalr    zero, ra, 0
	
	
#------------------------------------------------------------------------------
# waitForDisplayReady
#
# A method that will check if the Keyboard and Display MMIO Simulator terminal
# can be writen to, busy-waiting until it can.
#------------------------------------------------------------------------------
waitForDisplayReady:
	# Loop while display ready bit is zero
	lw	t0, DISPLAY_CONTROL
	lw	t0, 0(t0)
	andi	t0, t0, 1
	beq	t0, zero, waitForDisplayReady
	
	jalr    zero, ra, 0

handlerTerminate:
	# Print error msg before terminating
	li	a7, 4
	la	a0, INTERRUPT_ERROR
	ecall
	li	a7, 34
	csrrci	a0, 66, 0
	ecall
	li	a7, 4
	la	a0, INSTRUCTION_ERROR
	ecall
	li	a7, 34
	csrrci	a0, 65, 0
	ecall
handlerQuit:
	li	a7, 10
	ecall	# End of program
	
endGame:
	li a7, 10
	ecall	
