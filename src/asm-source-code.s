            TTL Multiprecision Arithmetic
;****************************************************************
; This program performs multiprecision arithmetic on the two
; 128-bit hex numbers the user provides, and prints the result.
;Name:  Helena Lynd
;Date:  10/19/22
;---------------------------------------------------------------
;Keil Template for KL05
;R. W. Melton
;September 13, 2020
;****************************************************************
;Assembler directives
            THUMB
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;Include files
            GET  MKL05Z4.s     ;Included by start.s
            OPT  1   		   ;Turn on listing
;****************************************************************
;EQUates
LEAST_BYTE_MASK	 EQU  0x000F
	
N EQU 4

;UART0 Init Masks
TDRE_MASK	EQU		2_10000000
RDRF_MASK	EQU		2_00100000
	
;String Operations
MAX_STRING	EQU		80

;Characters
CR          EQU  0x0D
LF          EQU  0x0A
NULL        EQU  0x00
LESS_THAN_SYM	EQU	 0x3C
GREATER_THAN_SYM	EQU	0x3E
COLON_CHAR  EQU  0x3A	

; Queue management record field offsets
IN_PTR      EQU   0
OUT_PTR     EQU   4
BUF_STRT    EQU   8
BUF_PAST    EQU   12
BUF_SIZE    EQU   16
NUM_ENQD    EQU   17

; Queue structure sizes
Q_BUF_SZ    EQU   4   ;Queue contents
Q_REC_SZ    EQU   18  ;Queue management record
;---------------------------------------------------------------
;PORTx_PCRn (Port x pin control register n [for pin n])
;___->10-08:Pin mux control (select 0 to 8)
;Use provided PORT_PCR_MUX_SELECT_2_MASK
;---------------------------------------------------------------
;Port B
PORT_PCR_SET_PTB2_UART0_RX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
PORT_PCR_SET_PTB1_UART0_TX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
;---------------------------------------------------------------
;SIM_SCGC4
;1->10:UART0 clock gate control (enabled)
;Use provided SIM_SCGC4_UART0_MASK
;---------------------------------------------------------------
;SIM_SCGC5
;1->09:Port A clock gate control (enabled)
;Use provided SIM_SCGC5_PORTA_MASK
;---------------------------------------------------------------
;SIM_SOPT2
;01=27-26:UART0SRC=UART0 clock source select (MCGFLLCLK)
;---------------------------------------------------------------
SIM_SOPT2_UART0SRC_MCGFLLCLK  EQU  \
                                 (1 << SIM_SOPT2_UART0SRC_SHIFT)
;---------------------------------------------------------------
;SIM_SOPT5
; 0->   16:UART0 open drain enable (disabled)
; 0->   02:UART0 receive data select (UART0_RX)
;00->01-00:UART0 transmit data select source (UART0_TX)
SIM_SOPT5_UART0_EXTERN_MASK_CLEAR  EQU  \
                               (SIM_SOPT5_UART0ODE_MASK :OR: \
                                SIM_SOPT5_UART0RXSRC_MASK :OR: \
                                SIM_SOPT5_UART0TXSRC_MASK)
;---------------------------------------------------------------
;UART0_BDH
;    0->  7:LIN break detect IE (disabled)
;    0->  6:RxD input active edge IE (disabled)
;    0->  5:Stop bit number select (1)
;00001->4-0:SBR[12:0] (UART0CLK / [9600 * (OSR + 1)]) 
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDH_9600  EQU  0x01
;---------------------------------------------------------------
;UART0_BDL
;26->7-0:SBR[7:0] (UART0CLK / [9600 * (OSR + 1)])
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDL_9600  EQU  0x38
;---------------------------------------------------------------
;UART0_C1
;0-->7:LOOPS=loops select (normal)
;0-->6:DOZEEN=doze enable (disabled)
;0-->5:RSRC=receiver source select (internal--no effect LOOPS=0)
;0-->4:M=9- or 8-bit mode select 
;        (1 start, 8 data [lsb first], 1 stop)
;0-->3:WAKE=receiver wakeup method select (idle)
;0-->2:IDLE=idle line type select (idle begins after start bit)
;0-->1:PE=parity enable (disabled)
;0-->0:PT=parity type (even parity--no effect PE=0)
UART0_C1_8N1  EQU  0x00
;---------------------------------------------------------------
;UART0_C2
;0-->7:TIE=transmit IE for TDRE (disabled)
;0-->6:TCIE=transmission complete IE for TC (disabled)
;0-->5:RIE=receiver IE for RDRF (disabled)
;0-->4:ILIE=idle line IE for IDLE (disabled)
;1-->3:TE=transmitter enable (enabled)
;1-->2:RE=receiver enable (enabled)
;0-->1:RWU=receiver wakeup control (normal)
;0-->0:SBK=send break (disabled, normal)
UART0_C2_T_R  EQU  (UART0_C2_TE_MASK :OR: UART0_C2_RE_MASK)
;---------------------------------------------------------------
;UART0_C3
;0-->7:R8T9=9th data bit for receiver (not used M=0)
;           10th data bit for transmitter (not used M10=0)
;0-->6:R9T8=9th data bit for transmitter (not used M=0)
;           10th data bit for receiver (not used M10=0)
;0-->5:TXDIR=UART_TX pin direction in single-wire mode
;            (no effect LOOPS=0)
;0-->4:TXINV=transmit data inversion (not inverted)
;0-->3:ORIE=overrun IE for OR (disabled)
;0-->2:NEIE=noise error IE for NF (disabled)
;0-->1:FEIE=framing error IE for FE (disabled)
;0-->0:PEIE=parity error IE for PF (disabled)
UART0_C3_NO_TXINV  EQU  0x00
;---------------------------------------------------------------
;UART0_C4
;    0-->  7:MAEN1=match address mode enable 1 (disabled)
;    0-->  6:MAEN2=match address mode enable 2 (disabled)
;    0-->  5:M10=10-bit mode select (not selected)
;01111-->4-0:OSR=over sampling ratio (16)
;               = 1 + OSR for 3 <= OSR <= 31
;               = 16 for 0 <= OSR <= 2 (invalid values)
UART0_C4_OSR_16           EQU  0x0F
UART0_C4_NO_MATCH_OSR_16  EQU  UART0_C4_OSR_16
;---------------------------------------------------------------
;UART0_C5
;  0-->  7:TDMAE=transmitter DMA enable (disabled)
;  0-->  6:Reserved; read-only; always 0
;  0-->  5:RDMAE=receiver full DMA enable (disabled)
;000-->4-2:Reserved; read-only; always 0
;  0-->  1:BOTHEDGE=both edge sampling (rising edge only)
;  0-->  0:RESYNCDIS=resynchronization disable (enabled)
UART0_C5_NO_DMA_SSR_SYNC  EQU  0x00
;---------------------------------------------------------------
;UART0_S1
;0-->7:TDRE=transmit data register empty flag; read-only
;0-->6:TC=transmission complete flag; read-only
;0-->5:RDRF=receive data register full flag; read-only
;1-->4:IDLE=idle line flag; write 1 to clear (clear)
;1-->3:OR=receiver overrun flag; write 1 to clear (clear)
;1-->2:NF=noise flag; write 1 to clear (clear)
;1-->1:FE=framing error flag; write 1 to clear (clear)
;1-->0:PF=parity error flag; write 1 to clear (clear)
UART0_S1_CLEAR_FLAGS  EQU  (UART0_S1_IDLE_MASK :OR: \
                            UART0_S1_OR_MASK :OR: \
                            UART0_S1_NF_MASK :OR: \
                            UART0_S1_FE_MASK :OR: \
                            UART0_S1_PF_MASK)
;---------------------------------------------------------------
;UART0_S2
;1-->7:LBKDIF=LIN break detect interrupt flag (clear)
;             write 1 to clear
;1-->6:RXEDGIF=RxD pin active edge interrupt flag (clear)
;              write 1 to clear
;0-->5:(reserved); read-only; always 0
;0-->4:RXINV=receive data inversion (disabled)
;0-->3:RWUID=receive wake-up idle detect
;0-->2:BRK13=break character generation length (10)
;0-->1:LBKDE=LIN break detect enable (disabled)
;0-->0:RAF=receiver active flag; read-only
UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS  EQU  \
        (UART0_S2_LBKDIF_MASK :OR: UART0_S2_RXEDGIF_MASK)
;---------------------------------------------------------------
;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            ENTRY
            EXPORT  Reset_Handler
            IMPORT  Startup
Reset_Handler  PROC  {}
main
;---------------------------------------------------------------
;Mask interrupts
            CPSID   I
;KL05 system startup with 48-MHz system clock
            BL      Startup
;---------------------------------------------------------------
;>>>>> begin main program code <<<<<
			BL		Init_UART0_Polling
			
			LDR		R0,=String1				;Initializes String1 to a NULL character
			MOVS	R1,#NULL
			STRB	R1,[R0,#0]
			
			LDR		R0,=inputString1				;Initializes inputString1 to a NULL character
			MOVS	R1,#NULL
			STRB	R1,[R0,#0]
			
			LDR		R0,=inputString2				;Initializes inputString2 to a NULL character
			MOVS	R1,#NULL
			STRB	R1,[R0,#0]
			
			LDR		R0,=inputCopy					;Initializes inputCopy to a NULL character
			MOVS	R1,#NULL
			STRB	R1,[R0,#0]
			
Start		LDR		R0,=prompt1				;Prints "Enter the first 128-bit hex number: "
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
												
HexSearch	LDR		R0,=hexprompt			;Prints "0x"
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			
			LDR		R0,=inputString1		;Initialize R0 and R1
			MOVS	R1,#N						
			BL		GetHexIntMulti			;Takes user input string
			
			BCS		InvalidNum				;if (number input is correct)
			LDR		R0,=prompt2				;	Print "Enter 128 bit hex number to add: "
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			B		HexSearch2				;	Loop to hex search 2
			
InvalidNum	LDR 	R0,=promptInvalid		;	Print "Invalid number--try again:"
			MOVS	R1,#MAX_STRING
			BL	 	PutStringSB
			B		HexSearch				;	Loop
			
			
HexSearch2	LDR		R0,=hexprompt			;Prints "0x"
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			
			LDR		R0,=inputString2		;Initialize R0 and R1
			MOVS	R1,#N							
			BL		GetHexIntMulti			;Takes user input string
			
			BCS		Invalid2				;if (number input is correct)
			
			LDR		R0,=sum
			LDR		R1,=inputString1
			LDR		R2,=inputString2
			MOVS	R3,#N
			BL		AddIntMultiU			;	add the numbers
			BCS		Overflow
			LDR		R0,=sumprompt			;	if C is clear
			MOVS	R1,#MAX_STRING			;		print "Sum:" and the sum
			BL		PutStringSB
			LDR		R0,=sum
			MOVS	R1,#N
			BL		PutHexIntMulti	
			MOVS	R0,#CR					;Prints carriage return
			BL		PutChar
			MOVS	R0,#LF					;Prints line feed
			BL		PutChar
			B		Start
											
Invalid2	LDR 	R0,=promptInvalid		;	Print "Invalid number--try again:"
			MOVS	R1,#MAX_STRING
			BL	 	PutStringSB
			B		HexSearch2				;	Loop	

Overflow	LDR 	R0,=promptOverflow		;	Print "0xOVERFLOW"
			MOVS	R1,#MAX_STRING
			BL	 	PutStringSB
			MOVS	R0,#CR					;Prints carriage return
			BL		PutChar
			MOVS	R0,#LF					;Prints line feed
			BL		PutChar
			B		Start					;	Loop	
		
;>>>>>   end main program code <<<<<
;Stay here
            B       .
            ENDP
;>>>>> begin subroutine code <<<<<
Init_UART0_Polling	PROC	{R0-R13}
;****************************************************************
; Initializes KL05 with 8N0 and 9600 baud
; Inputs : None
; Outputs : None
; Local Variables
;	R0 : Stores memory addresses
;	R1 : Stores masks
;	R2 : Stores the values at memory addresses in R0
;****************************************************************
			PUSH	{R0-R2}
														;Setting up SIM
			LDR		R0,=SIM_SOPT2							;SIM_SOPT2
			LDR		R1,=SIM_SOPT2_UART0SRC_MASK				;Want : 2_XXXX01XXXXXXXXXXXXXXXXXXXXXXXXXX
			LDR		R2,[R0,#0]
			BICS	R2,R2,R1									;Clear bit 27
			LDR		R1,=SIM_SOPT2_UART0SRC_MCGFLLCLK
			ORRS	R2,R2,R1									;Set bit 26
			STR		R2,[R0,#0]								
															;SIM_SOPT5
			LDR		R0,=SIM_SOPT5								;Want : 2_00000000000000000000000000000000
			LDR		R1,=SIM_SOPT5_UART0_EXTERN_MASK_CLEAR
			LDR		R2,[R0,#0]
			BICS	R2,R2,R1									;Clear all bits
			STR		R2,[R0,#0]
															;SIM_SCGC4
			LDR		R0,=SIM_SCGC4								;Want : 2_XXXXXXXXXXXXXXXXXXXXX0XXXXXXXXXX
			LDR		R1,=SIM_SCGC4_UART0_MASK
			LDR		R2,[R0,#0]
			ORRS	R2,R2,R1									;Set bit 10
			STR		R2,[R0,#0]
															;SIM_SCGC5
			LDR		R0,=SIM_SCGC5								;Want : 2_XXXXXXXXXXXXXXXXXXXXX0XXXXXXXXXX
			LDR		R1,=SIM_SCGC4_UART0_MASK
			LDR		R2,[R0,#0]
			ORRS	R2,R2,R1									;Set bit 10
			STR		R2,[R0,#0]
														;Setting up ports
			LDR		R0,=PORTB_PCR2							;PCR 2
			LDR		R1,=PORT_PCR_SET_PTB2_UART0_RX				;Want : 2_XXXXXXX0XXXXXXXXXXXXX010XXXXXXXX
			STR		R1,[R0,#0]
			LDR		R0,=PORTB_PCR1							;PCR 1
			LDR		R1,=PORT_PCR_SET_PTB1_UART0_TX				;Want : 2_XXXXXXX0XXXXXXXXXXXXX010XXXXXXXX
			STR		R1,[R0,#0]
														;Setting up UART0
			LDR		R0,=UART0_BASE							
			MOVS	R1,#UART0_C2_T_R						;Disable UART0
			LDRB	R2,[R0,#UART0_C2_OFFSET]
			BICS	R2,R2,R1
			STRB	R2,[R0,#UART0_C2_OFFSET]
			MOVS	R1,#UART0_BDH_9600						;UART0_BDH and UART0_BDL
			STRB	R1,[R0,#UART0_BDH_OFFSET]					;Set baud rate to 9600
			MOVS	R1,#UART0_BDL_9600
			STRB	R1,[R0,#UART0_BDL_OFFSET]
			MOVS	R1,#UART0_C1_8N1						;UART0_C1
			STRB	R1,[R0,#UART0_C1_OFFSET]					;Want : 2_00X0000X
			MOVS	R1,#UART0_C3_NO_TXINV					;UART_C3
			STRB	R1,[R0,#UART0_C3_OFFSET]					;Want : 2_XXX00000
			MOVS	R1,#UART0_C4_NO_MATCH_OSR_16			;UART_C4
			STRB	R1,[R0,#UART0_C4_OFFSET]					;Want : 2_00001111
			MOVS	R1,#UART0_C5_NO_DMA_SSR_SYNC			;UART_C5
			STRB	R1,[R0,#UART0_C5_OFFSET]					;Want : 2_00000000
			MOVS	R1,#UART0_S1_CLEAR_FLAGS				;UART_S1
			STRB	R1,[R0,#UART0_S1_OFFSET]					;Clear flags
			MOVS	R1,#UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS	;UART_S2
			STRB	R1,[R0,#UART0_S2_OFFSET]									;Clear flags
			MOVS	R1,#UART0_C2_T_R						;Enable UART0
			STRB	R1,[R0,#UART0_C2_OFFSET]
			
			POP		{R0-R2}
			
			BX		LR
			ENDP
;****************************************************************
AddIntMultiU	PROC	{R1-R14}
;****************************************************************
; Adds two n-word unsigned numbers in memory and stores the result to memory
; Uses ADCS to add word by word, starting from the least significant
; words of the augend and addend and working to the most significant words.
; Input
;	R0 : address of n-word sum (unsigned)
;	R1 : address of n-word augend (unsigned)
;	R2 : address of n-word addend (unsigned)
;	R3 : n, number of words in source and result operands (unsigned)
; Output
;	R0 : address of n-word sum
;	C Flag : 0 indicates success, 1 indicates overflow
; Local
;	R4 : Value at address in R1
;	R5 : Value at address in R2
;	R6 : Stored value of C flag
;	R7 : APSR_C_MASK
;****************************************************************				
			PUSH	{R0-R7}
			
			MOVS	R6,#0
			
			;Load words of R1 and R2 from least significant to most
LoopAdds	LDM		R1!,{R4}
			LDM		R2!,{R5}
			
			;Restore C
			MSR		APSR,R6
			
			;Add with carry set
			ADCS	R4,R4,R5
			
			;Store C
			MRS		R6, APSR			
			LDR		R7,=APSR_C_MASK
			ANDS	R6,R6,R7
			
			;Store Sum
			STM		R0!,{R4}
			
			;Increment Loop Counter
			SUBS	R3,R3,#1
			CMP		R3,#0
			BNE		LoopAdds
			
			
EndAdds		;Restore C
			MSR		APSR,R6
			
			POP		{R0-R7}
			BX		LR
			ENDP
;****************************************************************
GetHexIntMulti	PROC	{R1-R14}
;****************************************************************
; Gets an n-word unsigned number from the user typed in text
; hexadecimal representation, and stores it in binary in memory 
; Reads characters typed by the user until the enter key is pressed 
; by calling the subroutine GetStringSB. It then converts the
; ASCII hexadecimal representation input by the user to binary.
; Input
;	R0 : address of n-word number for user input
;	R1 : n, number of words in the input number
; Output
;	R0 : address of n-word number input by user
;	C Flag : 0 indicates success, 1 indicates failure
; Local
;	R3 : Current character
;	R4 : Loop Counter
;	R5 : Second character
;	R6 : 4 X N
;****************************************************************
			PUSH	{R0-R6,LR}
			
			MOVS	R2,R0
			
			;Gets user input string and stores in temporary copy
			LDR		R0,=inputCopy
			LSLS	R1,R1,#3
			;SUBS	R1,R1,#1
			BL		GetStringSB
			
			MOVS	R4,#0
			;Convert ASCII codes to hex
LoopHexConv	LDRB	R3,[R0,R4]
			CMP		R3,#0
			BEQ		EndLoopHex
			CMP		R3,#0x39
			BLS		ConvNum
			CMP		R3,#0x41
			BLO		InvalidInp
			CMP		R3,#0x46
			BHI		InvalidInp
			SUBS	R3,R3,#0x31
			SUBS	R3,R3,#6
BackHexCon	STRB	R3,[R0,R4]
			ADDS	R4,R4,#1
			B		LoopHexConv
			
ConvNum		CMP		R3,#0x30
			BHS		ConvNum2
			B		InvalidInp

ConvNum2    SUBS	R3,R3,#0x30
			B		BackHexCon	
			
EndLoopHex	CMP		R4,#32
			BNE		InvalidInp

			;Consolidate hex
			MOVS	R4,#0
			MOVS	R6,#0
PackLoop	
			LDRB	R3,[R0,R4]
			ADDS	R4,R4,#1
			LDRB	R5,[R0,R4]
			ADDS	R4,R4,#1
			LSLS	R3,R3,#4
			ORRS	R3,R3,R5		
			STRB	R3,[R0,R6]
			ADDS	R6,R6,#1
			CMP		R6,R1
			BEQ		CopyLoopS
			B		PackLoop	

;R0 : address of string copy
;R2 : address of string
;R4 : offset for string copy, starting at 0
;R6 : offset for string, starting at n * 4 
CopyLoopS	MOVS	R4,#0
			LSRS	R1,R1,#1
			MOVS	R6,R1
			SUBS	R6,R6,#1
CopyLoop	LDRB	R3,[R0,R4]
			STRB	R3,[R2,R6]
			ADDS	R4,R4,#1
			SUBS	R6,R6,#1
			CMP		R4,R1
			BEQ		EndPackLoop
			B		CopyLoop
		
EndPackLoop	MRS		R4, APSR			;Clear C
			LDR		R5,=APSR_C_MASK
			BICS	R4,R4,R5
			MSR		APSR, R4
			B		EndHexInt
			
InvalidInp	MRS		R4, APSR			;Set C
			LDR		R5,=APSR_C_MASK	
			ORRS	R4,R4,R5
			MSR		APSR, R4

EndHexInt	POP 	{R0-R6, PC}
			ENDP
;****************************************************************
PutHexIntMulti	PROC	{R1-R14}
;****************************************************************
; Outputs an n-word unsigned number to the terminal in text 
; hexadecimal representation using 8n hex digits,
; where the value in R1 is n.
; Input
;	R0 : address of n-word number to output
;	R1 : n, number of words in the input number
; Output
;	None
; Local
;	R0 : value of word for PutNumHex
;	R1 : n * 4
;	R2 : address of n-word number to output
;****************************************************************
		PUSH	{R0-R2, LR}
		
		;Initialize loop counter and memory address
		LSLS	R1,R1,#2
		SUBS	R1,R1,#4
		MOVS	R2,R0
		
		;Load words from most significant to least significant
PutLoop	LDR		R0,[R2,R1]
		BL		PutNumHex
		SUBS	R1,R1,#4
		BPL		PutLoop

EndPutHex	POP		{R0-R2, PC}		
			ENDP				
;****************************************************************
PutNumHex	PROC	{R0-R14}
;****************************************************************
; Prints to the terminal screen the text hexadecimal representation 
; of the unsigned word value in R0.
; Input
;	R0 : Value to convert to hex (unsigned word value)
; Output
;	None
; Local
;	R1 : Copy of value to convert
;	R2 : Number by which to shift
;	R3 : Least byte mask
;****************************************************************
			PUSH	{R0-R3,LR}

			MOVS	R1,R0
			MOVS	R2,#28
			MOVS	R3,#LEAST_BYTE_MASK
			
LoopHex		MOVS	R0,R1
			ASRS	R0,R0,R2
			ANDS	R0,R0,R3
			CMP		R0,#10
			BHS		HexCodeConv
			ADDS	R0,R0,#0x30
BackHex		BL		PutChar
			SUBS	R2,R2,#4
			CMP		R2,#0
			BEQ		EndHex
			B		LoopHex

HexCodeConv ADDS	R0,R0,#0x37
			B		BackHex

EndHex		MOVS	R0,R1
			ANDS	R0,R0,R3
			CMP		R0,#10
			BHS		HexCode2
			ADDS	R0,R0,#0x30
BackHex2	BL		PutChar
			B		EndHexConv

HexCode2    ADDS	R0,R0,#0x37
			B		BackHex2

EndHexConv	POP		{R0-R3,PC}

			ENDP
;****************************************************************
PutNumUB	PROC	{R0-R14}
;****************************************************************
; Prints to the terminal screen the text decimal representation 
; of the unsigned byte value in R0.
; Input
;	R0 : Value to convert
; Output
;	None
;****************************************************************
			PUSH	{R0,R1,LR}
			
			MOVS	R1,#LEAST_BYTE_MASK
			ANDS	R0,R0,R1
			BL		PutNumU

			POP		{R0,R1,PC}
			ENDP
;****************************************************************
GetStringSB	PROC	{R0-R14}
;****************************************************************
; Inputs a string from the terminal keyboard to memory starting at 
; the address in R0 and adds null termination. It ends terminal 
; keyboard input when the user presses the enter key.
; Input
;	R0 : Pointer to destination string
;	R1 : Buffer Capacity
; Output
;	R0 : string buffer in memory for input from user (via reference by unsigned word address)
; Local Variables:
;	R0 : GetChar Result / Current Character
;	R1 : Memory address of destination string
;	R2 : Index counter
;	R3 : Buffer Capacity
;****************************************************************

			PUSH	{R0-R3,LR}
			MOVS	R3,R1					;Initialize R3
			MOVS	R1,R0					;Initialize R1
			MOVS	R2,#0					;Initialize R2
StartLoop	BL		GetChar					;Initialize R0
			CMP		R2,R3					;Check if index (number of characters entered) has hit buffer limit
			BHS		BufferHit				;If it has, go to separate buffer loop
			BL		PutChar
			CMP		R0,#CR					
			BEQ		EndLoop					;while(character != CR){
			STRB	R0,[R1,R2]				;	Store character, then increment pointer
			ADDS	R2,R2,#1				;	GetChar
			B		StartLoop
			
BufferHit	CMP		R0,#CR
			BEQ		EndLoop
			BL		GetChar
			B		BufferHit

EndLoop		MOVS	R0,#NULL				;Store null character at current pointer
			STRB	R0,[R1,R2]
			MOVS	R0,#CR					;Prints carriage return
			BL		PutChar
			MOVS	R0,#LF					;Prints line feed
			BL		PutChar

			POP		{R0-R3,PC}
			ENDP
;****************************************************************
PutStringSB	PROC	{R0-R14}
;****************************************************************
; Displays a null-terminated string to the terminal screen from 
; memory starting at the address in R0
; Input
;	R0 : Pointer to source string
;	R1 : Buffer Capacity
; Output : None
; Local Variables:
;	R0 : Character to output / current character
;	R1 : Address in memory to read from
;	R2 : Index counter
;	R3 : Buffer capacity
;****************************************************************

			PUSH	{R0-R3,LR}
			
			MOVS	R3,R1					;Initialize R3
			MOVS	R1,R0					;Initialize R1
			MOVS	R2,#0					;Initialize R2
			LDRB	R0,[R1,R2]				;Initialize R0

WhileLoop	CMP		R2,R3					;Check if index (number of characters printed) has hit buffer limit
			BEQ		EndWhileLoop			;If it has, break
			CMP		R0,#NULL				;while(character != NULL){
			BEQ		EndWhileLoop			;	PutChar
			BL		PutChar					;	Read next character (increment pointer)
			ADDS	R2,R2,#1				;}
			LDRB	R0,[R1,R2]
			B		WhileLoop
EndWhileLoop

			POP		{R0-R3, PC}
			ENDP
;****************************************************************
PutNumU		PROC	{R0-R14}
;****************************************************************
; Displays the text decimal representation to the terminal
; screen of the unsigned word value in R0
; Input 
;	R0 : Unsigned word value to print
; Output : None
; Local Variables
;	R0 : Divisor (number by which to divide, 10)  / After DIVU : Quotient
;	R1 : Dividend (number to divide, input)       / After DIVU : Remainder
;	R2 : Counter 
;	R3 : ASCII code of 0
;****************************************************************
			PUSH	{R0-R3,LR}
			
			MOVS	R1,R0			;Initialize R1 to be dividend, input
			MOVS	R0,#10			;Initialize R0 to be divisor, 10
			MOVS	R2,#0			;Initialize R2
			MOVS	R3,#'0'			;Initialize R3

			CMP		R1,#0
			BEQ		IfZero
			
DivLoop		BL		DIVU			
			BEQ		IfZero
			PUSH	{R1}
			MOVS	R1,R0					; Make quotient the new dividend (number to divide) 
			MOVS	R0,#10					; Make 10 the new divisor (number by which to divide)
			ADDS	R2,R2,#1				; Increment counter
			B		DivLoop

IfZero		PUSH	{R1}
			ADDS	R2,R2,#1
			B		PrintLoop

PrintLoop	CMP		R2,#0
			BEQ		EndPrint
			POP		{R0}
			ADDS	R0,R0,R3
			BL		PutChar
			SUBS	R2,R2,#1
			B		PrintLoop
EndPrint
			
			POP		{R0-R3, PC}
			ENDP
;***************************************************************
GetChar		PROC	{R1-R13}
;***************************************************************
; Reads a single character from the terminal keyboard into R0.
; Input: None
; Output: R0: Character received
; Local Variables:
;	R1: Memory address of UART0
;	R2: Value of UART_S1
;	R3: RDRF Mask
;***************************************************************
			PUSH	{R1-R3}
			
			LDR		R1,=UART0_BASE	
			MOVS	R3,#RDRF_MASK
GetWhile	LDRB	R2,[R1,#UART0_S1_OFFSET]	    ;Pulls S1 every iteration			;while (RDRF != 1){
			ANDS	R2,R2,R3					;Clears all bits except 5 (RDRF)	;	check RDRF
			CMP		R2,#0						;Iterates if RDRF if clear			;}
			BEQ		GetWhile
			LDRB	R0,[R1,#UART0_D_OFFSET]											;Read from data register

			POP		{R1-R3}
			BX		LR
			ENDP
;***************************************************************
PutChar		PROC	{R1-R13}
;***************************************************************
; Displays the single character from R0 to the terminal screen.
; Input: R0: Character to transmit
; Output: None
; Local Variables:
;	R1: Memory address of UART0
;	R2: Value of UART_S1
;	R3: TDRE Mask
;***************************************************************
			PUSH	{R1-R3}

			LDR		R1,=UART0_BASE	
			MOVS	R3,#TDRE_MASK
PutWhile	LDRB	R2,[R1,#UART0_S1_OFFSET]     ;Pulls S1 every iteration			;while (TDRE != 1) {
			ANDS	R2,R2,R3					;Clears all bit except 7 (TDRE)		;	check TDRE;
			BEQ		PutWhile															;}
			STRB	R0,[R1,#UART0_D_OFFSET]											;Write data to UART data register
			
			POP		{R1-R3}
			BX		LR
			ENDP
;****************************************************************
DIVU		PROC	{R2-R14}
;****************************************************************
; Computes unsigned integer division
; Inputs
;	  R0 : divisor (number by which to divide)
;     R1 : dividend (number to divide)
; Outputs
;	  R0 : quotient
;	  R1 : remainder
;	  C ASPR Flag : 0 for valid result, 1 for invalid result
; Locals
;	  R3 : Temp value of quotient
;	  R4 : Holds PSR value
;	  R5 : Holds bit mask
;****************************************************************
			PUSH	{R3-R5}

			CMP		R0, #0				;if (divisor == 0) {
			BEQ		DivBy0				

			CMP		R1, #0				;} else if (dividend == 0) {
			BEQ		Div0				
										;} else {
			CMP		R1, R0				;	while (Dividend >= Divisor){
			BLO		EndEarly			;		
			MOVS	R3, #0
while		SUBS	R1,R1,R0			;		Dividend = Dividend - Divisor
			ADDS    R3,#1				;		Quotient = Quotient + 1
			CMP		R1, R0				;	}
			BHS		while				;}
			MOVS    R0, R3				;
			B		EndWhile							
										
DivBy0		MRS		R4, APSR			;Set C
			LDR		R5,=APSR_C_MASK	
			ORRS	R4,R4,R5
			MSR		APSR, R4
			B		EndSubR
			
Div0		MOVS	R0,#0				;Set outputs to 0
			MOVS	R1,#0
			MRS		R4, APSR			;Set Z
			LDR		R5,=APSR_Z_MASK
			ORRS	R4,R4,R5
			MSR		APSR, R4
			B		EndWhile
			
EndEarly	MOVS	R0,#0				;Set quotient (R0) to 0
			B		EndWhile
			
EndWhile	MRS		R4, APSR			;Clear C
			LDR		R5,=APSR_C_MASK
			BICS	R4,R4,R5
			MSR		APSR, R4
			B		EndSubR
			
EndSubR		POP     {R3-R5}
			BX		LR
			ENDP
;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Vector Table Mapped to Address 0 at Reset
;Linker requires __Vectors to be exported
            AREA    RESET, DATA, READONLY
            EXPORT  __Vectors
            EXPORT  __Vectors_End
            EXPORT  __Vectors_Size
            IMPORT  __initial_sp
            IMPORT  Dummy_Handler
            IMPORT  HardFault_Handler
__Vectors 
                                      ;ARM core vectors
            DCD    __initial_sp       ;00:end of stack
            DCD    Reset_Handler      ;01:reset vector
            DCD    Dummy_Handler      ;02:NMI
            DCD    HardFault_Handler  ;03:hard fault
            DCD    Dummy_Handler      ;04:(reserved)
            DCD    Dummy_Handler      ;05:(reserved)
            DCD    Dummy_Handler      ;06:(reserved)
            DCD    Dummy_Handler      ;07:(reserved)
            DCD    Dummy_Handler      ;08:(reserved)
            DCD    Dummy_Handler      ;09:(reserved)
            DCD    Dummy_Handler      ;10:(reserved)
            DCD    Dummy_Handler      ;11:SVCall (supervisor call)
            DCD    Dummy_Handler      ;12:(reserved)
            DCD    Dummy_Handler      ;13:(reserved)
            DCD    Dummy_Handler      ;14:PendSV (PendableSrvReq)
                                      ;   pendable request 
                                      ;   for system service)
            DCD    Dummy_Handler      ;15:SysTick (system tick timer)
            DCD    Dummy_Handler      ;16:DMA channel 0 transfer 
                                      ;   complete/error
            DCD    Dummy_Handler      ;17:DMA channel 1 transfer
                                      ;   complete/error
            DCD    Dummy_Handler      ;18:DMA channel 2 transfer
                                      ;   complete/error
            DCD    Dummy_Handler      ;19:DMA channel 3 transfer
                                      ;   complete/error
            DCD    Dummy_Handler      ;20:(reserved)
            DCD    Dummy_Handler      ;21:FTFA command complete/
                                      ;   read collision
            DCD    Dummy_Handler      ;22:low-voltage detect;
                                      ;   low-voltage warning
            DCD    Dummy_Handler      ;23:low leakage wakeup
            DCD    Dummy_Handler      ;24:I2C0
            DCD    Dummy_Handler      ;25:(reserved)
            DCD    Dummy_Handler      ;26:SPI0
            DCD    Dummy_Handler      ;27:(reserved)
            DCD    Dummy_Handler      ;28:UART0 (status; error)
            DCD    Dummy_Handler      ;29:(reserved)
            DCD    Dummy_Handler      ;30:(reserved)
            DCD    Dummy_Handler      ;31:ADC0
            DCD    Dummy_Handler      ;32:CMP0
            DCD    Dummy_Handler      ;33:TPM0
            DCD    Dummy_Handler      ;34:TPM1
            DCD    Dummy_Handler      ;35:(reserved)
            DCD    Dummy_Handler      ;36:RTC (alarm)
            DCD    Dummy_Handler      ;37:RTC (seconds)
            DCD    Dummy_Handler      ;38:PIT
            DCD    Dummy_Handler      ;39:(reserved)
            DCD    Dummy_Handler      ;40:(reserved)
            DCD    Dummy_Handler      ;41:DAC0
            DCD    Dummy_Handler      ;42:TSI0
            DCD    Dummy_Handler      ;43:MCG
            DCD    Dummy_Handler      ;44:LPTMR0
            DCD    Dummy_Handler      ;45:(reserved)
            DCD    Dummy_Handler      ;46:PORTA
            DCD    Dummy_Handler      ;47:PORTB
__Vectors_End
__Vectors_Size  EQU     __Vectors_End - __Vectors
            ALIGN
;****************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<
prompt1		DCB			"Enter the first 128-bit hex number: \0"
prompt2		DCB			"Enter 128 bit hex number to add:    \0"
promptInvalid	DCB		"Invalid number--try again:          \0"
hexprompt	DCB			"0x\0"
sumprompt	DCB			"Sum:                                0x\0"
promptOverflow	DCB		"                                    0xOVERFLOW\0"
;>>>>>   end constants here <<<<<
            ALIGN
;****************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<
String1		SPACE	MAX_STRING
inputString1 SPACE	4 * N 
inputString2 SPACE	4 * N
inputCopy	SPACE	4 * N
sum			SPACE	4 * N
;>>>>>   end variables here <<<<<
            ALIGN
            END