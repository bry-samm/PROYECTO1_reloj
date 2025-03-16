;
; Proyecto1_reloj.asm
;
; Created: 3/03/2025 16:51:29
; Author : Bryan Samuel Morales Paredes

; El programa funciona como un reloj en donde por modos se puede seleccionar si se desea ver la hora
; fecha, alarma o modificar alguno de estos 

//============================================================== LABORATORIO 3 ===============================================================
.include "M328PDEF.inc"  
.equ	T2VALOR			= 100
.equ	T1VALOR			= 0x1B1E 
.equ	T0VALOR			= 251
.equ	MODO_CANT		= 9

.def	MODO			= R20
.def	CONTADOR		= R21
.def	ACTION			= R22
.def	ACTION_DIS		= R23

.def	UNI_MIN			= R3
.def	DEC_MIN			= R4
.def	UNI_HORA		= R5
.def	DEC_HORA		= R6

.def	UNI_DIA			= R7
.def	DEC_DIA			= R8
.def	UNI_MES			= R9
.def	DEC_MES			= R10

.def	UNI_MIN_ALARM	= R11
.def	DEC_MIN_ALARM	= R12
.def	UNI_HORA_ALARM	= R13
.def	DEC_HORA_ALARM	= R14


.cseg
.org	0x0000
	JMP	START
	
.org	PCI0addr
	JMP	ISR_BOTON

.org	OVF2addr
	JMP	ISR_TIMER2
	
.org	OVF1addr
	JMP	ISR_TIMER1

.org	OVF0addr
	JMP	ISR_TIMER0
	
//==============================================================================
START:
//Configuraci�n de la pila
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16		// SPL 
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16		// SPH 

//=================================================================================
//Configurar el microcontrolador (MCU)
SETUP:
	CLI					//Deshabilito interrupciones globales

	LDI		R16, 0x00
	STS		UCSR0B, R16			// Desabilito el serial
	
	//Prescaler del oscilador CPU
	LDI		R16, (1 << CLKPCE)	//Habilita la escritura en CLKPR
	STS		CLKPR, R16
	LDI		R16, (1 << CLKPS2)	//Configura prescaler a 16 (16 MHz / 16 = 1 MHz)
	STS		CLKPR, R16

	// Inicializar timer0
	LDI		R16, (1<<CS02) | (1<<CS00)	//Configuraci�n para el prescaler de 1024 (ver datasheet)
	OUT		TCCR0B, R16			// Setear prescaler del TIMER 0 a 1024
	LDI		R16, T0VALOR		//Poner a T0VALOR previamente definido
	OUT		TCNT0, R16			// Cargar valor inicial en TCNT0

	//LDI		R16, (1 << TOV0)
	//OUT		TIFR0, R16			// Limpiar la bandera de desbordamiento

	//Inicializar timer1
	//LDI		R16, 0x00
	//STS		TCCR1A, R16			// Modo normal
	LDI		R16, (1<<CS12) | (1<<CS10)
	STS		TCCR1B, R16

	LDI     R16, LOW(T1VALOR)  // Recarga Timer1
    STS     TCNT1L, R16
    LDI     R16, HIGH(T1VALOR)
    STS     TCNT1H, R16

	//LDI		R16, (1 << TOV1)
	//STS		TIFR1, R16			// Limpiar la bandera de desbordamiento 

	//Inicializar timer2
	LDI		R16, (1<<CS22)		// Configurar prescaler en 256
	STS		TCCR2B, R16			// Setear prescaler del TIMER 2 a 256
	LDI		R16, T2VALOR		// Poner a T2VALOR
	STS		TCNT2, R16			// Cargar valor inicial en TCNT2

	//LDI		R16, (1 << TOV2)
	//STS		TIFR2, R16			// Limpiar el flag de desbordamiento

	//PORTD y PORTC como salida e inicialmente apagado 
	LDI		R16, 0xFF
	OUT		DDRD, R16			//Setear puerto D como salida
	OUT		DDRC, R16
	LDI		R16, 0x00
	OUT		PORTD, R16			//Apagar puerto D
	OUT		PORTC, R16

	//PORTB parcial
	//Como entrada
	CBI		DDRB, PB0
	CBI		DDRB, PB1
	CBI		DDRB, PB2
	SBI		PORTB, PB0
	SBI		PORTB, PB1
	SBI		PORTB, PB2
	//Como salida
	SBI		DDRB, PB3
	SBI		DDRB, PB4
	SBI		DDRB, PB5
	CBI		PORTB, PB3
	CBI		PORTB, PB4
	CBI		PORTB, PB5

	//Configuraci�n del display
	DISPLAY_VAL:	.db		0x7D, 0x48,	0x3E, 0x6E, 0x4B, 0x67, 0x77, 0x4C, 0x7F, 0x6F
	//						 0	    1	  2		3	 4     5	  6     7     8		9

	//Tabla para tener la cantidad de d�as en los meses del a�o 
	TABLA_DIAS:		.db		31, 28 , 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
	//				   		1	2    3	 4   5	 6   7   8	 9   10  11  12

	//Configuraci�n display para mostrar ON/OFF alarma
	ALARMA_LETRA:	.db		0x00, 0x7D, 0x5D, 0x17
	//				   		        O     N     F

	CALL SET_INICIO
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posici�n inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)

//===================== CONFIGURACI�N INTERRUPCIONES =======================
//Para el timer2
	LDI		R16, (1 << TOIE2)
	STS		TIMSK2, R16
//Para el timer1
	LDI		R16, (1 << TOIE1)
	STS		TIMSK1, R16

//Para el timer0
	LDI		R16, (1 << TOIE0)
	STS		TIMSK0, R16

//Para los botones
	LDI		R16, (1 << PCINT0) | (1 << PCINT1) | (1 << PCINT2) //Habilito los pines en espec�fico que causan la interrupci�n 
	STS		PCMSK0, R16
	
	LDI		R16, (1 << PCIE0)	//Habilito las interrupciones en el PORTB
	STS		PCICR, R16

//======================================= DEFINIR Y SETEAR EN 0 ALGUNOS REGISTROS ========================================================
//No usar registro 30 y 31
//No usar R0 y R1

	CLR		MODO				//R18
	CLR		CONTADOR			//R19
	CLR		ACTION				//R20

	CLR		R1
	CLR		R2
	CLR		R3
	CLR		R4
	CLR		R5
	CLR		R6
	CLR		R8
	LDI		R16, 0x01
	MOV		R9, R16
	MOV		R7, R16
	CLR		R10
	CLR		R11	
	CLR		R12
	CLR		R13
	CLR		R14
	LDI		R16, 0x03
	MOV		R15, R16
	LDI		R17, 0x03
	LDI		R18, 0x01
	CLR		R19
	CLR		R20
	CLR		R21
	CLR		R22
	CLR		R23
	CLR		R24
	CLR		R25
	CLR		R26
	CLR		R27
	CLR		R28

	CLR		R16	
	SEI
//============================================================================
MAIN:
	CPI		MODO, 0
	BREQ	HORA_RJMP
	CPI		MODO, 1
	BREQ	FECHA_RJMP
	CPI		MODO, 2
	BREQ	CONF_MIN_RJMP
	CPI		MODO, 3
	BREQ	CONF_HORA_RJMP
	CPI		MODO, 4
	BREQ	CONF_MES_RJMP
	CPI		MODO, 5
	BREQ	CONF_DIA_RJMP
	CPI		MODO, 6
	BREQ	CONF_ALARMA_MIN_RJMP
	CPI		MODO, 7
	BREQ	CONF_ALARMA_HORA_RJMP
	CPI		MODO, 8
	BREQ	ON_OFF_RJMP
	RJMP	MAIN

HORA_RJMP:
	RJMP	HORA
FECHA_RJMP:
	RJMP	FECHA
CONF_MIN_RJMP:
	RJMP	CONF_MIN
CONF_HORA_RJMP:
	RJMP	CONF_HORA
CONF_DIA_RJMP:
	RJMP	CONF_DIA
CONF_MES_RJMP:
	RJMP	CONF_MES
CONF_ALARMA_MIN_RJMP:
	RJMP	CONF_ALARMA_MIN
CONF_ALARMA_HORA_RJMP:
	RJMP	CONF_ALARMA_HORA
ON_OFF_RJMP:
	RJMP	ON_OFF
//==================================================== RUTINAS DEL MAIN ======================================================================
HORA:
	LDI		ACTION_DIS, 0x01
	CBI		PORTB, PB3			// LEDS que muestran el modo 000
	CBI		PORTB, PB4
	CBI		PORTB, PB5
	//Habilitar interrupciones del timer1
	LDI		R16, (1 << TOIE1)
	STS		TIMSK1, R16

	CALL	SONAR_ALARMA

	RJMP	MAIN
//---------------------------------------------------------------------------------------------------------------
FECHA:
	LDI		ACTION_DIS, 0x02
	SBI		PORTB, PB3			// Leds	que muestran el modo 001
	CBI		PORTB, PB4
	CBI		PORTB, PB5
	//Habilitar interrupciones del timer1
	LDI		R16, (1 << TOIE1)
	STS		TIMSK1, R16

	CALL	SONAR_ALARMA

	RJMP	MAIN
//--------------------------------------------------------------------------------------------------------------
CONF_MIN:
	//Parar interrupci�n del timer1
	CLR		R16
	STS		TIMSK1, R16

	LDI		ACTION_DIS, 0x01
	CBI		PORTB, PB3			// LEDS que muestran el modo 010
	SBI		PORTB, PB4
	CBI		PORTB, PB5

    CPI     ACTION, 0x01       ; Compara ACTION con 0x01
    BREQ    DO_SUMA            ; Si ACTION == 0x01, salta a DO_SUMA
    CPI     ACTION, 0x02       ; Compara ACTION con 0x02
    BREQ    DO_RESTA           ; Si ACTION == 0x02, salta a DO_RESTA
    CLR     ACTION             ; Limpia ACTION (opcional, dependiendo de tu l�gica)
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_SUMA:
    CALL    SUMA_MIN               ; Llama a la subrutina SUMA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_RESTA:
    CALL    RESTA_MIN              ; Llama a la subrutina RESTA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle
//-----------------------------------------------------------------------------------------------------------
CONF_HORA:
	//Parar interrupci�n del timer1
	CLR		R16
	STS		TIMSK1, R16

	LDI		ACTION_DIS, 0x01
	SBI		PORTB, PB3			// LEDS que muestran el modo 011
	SBI		PORTB, PB4
	CBI		PORTB, PB5
	
	CPI     ACTION, 0x01       ; Compara ACTION con 0x01
    BREQ    DO_SUMA_HORA           ; Si ACTION == 0x01, salta a DO_SUMA
    CPI     ACTION, 0x02       ; Compara ACTION con 0x02
    BREQ    DO_RESTA_HORA           ; Si ACTION == 0x02, salta a DO_RESTA
    CLR     ACTION             ; Limpia ACTION (opcional, dependiendo de tu l�gica)
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_SUMA_HORA:
    CALL    SUMA_HORA               ; Llama a la subrutina SUMA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_RESTA_HORA:
    CALL    RESTA_HORA              ; Llama a la subrutina RESTA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle
//-------------------------------------------------------------------------------------------------------------
CONF_DIA:
	LDI		ACTION_DIS, 0x02
	CBI		PORTB, PB3			// LEDS que muestran el modo 100
	CBI		PORTB, PB4
	SBI		PORTB, PB5

	//Parar interrupci�n del timer1
	CLR		R16
	STS		TIMSK1, R16
	
	CPI     ACTION, 0x01       ; Compara ACTION con 0x01
    BREQ    DO_SUMA_DIA           ; Si ACTION == 0x01, salta a DO_SUMA
    CPI     ACTION, 0x02       ; Compara ACTION con 0x02
    BREQ    DO_RESTA_DIA           ; Si ACTION == 0x02, salta a DO_RESTA
    CLR     ACTION             ; Limpia ACTION (opcional, dependiendo de tu l�gica)
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_SUMA_DIA:
    CALL    SUMA_DIA               ; Llama a la subrutina SUMA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_RESTA_DIA:
    CALL    RESTA_DIA              ; Llama a la subrutina RESTA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle

//--------------------------------------------------------------------------------------------------------------
CONF_MES:
	LDI		ACTION_DIS, 0x02
	SBI		PORTB, PB3			// LEDS que muestran el modo 101
	CBI		PORTB, PB4
	SBI		PORTB, PB5

	//Parar interrupci�n del timer1
	CLR		R16
	STS		TIMSK1, R16
	
	CPI     ACTION, 0x01       ; Compara ACTION con 0x01
    BREQ    DO_SUMA_MES           ; Si ACTION == 0x01, salta a DO_SUMA
    CPI     ACTION, 0x02       ; Compara ACTION con 0x02
    BREQ    DO_RESTA_MES           ; Si ACTION == 0x02, salta a DO_RESTA
    CLR     ACTION             ; Limpia ACTION (opcional, dependiendo de tu l�gica)
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_SUMA_MES:
    CALL    SUMA_MES               ; Llama a la subrutina SUMA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_RESTA_MES:
    CALL    RESTA_MES              ; Llama a la subrutina RESTA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle
//-------------------------------------------------------------------------------------------------------------------
CONF_ALARMA_MIN:
	LDI		ACTION_DIS, 0x03
	CBI		PORTB, PB3			// LEDS que muestran el modo 110
	SBI		PORTB, PB4
	SBI		PORTB, PB5


	//Parar interrupci�n del timer1
	CLR		R16
	STS		TIMSK1, R16

    CPI     ACTION, 0x01       ; Compara ACTION con 0x01
    BREQ    DO_SUMA_MIN_ALARMA            ; Si ACTION == 0x01, salta a DO_SUMA
    CPI     ACTION, 0x02       ; Compara ACTION con 0x02
    BREQ    DO_RESTA_MIN_ALARMA           ; Si ACTION == 0x02, salta a DO_RESTA
    CLR     ACTION             ; Limpia ACTION (opcional, dependiendo de tu l�gica)
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_SUMA_MIN_ALARMA:
    CALL    SUMA_MIN_ALARMA               ; Llama a la subrutina SUMA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_RESTA_MIN_ALARMA:
    CALL    RESTA_MIN_ALARMA              ; Llama a la subrutina RESTA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle

//-------------------------------------------------------------------------------------------------------------------
CONF_ALARMA_HORA:
	LDI		ACTION_DIS, 0x03
	SBI		PORTB, PB3			// LEDS que muestran el modo 111
	SBI		PORTB, PB4
	SBI		PORTB, PB5

	//Parar interrupci�n del timer1
	CLR		R16
	STS		TIMSK1, R16

    CPI     ACTION, 0x01       ; Compara ACTION con 0x01
    BREQ    DO_SUMA_HORA_ALARMA            ; Si ACTION == 0x01, salta a DO_SUMA
    CPI     ACTION, 0x02       ; Compara ACTION con 0x02
    BREQ    DO_RESTA_HORA_ALARMA           ; Si ACTION == 0x02, salta a DO_RESTA
    CLR     ACTION             ; Limpia ACTION (opcional, dependiendo de tu l�gica)
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_SUMA_HORA_ALARMA:
    CALL    SUMA_HORA_ALARMA               ; Llama a la subrutina SUMA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_RESTA_HORA_ALARMA:
    CALL    RESTA_HORA_ALARMA              ; Llama a la subrutina RESTA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle

//---------------------------------------------------------------------------------------------------------------------
ON_OFF:
	LDI		ACTION_DIS, 0x04
	
	//Parar interrupci�n del timer1
	CLR		R16
	STS		TIMSK1, R16

    CPI     ACTION, 0x01       ; Compara ACTION con 0x01
    BREQ    DO_ON            ; Si ACTION == 0x01, salta a DO_SUMA
    CPI     ACTION, 0x02       ; Compara ACTION con 0x02
    BREQ    DO_OFF           ; Si ACTION == 0x02, salta a DO_RESTA
    CLR     ACTION             ; Limpia ACTION (opcional, dependiendo de tu l�gica)
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_ON:
	LDI		R19, 0x01			//Activo la bandera de acci�n para que suene la alarma
	CLR		R15					// Coloco el valor correspondiente para que su muestre "nada"
	LDI		R17, 0x02			// Coloco el valor correspondiente para que se muestre "N"
	LDI		R18, 0x01			// Coloco el valor correspondiente para que se muestre "O"
    CALL    SONAR_ALARMA               ; Llama a la subrutina SUMA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle

DO_OFF:
	LDI		R19, 0x00
	LDI		R16, 0x03
	MOV		R15, R16			// Coloco el valor correspondiente para que su muestre "F"
	LDI		R17, 0x03			// Coloco el valor correspondiente para que se muestre "F"
	LDI		R18, 0x01			// Coloco el valor correspondiente para que se muestre "O"
    CALL    SONAR_ALARMA              ; Llama a la subrutina RESTA
    CLR     ACTION             ; Limpia ACTION despu�s de la operaci�n
    RJMP    MAIN               ; Vuelve al inicio del bucle


//========================================================================== RUTINAS NO INTERRUPCI�N ====================================================================================
SET_INICIO:
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posici�n inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)
	RET

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_MIN:
    ; Incrementa las unidades de minutos (R3)
    MOV     R16, R3            ; Carga R3 en R16
    INC     R16                ; Incrementa R16
    CPI     R16, 10            ; Compara R16 con 10
    BRNE    UPDATE_SUM_UNI_MIN_ALARMA ; Si R16 != 10, salta a UPDATE_SUM_UNI_MIN

    ; Si R16 == 10, reinicia las unidades de minutos e incrementa las decenas
    CLR     R16                ; Reinicia R16 a 0
    MOV     R3, R16            ; Guarda 0 en R3 (unidades de minutos)
    MOV     R16, R4            ; Carga R4 en R16
    INC     R16                ; Incrementa R16 (decenas de minutos)
    CPI     R16, 6             ; Compara R16 con 6
    BRNE    UPDATE_SUM_DEC_MIN_ALARMA ; Si R16 != 6, salta a UPDATE_SUM_DEC_MIN

    ; Si R16 == 6, reinicia las decenas de minutos
    CLR     R16                ; Reinicia R16 a 0
    MOV     R4, R16            ; Guarda 0 en R4 (decenas de minutos)
    RET                        ; Retorna de la subrutina

UPDATE_SUM_UNI_MIN_ALARMA:
    ; Actualiza las unidades de minutos
    MOV     R3, R16            ; Guarda R16 en R3
    RET                        ; Retorna de la subrutina

UPDATE_SUM_DEC_MIN_ALARMA:
    ; Actualiza las decenas de minutos
    MOV     R4, R16            ; Guarda R16 en R4
    RET                        ; Retorna de la subrutina
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_MIN:
    ; Resta las unidades de minutos (R3)
    MOV     R16, R3            ; Carga R3 en R16
    DEC     R16                ; Decrementa R16
    CPI     R16, 0xFF          ; Compara R16 con -1 (0xFF en complemento a 2)
    BRNE    UPDATE_RES_UNI_MIN  ; Si R16 != -1, salta a UPDATE_RES_UNI_MIN

    ; Si R16 == -1, ajusta las unidades a 9 y decrementa las decenas
    LDI     R16, 9             ; Carga 9 en R16 (unidades de minutos)
    MOV     R3, R16            ; Guarda 9 en R3
    MOV     R16, R4            ; Carga R4 en R16
    DEC     R16                ; Decrementa R16 (decenas de minutos)
    CPI     R16, 0xFF          ; Compara R16 con -1 (0xFF en complemento a 2)
    BRNE    UPDATE_RES_DEC_MIN  ; Si R16 != -1, salta a UPDATE_RES_DEC_MIN

    ; Si R16 == -1, ajusta las decenas a 5 (para volver a 59)
    LDI     R16, 5             ; Carga 5 en R16 (decenas de minutos)
    MOV     R4, R16            ; Guarda 5 en R4
    RET                        ; Retorna de la subrutina

UPDATE_RES_UNI_MIN:
    ; Actualiza las unidades de minutos
    MOV     R3, R16            ; Guarda R16 en R3
    RET                        ; Retorna de la subrutina

UPDATE_RES_DEC_MIN:
    ; Actualiza las decenas de minutos
    MOV     R4, R16            ; Guarda R16 en R4
    RET                        ; Retorna de la subrutina
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_HORA:
    ; Incrementa las unidades de hora (R5)
	MOV		R16, R6
	CPI		R16, 2
	BRNE	CONTINUAR_NORMAL_HORA

	MOV		R16, R5
	INC		R16
	CPI		R16, 4
	BRNE	UPDATE_SUM_UNI_HORA
	RJMP	RESET_HORAS

CONTINUAR_NORMAL_HORA:
    MOV     R16, R5            ; Carga R5 en R16
    INC     R16                ; Incrementa R16
    CPI     R16, 10            ; Compara R16 con 10
    BRNE    UPDATE_SUM_UNI_HORA ; Si R16 != 10, salta a UPDATE_SUM_UNI_MIN

    ; Si R16 == 10, reinicia las unidades de minutos e incrementa las decenas
    CLR     R16                ; Reinicia R16 a 0
    MOV     R5, R16            ; Guarda 0 en R3 (unidades de minutos)
    MOV     R16, R6            ; Carga R4 en R16
    INC     R16                ; Incrementa R16 (decenas de minutos)
    CPI     R16, 6             ; Compara R16 con 6
    BRNE    UPDATE_SUM_DEC_HORA ; Si R16 != 6, salta a UPDATE_SUM_DEC_MIN

RESET_HORAS:
    ; Si R16 == 6, reinicia las decenas de minutos
    CLR     R16                ; Reinicia R16 a 0
    MOV     R6, R16            ; Guarda 0 en R4 (decenas de minutos)
	MOV		R5, R16
    RET                        ; Retorna de la subrutina

UPDATE_SUM_UNI_HORA:
    ; Actualiza las unidades de minutos
    MOV     R5, R16            ; Guarda R16 en R3
    RET                        ; Retorna de la subrutina

UPDATE_SUM_DEC_HORA:
    ; Actualiza las decenas de minutos
    MOV     R6 , R16            ; Guarda R16 en R4
    RET                        ; Retorna de la subrutina
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_HORA:
    ; Resta las unidades de minutos (R3)
    MOV     R16, R5            ; Carga R3 en R16
    DEC     R16                ; Decrementa R16
    CPI     R16, 0xFF          ; Compara R16 con -1 (0xFF en complemento a 2)
    BRNE    UPDATE_RES_UNI_HORA  ; Si R16 != -1, salta a UPDATE_RES_UNI_MIN

    ; Si R16 == -1, ajusta las unidades a 9 y decrementa las decenas
    LDI     R16, 9             ; Carga 9 en R16 (unidades de minutos)
    MOV     R5, R16            ; Guarda 9 en R3
    MOV     R16, R6           ; Carga R4 en R16
    DEC     R16                ; Decrementa R16 (decenas de minutos)
    CPI     R16, 0xFF          ; Compara R16 con -1 (0xFF en complemento a 2)
    BRNE    UPDATE_RES_DEC_HORA  ; Si R16 != -1, salta a UPDATE_RES_DEC_MIN

RESET_HORA_DEC:
    ; Si R16 == -1, ajusta las decenas a 5 (para volver a 59)
    LDI     R16, 2             ; Carga 5 en R16 (decenas de minutos)
    MOV     R6, R16            ; Guarda 5 en R4
	LDI		R16, 3
	MOV		R5, R16
    RET                        ; Retorna de la subrutina

UPDATE_RES_UNI_HORA:
    ; Actualiza las unidades de minutos
    MOV     R5, R16            ; Guarda R16 en R3
    RET                        ; Retorna de la subrutina

UPDATE_RES_DEC_HORA:
    ; Actualiza las decenas de minutos
    MOV     R6, R16            ; Guarda R16 en R4
    RET                        ; Retorna de la subrutina
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_DIA:
    ; Calcular el d�a actual en formato decimal (R24 = R8 * 10 + R7)
    MOV     R24, R8
    MOV     R27, R24
    LSL     R24          ; R24 = R8 * 2
    LSL     R27          ; R27 = R8 * 2
    LSL     R27          ; R27 = R8 * 4
    LSL     R27          ; R27 = R8 * 8
    ADD     R24, R27     ; R24 = (R8 * 2) + (R8 * 8) = R8 * 10
    ADD     R24, R7      ; R24 = R8 * 10 + R7

    ; Obtener el n�mero de d�as del mes actual (en decimal)
    LDI     ZL, LOW(TABLA_DIAS << 1)  ; Cargar la direcci�n baja de la tabla
    LDI     ZH, HIGH(TABLA_DIAS << 1) ; Cargar la direcci�n alta de la tabla
    MOV     R16, R25                  ; Cargar el mes actual en R16
    DEC     R16                       ; Ajustar el �ndice (R16 = R25 - 1)
    ADD     ZL, R16                   ; Sumar el �ndice del mes a la direcci�n
    ADC     ZH, R1                    ; A�adir el acarreo si es necesario
    LPM     R27, Z                    ; Cargar el n�mero de d�as del mes en R27 (decimal)

    ; Comparar el d�a actual con el n�mero m�ximo de d�as del mes
    CP      R24, R27                  ; Comparar R24 con R27
    BRLO    CONTINUAR_SUMA_DIA        ; Si R24 < R27, continuar sumando

    ; Si R24 >= R27, reiniciar el d�a a 1
    LDI     R16, 1                    ; Cargar 1 en R16
    MOV     R7, R16                   ; Guardar 1 en R7 (unidades del d�a)
    CLR     R8                        ; Limpiar R8 (decenas del d�a)
    RET                               ; Retornar de la subrutina

CONTINUAR_SUMA_DIA:
    ; Incrementar las unidades del d�a
    MOV     R16, R7                   ; Cargar R7 en R16
    INC     R16                       ; Incrementar R16
    CPI     R16, 10                   ; Comparar R16 con 10
    BRNE    UPDATE_SUM_UNI_DIA        ; Si no es 10, actualizar las unidades

    ; Si las unidades son 10, reiniciar a 0 e incrementar las decenas
    CLR     R16                       ; Limpiar R16
    MOV     R7, R16                   ; Guardar 0 en R7 (unidades del d�a)
    INC     R8                        ; Incrementar R8 (decenas del d�a)
    RET                               ; Retornar de la subrutina

UPDATE_SUM_UNI_DIA:
    ; Actualizar las unidades del d�a
    MOV     R7, R16                   ; Guardar R16 en R7
    RET                               ; Retornar de la subrutina

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_DIA:
    ; Calcular el d�a actual en formato decimal (R24 = R8 * 10 + R7)
    MOV     R24, R8
    MOV     R27, R24
    LSL     R24          ; R24 = R8 * 2
    LSL     R27          ; R27 = R8 * 2
    LSL     R27          ; R27 = R8 * 4
    LSL     R27          ; R27 = R8 * 8
    ADD     R24, R27     ; R24 = (R8 * 2) + (R8 * 8) = R8 * 10
    ADD     R24, R7      ; R24 = R8 * 10 + R7

    ; Obtener el n�mero de d�as del mes actual (en decimal)
    LDI     ZL, LOW(TABLA_DIAS << 1)  ; Cargar la direcci�n baja de la tabla
    LDI     ZH, HIGH(TABLA_DIAS << 1) ; Cargar la direcci�n alta de la tabla
    MOV     R16, R25                  ; Cargar el mes actual en R16
    DEC     R16                       ; Ajustar el �ndice (R16 = R25 - 1)
    ADD     ZL, R16                   ; Sumar el �ndice del mes a la direcci�n
    ADC     ZH, R1                    ; A�adir el acarreo si es necesario
    LPM     R27, Z                    ; Cargar el n�mero de d�as del mes en R27 (decimal)

    ; Verificar si el d�a actual es 1 (R7 = 1 y R8 = 0)
    MOV     R16, R7                   ; Cargar R7 en R16
    CPI     R16, 1                    ; Comparar R16 con 1
    BRNE    DECREMENTAR_NORMAL        ; Si R16 no es 1, decrementar normalmente
    MOV     R16, R8                   ; Cargar R8 en R16
    CPI     R16, 0                    ; Comparar R16 con 0
    BRNE    DECREMENTAR_NORMAL        ; Si R16 no es 0, decrementar normalmente

    ; Si el d�a actual es 1, ajustar al �ltimo d�a del mes actual (en decimal)
    MOV     R24, R27                  ; Cargar el n�mero de d�as del mes en R24
    RJMP    CONVERTIR_A_BCD           ; Convertir a BCD y actualizar R7 y R8

DECREMENTAR_NORMAL:
    ; Decrementar las unidades del d�a
    MOV     R16, R7                   ; Cargar R7 en R16
    DEC     R16                       ; Decrementar R16
    MOV     R7, R16                   ; Guardar R16 en R7
    CPI     R16, 0xFF                 ; Verificar si R16 es -1 (0xFF)
    BRNE    EXIT_RESTA_DIA            ; Si no es -1, salir

    ; Si las unidades son -1, ajustar las decenas y las unidades
    MOV     R16, R8                   ; Cargar R8 en R16
    DEC     R16                       ; Decrementar R16
    MOV     R8, R16                   ; Guardar R16 en R8
    CPI     R16, 0xFF                 ; Verificar si R16 es -1 (0xFF)
    BRNE    AJUSTAR_DECENAS           ; Si no es -1, ajustar las decenas

    ; Si las decenas son -1, ajustar al �ltimo d�a del mes actual (en decimal)
    MOV     R24, R27                  ; Cargar el n�mero de d�as del mes en R24
    RJMP    CONVERTIR_A_BCD           ; Convertir a BCD y actualizar R7 y R8

AJUSTAR_DECENAS:
    ; Ajustar las decenas
    LDI     R16, 9                    ; Cargar 9 en R16
    MOV     R7, R16                   ; Guardar R16 en R7
    RET                               ; Retornar de la subrutina

CONVERTIR_A_BCD:
    ; Convertir el valor decimal de la tabla a BCD
    MOV     R16, R24                  ; Cargar el n�mero de d�as en R16
    CLR     R17                       ; Limpiar R17 para las decenas
CONVERTIR_LOOP:
    CPI     R16, 10                   ; Comparar con 10
    BRLO    CONVERSION_COMPLETA       ; Si es menor que 10, la conversi�n est� completa
    INC     R17                       ; Incrementar las decenas
    SUBI    R16, 10                   ; Restar 10 a las unidades
    RJMP    CONVERTIR_LOOP            ; Repetir hasta que R16 < 10
CONVERSION_COMPLETA:
    ; R17 = decenas, R16 = unidades (en BCD)
    MOV     R7, R16                   ; Guardar las unidades del d�a en R7
    MOV     R8, R17                   ; Guardar las decenas del d�a en R8
    RET                               ; Retornar de la subrutina

EXIT_RESTA_DIA:
    RET                               ; Retornar de la subrutina

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_MES:
	LDI		R16, 0x01
	MOV		R7, R16
	CLR		R8

    MOV     R16, R10
    CPI     R16, 1
    BRNE    CONT_NORMAL_MES	
    MOV     R16, R9
    INC     R16
    CPI     R16, 3
    BRNE    UPDATE_UNI_MES
    RJMP    RESET_MES

CONT_NORMAL_MES:
    MOV     R16, R9
    INC     R16
    CPI     R16, 10
    BRNE    UPDATE_UNI_MES
    CLR     R16

UPDATE_UNI_MES:
    MOV     R9, R16
    CPI     R16, 0
    BRNE    ACTUALIZAR_SUM_MES
    MOV     R16, R10
    INC     R16
    CPI     R16, 2
    BRNE    UPDATE_DEC_MES
    CLR     R16

UPDATE_DEC_MES:
    MOV     R10, R16
    RJMP    ACTUALIZAR_SUM_MES

RESET_MES:
    LDI     R16, 0x01
    MOV     R9, R16
    CLR     R16
    MOV     R10, R16

ACTUALIZAR_SUM_MES:
    MOV     R16, R25
    INC     R16
    CPI     R16, 13
    BRNE    EXIT_SUM_MES
    LDI     R16, 0x01

EXIT_SUM_MES:
    MOV     R25, R16
    RET

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_MES:
	LDI		R16, 0x01
	MOV		R7, R16
	CLR		R8

    ; Decrementar el mes
    MOV     R16, R25                  ; Cargar el mes actual en R16
    DEC     R16                       ; Decrementar R16
    CPI     R16, 0                    ; Verificar si el mes es 0
    BRNE    UPDATE_MES                ; Si no es 0, actualizar el mes

    ; Si el mes es 0, ajustar a 12
    LDI     R16, 12                   ; Cargar 12 en R16
    MOV     R25, R16                  ; Guardar 12 en R25 (mes actual)

UPDATE_MES:
    ; Actualizar el mes
    MOV     R25, R16                  ; Guardar R16 en R25

    ; Convertir el mes a unidades (R9) y decenas (R10)
    CLR     R10                       ; Limpiar R10 (decenas)
    CLR     R9                        ; Limpiar R9 (unidades)

CONVERTIR_MES_A_BCD:
    CPI     R16, 10                   ; Comparar con 10
    BRLO    CONVERSION_COMPLETA_MES   ; Si es menor que 10, la conversi�n est� completa
    INC     R10                       ; Incrementar las decenas
    SUBI    R16, 10                   ; Restar 10 a las unidades
    RJMP    CONVERTIR_MES_A_BCD       ; Repetir hasta que R16 < 10

CONVERSION_COMPLETA_MES:
    ; Guardar las unidades en R9
    MOV     R9, R16                   ; Guardar R16 en R9 (unidades)

    ; Verificar si el mes es 12
    CPI     R25, 12                   ; Comparar R25 con 12
    BRNE    EXIT_RESTA_MES            ; Si no es 12, salir

    ; Si el mes es 12, ajustar R10 y R9
    LDI     R16, 1                    ; Cargar 1 en R16 (decenas)
    MOV     R10, R16                  ; Guardar R16 en R10
    LDI     R16, 2                    ; Cargar 2 en R16 (unidades)
    MOV     R9, R16                   ; Guardar R16 en R9

EXIT_RESTA_MES:
    RET                               ; Retornar de la subrutina
/*
RESTA_MES:
    ; Decrementar el mes
    MOV     R16, R25                  ; Cargar el mes actual en R16
    DEC     R16                       ; Decrementar R16
    CPI     R16, 0                    ; Verificar si el mes es 0
    BRNE    UPDATE_MES                ; Si no es 0, actualizar el mes

    ; Si el mes es 0, ajustar a 12
    LDI     R16, 12                   ; Cargar 12 en R16
    MOV     R25, R16                  ; Guardar 12 en R25 (mes actual)

UPDATE_MES:
    ; Actualizar el mes
    MOV     R25, R16                  ; Guardar R16 en R25

    ; Convertir el mes a unidades (R9) y decenas (R10)
    CLR     R10                       ; Limpiar R10 (decenas)
    CLR     R9                        ; Limpiar R9 (unidades)

CONVERTIR_MES_A_BCD:
    CPI     R16, 10                   ; Comparar con 10
    BRLO    CONVERSION_COMPLETA_MES       ; Si es menor que 10, la conversi�n est� completa
    INC     R10                       ; Incrementar las decenas
    SUBI    R16, 10                   ; Restar 10 a las unidades
    RJMP    CONVERTIR_MES_A_BCD       ; Repetir hasta que R16 < 10

CONVERSION_COMPLETA_MES:
    ; Guardar las unidades en R9
    MOV     R9, R16                   ; Guardar R16 en R9 (unidades)
    RET                               ; Retornar de la subrutina*/

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_MIN_ALARMA:
    ; Incrementa las unidades de minutos (R3)
    MOV     R16, R11            ; Carga R3 en R16
    INC     R16                ; Incrementa R16
    CPI     R16, 10            ; Compara R16 con 10
    BRNE    UPDATE_SUM_UNI_MIN ; Si R16 != 10, salta a UPDATE_SUM_UNI_MIN

    ; Si R16 == 10, reinicia las unidades de minutos e incrementa las decenas
    CLR     R16                ; Reinicia R16 a 0
    MOV     R11, R16            ; Guarda 0 en R3 (unidades de minutos)
    MOV     R16, R12            ; Carga R4 en R16
    INC     R16                ; Incrementa R16 (decenas de minutos)
    CPI     R16, 6             ; Compara R16 con 6
    BRNE    UPDATE_SUM_DEC_MIN ; Si R16 != 6, salta a UPDATE_SUM_DEC_MIN

    ; Si R16 == 6, reinicia las decenas de minutos
    CLR     R16                ; Reinicia R16 a 0
    MOV     R12, R16            ; Guarda 0 en R4 (decenas de minutos)
    RET                        ; Retorna de la subrutina

UPDATE_SUM_UNI_MIN:
    ; Actualiza las unidades de minutos
    MOV     R11, R16            ; Guarda R16 en R3
    RET                        ; Retorna de la subrutina

UPDATE_SUM_DEC_MIN:
    ; Actualiza las decenas de minutos
    MOV     R12, R16            ; Guarda R16 en R4
    RET                        ; Retorna de la subrutina
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_MIN_ALARMA:
    ; Resta las unidades de minutos (R3)
    MOV     R16, R11            ; Carga R3 en R16
    DEC     R16                ; Decrementa R16
    CPI     R16, 0xFF          ; Compara R16 con -1 (0xFF en complemento a 2)
    BRNE    UPDATE_RES_UNI_MIN_ALARMA  ; Si R16 != -1, salta a UPDATE_RES_UNI_MIN

    ; Si R16 == -1, ajusta las unidades a 9 y decrementa las decenas
    LDI     R16, 9             ; Carga 9 en R16 (unidades de minutos)
    MOV     R11, R16            ; Guarda 9 en R3
    MOV     R16, R12            ; Carga R4 en R16
    DEC     R16                ; Decrementa R16 (decenas de minutos)
    CPI     R16, 0xFF          ; Compara R16 con -1 (0xFF en complemento a 2)
    BRNE    UPDATE_RES_DEC_MIN_ALARMA  ; Si R16 != -1, salta a UPDATE_RES_DEC_MIN

    ; Si R16 == -1, ajusta las decenas a 5 (para volver a 59)
    LDI     R16, 5             ; Carga 5 en R16 (decenas de minutos)
    MOV     R12, R16            ; Guarda 5 en R4
    RET                        ; Retorna de la subrutina

UPDATE_RES_UNI_MIN_ALARMA:
    ; Actualiza las unidades de minutos
    MOV     R11, R16            ; Guarda R16 en R3
    RET                        ; Retorna de la subrutina

UPDATE_RES_DEC_MIN_ALARMA:
    ; Actualiza las decenas de minutos
    MOV     R12, R16            ; Guarda R16 en R4
    RET                        ; Retorna de la subrutina
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_HORA_ALARMA:
    ; Incrementa las unidades de hora (R5)
	MOV		R16, R14
	CPI		R16, 2
	BRNE	CONTINUAR_NORMAL_HORA_ALARMA

	MOV		R16, R13
	INC		R16
	CPI		R16, 4
	BRNE	UPDATE_SUM_UNI_HORA_ALARMA
	RJMP	RESET_HORAS_ALARMA

CONTINUAR_NORMAL_HORA_ALARMA:
    MOV     R16, R13            ; Carga R5 en R16
    INC     R16                ; Incrementa R16
    CPI     R16, 10            ; Compara R16 con 10
    BRNE    UPDATE_SUM_UNI_HORA_ALARMA ; Si R16 != 10, salta a UPDATE_SUM_UNI_MIN

    ; Si R16 == 10, reinicia las unidades de minutos e incrementa las decenas
    CLR     R16                ; Reinicia R16 a 0
    MOV     R13, R16            ; Guarda 0 en R3 (unidades de minutos)
    MOV     R16, R14            ; Carga R4 en R16
    INC     R16                ; Incrementa R16 (decenas de minutos)
    CPI     R16, 6             ; Compara R16 con 6
    BRNE    UPDATE_SUM_DEC_HORA_ALARMA ; Si R16 != 6, salta a UPDATE_SUM_DEC_MIN

RESET_HORAS_ALARMA:
    ; Si R16 == 6, reinicia las decenas de minutos
    CLR     R16                ; Reinicia R16 a 0
    MOV     R14, R16            ; Guarda 0 en R4 (decenas de minutos)
	MOV		R13, R16
    RET                        ; Retorna de la subrutina

UPDATE_SUM_UNI_HORA_ALARMA:
    ; Actualiza las unidades de minutos
    MOV     R13, R16            ; Guarda R16 en R3
    RET                        ; Retorna de la subrutina

UPDATE_SUM_DEC_HORA_ALARMA:
    ; Actualiza las decenas de minutos
    MOV     R14 , R16            ; Guarda R16 en R4
    RET                        ; Retorna de la subrutina
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_HORA_ALARMA:
    ; Resta las unidades de minutos (R3)
    MOV     R16, R13            ; Carga R3 en R16
    DEC     R16                ; Decrementa R16
    CPI     R16, 0xFF          ; Compara R16 con -1 (0xFF en complemento a 2)
    BRNE    UPDATE_RES_UNI_HORA_ALARMA  ; Si R16 != -1, salta a UPDATE_RES_UNI_MIN

    ; Si R16 == -1, ajusta las unidades a 9 y decrementa las decenas
    LDI     R16, 9             ; Carga 9 en R16 (unidades de minutos)
    MOV     R13, R16            ; Guarda 9 en R3
    MOV     R16, R14           ; Carga R4 en R16
    DEC     R16                ; Decrementa R16 (decenas de minutos)
    CPI     R16, 0xFF          ; Compara R16 con -1 (0xFF en complemento a 2)
    BRNE    UPDATE_RES_DEC_HORA_ALARMA  ; Si R16 != -1, salta a UPDATE_RES_DEC_MIN

RESET_HORA_DEC_ALARMA:
    ; Si R16 == -1, ajusta las decenas a 5 (para volver a 59)
    LDI     R16, 2             ; Carga 5 en R16 (decenas de minutos)
    MOV     R14, R16            ; Guarda 5 en R4
	LDI		R16, 3
	MOV		R13, R16
    RET                        ; Retorna de la subrutina

UPDATE_RES_UNI_HORA_ALARMA:
    ; Actualiza las unidades de minutos
    MOV     R13, R16            ; Guarda R16 en R3
    RET                        ; Retorna de la subrutina

UPDATE_RES_DEC_HORA_ALARMA:
    ; Actualiza las decenas de minutos
    MOV     R14, R16            ; Guarda R16 en R4
    RET                        ; Retorna de la subrutina
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SONAR_ALARMA:
	CPI		R19, 0x01
	BRNE	NO_SONAR
	CP		R3, R11
	BRNE	NO_SONAR
	CP		R4, R12
	BRNE	NO_SONAR
	CP		R5, R13
	BRNE	NO_SONAR
	CP		R6, R14
	BRNE	NO_SONAR
	SBI		PORTC, PC4
	RJMP	EXIT_ALARMA
NO_SONAR:
	CBI		PORTC, PC4
EXIT_ALARMA:
	RET
//================================================== RUTINAS DE INTERRUPCI�N =====================================================================
ISR_BOTON:
    PUSH	R16
    IN		R16, SREG
    PUSH	R16

	SBIS	PINB, PB2			// Verifica si se presion� el bot�n de modo
	INC		MODO
	LDI		R16, MODO_CANT
	CP		MODO, R16			// Verifica si ya se sobrepas� la cantidad de modos
	BRNE	CONTINUAR_BOTON		
	CLR		MODO

CONTINUAR_BOTON:				//Verifica que modo debe de ejecutarse
	CPI		MODO, 0
	BREQ	MODO0_ISR
	CPI		MODO, 1
	BREQ	MODO1_ISR
	CPI		MODO, 2
	BREQ	MODO2_ISR
	CPI		MODO, 3
	BREQ	MODO3_ISR
	CPI		MODO, 4
	BREQ	MODO4_ISR
	CPI		MODO, 5
	BREQ	MODO5_ISR
	CPI		MODO, 6
	BREQ	MODO6_ISR
	CPI		MODO, 7
	BREQ	MODO7_ISR
	CPI		MODO, 8
	BREQ	MODO8_ISR
//Comienza verificaci�n y ejecuci�n de modos
MODO0_ISR:
	RJMP	EXIT_MODO_ISR
MODO1_ISR:
	RJMP	EXIT_MODO_ISR
MODO2_ISR:
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
	RJMP	EXIT_MODO_ISR
MODO3_ISR:
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
	RJMP	EXIT_MODO_ISR
MODO4_ISR:
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
	RJMP	EXIT_MODO_ISR
MODO5_ISR:
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
	RJMP	EXIT_MODO_ISR
MODO6_ISR:
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
	RJMP	EXIT_MODO_ISR
MODO7_ISR:
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
	RJMP	EXIT_MODO_ISR
MODO8_ISR:
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
	RJMP	EXIT_MODO_ISR
EXIT_MODO_ISR:
    POP		R16
    OUT		SREG, R16
    POP		R16
    RETI
//.......................................................................................................................
ISR_TIMER0:
	PUSH	R16
	IN		R16,  SREG
	PUSH	R16

	LDI		R16, T0VALOR		//Cargar a R16 el valor de T0VALOR definido al inicio
	OUT		TCNT0, R16			// Cargar valor inicial en TCNT0

	INC		R2
	MOV		R16, R2
	CPI		R16, 0x01
	BREQ	DISPLAY1
	CPI		R16, 0x02
	BREQ	DISPLAY2
	CPI		R16, 0x03
	BREQ	DISPLAY3_RJMP
	CPI		R16, 0x04
	BREQ	DISPLAY4_RJMP

DISPLAY3_RJMP:
	RJMP	DISPLAY3
DISPLAY4_RJMP:
	RJMP	DISPLAY4
//++++++++++++++++++++++++++++++++
DISPLAY1:
	CBI		PORTC, PC0
	CBI		PORTC, PC1
	CBI		PORTC, PC2

	OUT		PORTD, R1
//Verificar el modo actual para mostrar hora o fecha
	CPI		ACTION_DIS, 0x01
	BREQ	DISPLAY1_HORA
	CPI		ACTION_DIS, 0x02
	BREQ	DISPLAY1_FECHA
	CPI		ACTION_DIS, 0x03
	BREQ	DISPLAY1_ALARMA
	CPI		ACTION_DIS, 0x04
	BREQ	DISPLAY1_ALARMA_ON_OFF
DISPLAY1_HORA:
	MOV		R16, R3
	RJMP	FLUJO_DISPLAY1
DISPLAY1_FECHA:
	MOV		R16, R7
	RJMP	FLUJO_DISPLAY1
DISPLAY1_ALARMA:
	MOV		R16, R11

FLUJO_DISPLAY1:
	//MOV		R16, R3
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posici�n inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC3
	OUT		PORTD, R16
	RJMP	FIN_TMR0
DISPLAY1_ALARMA_ON_OFF:
	MOV		R16, R15
	LDI		ZL, LOW(ALARMA_LETRA <<1)	//Coloca el direccionador indirecto en la posici�n inicial
	LDI		ZH, HIGH(ALARMA_LETRA <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC3
	OUT		PORTD, R16
	RJMP	FIN_TMR0

//+++++++++++++++++++++++++++++++++++++++++++++++++++
DISPLAY2:
	CBI		PORTC, PC0
	CBI		PORTC, PC1
	CBI		PORTC, PC3

	OUT		PORTD, R1
//Verificar el modo actual para mostrar hora o fecha
	CPI		ACTION_DIS, 0x01
	BREQ	DISPLAY2_HORA
	CPI		ACTION_DIS, 0x02
	BREQ	DISPLAY2_FECHA
	CPI		ACTION_DIS, 0x03
	BREQ	DISPLAY2_ALARMA
	CPI		ACTION_DIS, 0x04
	BREQ	DISPLAY2_ALARMA_ON_OFF
DISPLAY2_HORA:
	MOV		R16, R4
	RJMP	FLUJO_DISPLAY2
DISPLAY2_FECHA:
	MOV		R16, R8
	RJMP	FLUJO_DISPLAY2
DISPLAY2_ALARMA:
	MOV		R16, R12

FLUJO_DISPLAY2:
	//MOV		R16, R4
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posici�n inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC2
	OUT		PORTD, R16

	RJMP	FIN_TMR0
DISPLAY2_ALARMA_ON_OFF:
	MOV		R16, R17
	LDI		ZL, LOW(ALARMA_LETRA <<1)	//Coloca el direccionador indirecto en la posici�n inicial
	LDI		ZH, HIGH(ALARMA_LETRA <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC2
	OUT		PORTD, R16
	RJMP	FIN_TMR0
//+++++++++++++++++++++++++++++++++++++++++++++++
DISPLAY3:
	CBI		PORTC, PC0
	CBI		PORTC, PC2
	CBI		PORTC, PC3
    OUT     PORTD, R1

//Verificar el modo actual para mostrar hora o fecha
	CPI		ACTION_DIS, 0x01
	BREQ	DISPLAY3_HORA
	CPI		ACTION_DIS, 0x02
	BREQ	DISPLAY3_FECHA
	CPI		ACTION_DIS, 0x03
	BREQ	DISPLAY3_ALARMA
	CPI		ACTION_DIS, 0x04
	BREQ	DISPLAY3_ALARMA_ON_OFF
DISPLAY3_HORA:
	MOV		R16, R5
	RJMP	FLUJO_DISPLAY3
DISPLAY3_FECHA:
	MOV		R16, R9
	RJMP	FLUJO_DISPLAY3
DISPLAY3_ALARMA:
	MOV		R16, R13

FLUJO_DISPLAY3:
    //MOV     R16, R5						// Cargar unidades de hora
    LDI     ZL, LOW(DISPLAY_VAL <<1)
    LDI     ZH, HIGH(DISPLAY_VAL <<1)
    ADD     ZL, R16
    ADC     ZH, R1
    LPM     R16, Z
	SBI     PORTC, PC1
    OUT     PORTD, R16
    RJMP    FIN_TMR0

DISPLAY3_ALARMA_ON_OFF:
	MOV		R16, R18
	LDI		ZL, LOW(ALARMA_LETRA <<1)	//Coloca el direccionador indirecto en la posici�n inicial
	LDI		ZH, HIGH(ALARMA_LETRA <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC1
	OUT		PORTD, R16
	RJMP	FIN_TMR0
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DISPLAY4:
	CBI		PORTC, PC1
	CBI		PORTC, PC2
	CBI		PORTC, PC3

    OUT     PORTD, R1
//Verificar el modo actual para mostrar hora o fecha
	CPI		ACTION_DIS, 0x01
	BREQ	DISPLAY4_HORA
	CPI		ACTION_DIS, 0x02
	BREQ	DISPLAY4_FECHA
	CPI		ACTION_DIS, 0x03
	BREQ	DISPLAY4_ALARMA
	CPI		ACTION_DIS, 0x04
	BREQ	DISPLAY4_ALARMA_ON_OFF
DISPLAY4_HORA:
	MOV		R16, R6
	RJMP	FLUJO_DISPLAY4
DISPLAY4_FECHA:
	MOV		R16, R10
	RJMP	FLUJO_DISPLAY4
DISPLAY4_ALARMA:
	MOV		R16, R14

FLUJO_DISPLAY4:
   // MOV     R16, R6						// Cargar decenas de hora
    LDI     ZL, LOW(DISPLAY_VAL <<1)
    LDI     ZH, HIGH(DISPLAY_VAL <<1)
    ADD     ZL, R16
    ADC     ZH, R1
    LPM     R16, Z
	SBI     PORTC, PC0
    OUT     PORTD, R16

    RJMP    FIN_TMR0
DISPLAY4_ALARMA_ON_OFF:
	MOV		R16, R1
	LDI		ZL, LOW(ALARMA_LETRA <<1)	//Coloca el direccionador indirecto en la posici�n inicial
	LDI		ZH, HIGH(ALARMA_LETRA <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC0
	OUT		PORTD, R16
	RJMP	FIN_TMR0
//++++++++++++++++++++++++++++++++++++++++++++++++++++
FIN_TMR0:
	MOV		R16, R2
	CPI		R16, 0x04
	BRNE	RESET_END_ISR
	CLR		R16
	MOV		R2, R16

RESET_END_ISR:
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI
//...........................................................................................................
ISR_TIMER1:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16

    LDI     R16, LOW(T1VALOR)  // Recarga Timer1
    STS     TCNT1L, R16
    LDI     R16, HIGH(T1VALOR)
    STS     TCNT1H, R16

    // Incrementar minutos (unidades)
    MOV     R16, R3            // Mover unidades de minutos a R16
    INC     R16                // Incrementar unidades de minutos
    CPI     R16, 10            // Comparar si unidades de minutos llegan a 10
    BRNE    UPDATE_UNI_MIN     // Si no, actualizar R3 y salir
    CLR     R16                // Si s�, resetear unidades de minutos

UPDATE_UNI_MIN:
    MOV     R3, R16            // Actualizar R3 con el nuevo valor

    // Verificar si se debe incrementar decenas de minutos
    CPI     R16, 0             // Si unidades de minutos no son 0, no incrementar decenas
    BRNE    SALIR_ISR_1	   // Salir de la interrupci�n
	RJMP	CONTINUAR_UNI_MIN
SALIR_ISR_1:
	RJMP	EXIT_TMR1_ISR
CONTINUAR_UNI_MIN:
    // Incrementar minutos (decenas)
    MOV     R16, R4			   // Mover decenas de minutos a R16
    INC     R16                // Incrementar decenas de minutos
    CPI     R16, 6             // Comparar si decenas de minutos llegan a 6
    BRNE    UPDATE_DEC_MIN     // Si no, actualizar R4 y salir
    CLR     R16                // Si s�, resetear decenas de minutos

UPDATE_DEC_MIN:
    MOV     R4, R16            // Actualizar R4 con el nuevo valor

    // Verificar si se debe incrementar horas
    CPI     R16, 0             // Si decenas de minutos no son 0, no incrementar horas
    BRNE    SALIR_ISR_2		// Salir de la interrupci�n
	RJMP	CONTINUAR_DEC_MIN
SALIR_ISR_2:
	RJMP	EXIT_TMR1_ISR
CONTINUAR_DEC_MIN:
    // Incrementar horas (unidades)
	MOV		R16, R6				// Mover el valor de R6 (decena hora) a R16
	CPI		R16, 2				//Comparar si es 2 y as� unidad de hora no cuente hasta 9
	BRNE	CONT_NORMAL			// Si no es igual continuar contando normal de 0 a 9
	MOV		R16, R5				// Si si, mover R5 (unidad hora) a R16
	INC		R16					// Incrementar R16
	CPI		R16, 4				// Comparar si es igual a 4
	BRNE	UPDATE_UNI_HORA		// Si no es igual saltar a actualizar unidad hora
	RJMP	RESET_TOTAL			// Si es igual, resetear el contador debido a que lleg� a 23:59
	
CONT_NORMAL:	
    MOV     R16, R5            // Mover unidades de horas a R16
    INC     R16                // Incrementar unidades de horas
    CPI     R16, 10            // Si unidades de horas llegan a 10
    BRNE    UPDATE_UNI_HORA    // Si no, actualizar R5 y salir
    CLR     R16                // Si s�, resetear unidades de horas

UPDATE_UNI_HORA:
    MOV     R5, R16            // Actualizar R5 con el nuevo valor

    // Verificar si se debe incrementar decenas de horas
    CPI     R16, 0             // Si unidades de horas no son 0, no incrementar decenas
    BRNE    SALIR_ISR_3
	RJMP	CONTINUAR_UNI_HORA
SALIR_ISR_3:
	RJMP	EXIT_TMR1_ISR
CONTINUAR_UNI_HORA:
   // Incrementar horas (decenas)
	MOV     R16, R6            // Mover decenas de horas a R16
	CPI		R16, 2				// Comparar si es igual a 2
	BRNE	CONTINUAR_DEC_HORA	// Si no es igual ir a actualizar decena hora

RESET_TOTAL:
	CLR		R6					// Reiniciar R6 (decena hora)
	CLR		R5					// Reiniciar R5 (unidad hora)
	CLR		R16					// Reiniciar registro de prop�sito general
	RJMP	NUEVO_DIA		// Salir de la interrupci�n

CONTINUAR_DEC_HORA:
	INC		R16					// Incrementar R16
	MOV		R6, R16				
	RJMP	EXIT_TMR1_ISR

NUEVO_DIA:
    ; Calcular el d�a actual en formato decimal (R24 = R8 * 10 + R7)
    MOV     R24, R8
    MOV     R27, R24
    LSL     R24          ; R24 = R8 * 2
    LSL     R27          ; R27 = R8 * 2
    LSL     R27          ; R27 = R8 * 4
    LSL     R27          ; R27 = R8 * 8
    ADD     R24, R27     ; R24 = (R8 * 2) + (R8 * 8) = R8 * 10
    ADD     R24, R7      ; R24 = R8 * 10 + R7

    ; Obtener el n�mero de d�as del mes actual (en decimal)
    LDI     ZL, LOW(TABLA_DIAS << 1)  ; Cargar la direcci�n baja de la tabla
    LDI     ZH, HIGH(TABLA_DIAS << 1) ; Cargar la direcci�n alta de la tabla
    MOV     R16, R25                  ; Cargar el mes actual en R16
    DEC     R16                       ; Ajustar el �ndice (R16 = R25 - 1)
    ADD     ZL, R16                   ; Sumar el �ndice del mes a la direcci�n
    ADC     ZH, R1                    ; A�adir el acarreo si es necesario
    LPM     R27, Z                    ; Cargar el n�mero de d�as del mes en R27 (decimal)

    ; Comparar el d�a actual con el n�mero m�ximo de d�as del mes
    CP      R24, R27                  ; Comparar R24 con R27
    BRLO    CONTINUAR_SUMA_DIA_ISR    ; Si R24 < R27, continuar sumando

    ; Si R24 >= R27, reiniciar el d�a a 1 y sumar un mes
    LDI     R16, 1                    ; Cargar 1 en R16
    MOV     R7, R16                   ; Guardar 1 en R7 (unidades del d�a)
    CLR     R8                        ; Limpiar R8 (decenas del d�a)

    ; Verificar si el mes es 12 (diciembre)
    MOV     R16, R25                  ; Cargar el mes actual en R16
    CPI     R16, 12                   ; Comparar R16 con 12
    BRNE    SUMA_MES_ISR              ; Si no es 12, sumar un mes

    ; Si el mes es 12, reiniciar a 1 de enero
    LDI     R16, 1                    ; Cargar 1 en R16
    MOV     R25, R16                  ; Reiniciar el mes a 1
    MOV     R9, R16                   ; Reiniciar R9 (unidades del mes) a 1
    CLR     R10                       ; Reiniciar R10 (decenas del mes) a 0
    RJMP    EXIT_TMR1_ISR             ; Salir de la subrutina

SUMA_MES_ISR:
    LDI     R16, 0x01
    MOV     R7, R16
    CLR     R8

    MOV     R16, R10
    CPI     R16, 1
    BRNE    CONT_NORMAL_MES_ISR
    MOV     R16, R9
    INC     R16
    CPI     R16, 3
    BRNE    UPDATE_UNI_MES_ISR
    RJMP    RESET_MES_ISR

CONT_NORMAL_MES_ISR:
    MOV     R16, R9
    INC     R16
    CPI     R16, 10
    BRNE    UPDATE_UNI_MES_ISR
    CLR     R16

UPDATE_UNI_MES_ISR:
    MOV     R9, R16
    CPI     R16, 0
    BRNE    ACTUALIZAR_SUM_MES_ISR
    MOV     R16, R10
    INC     R16
    CPI     R16, 2
    BRNE    UPDATE_DEC_MES_ISR
    CLR     R16

UPDATE_DEC_MES_ISR:
    MOV     R10, R16
    RJMP    ACTUALIZAR_SUM_MES_ISR

RESET_MES_ISR:
    LDI     R16, 0x01
    MOV     R9, R16
    CLR     R16
    MOV     R10, R16

ACTUALIZAR_SUM_MES_ISR:
    MOV     R16, R25
    INC     R16
    CPI     R16, 13
    BRNE    EXIT_SUM_MES_ISR
    LDI     R16, 0x01

EXIT_SUM_MES_ISR:
    MOV     R25, R16
    RJMP    EXIT_TMR1_ISR

CONTINUAR_SUMA_DIA_ISR:
    ; Incrementar las unidades del d�a
    MOV     R16, R7                   ; Cargar R7 en R16
    INC     R16                       ; Incrementar R16
    CPI     R16, 10                   ; Comparar R16 con 10
    BRNE    UPDATE_SUM_UNI_DIA_ISR    ; Si no es 10, actualizar las unidades

    ; Si las unidades son 10, reiniciar a 0 e incrementar las decenas
    CLR     R16                       ; Limpiar R16
    MOV     R7, R16                   ; Guardar 0 en R7 (unidades del d�a)
    INC     R8                        ; Incrementar R8 (decenas del d�a)
    RJMP    EXIT_TMR1_ISR             ; Retornar de la subrutina

UPDATE_SUM_UNI_DIA_ISR:
    ; Actualizar las unidades del d�a
    MOV     R7, R16                   ; Guardar R16 en R7
    RJMP    EXIT_TMR1_ISR             ; Retornar de la subrutina

EXIT_TMR1_ISR:
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI
//.........................................................................................................

ISR_TIMER2:
	PUSH	R16
	IN		R16,  SREG
	PUSH	R16
	/*LDI		R16, T2VALOR		// Cargar definido al inicio T2VALOR
	STS		TCNT2, R16			// Cargar valor inicial en TCNT2
	INC		R26
	CPI		R26, 50
	BRNE	FIN_TMR2
	SBI		PINC, PC5
	CLR		R26
FIN_TMR2:*/
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI
