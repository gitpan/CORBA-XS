/* This file was partialy generated (by C:\Perl\bin\idl2xs_c.pl).*/
/* From file : Calc.idl, 273 octets, Wed May 01 11:26:54 2002
 */

/* START_EDIT */

/* STOP_EDIT */

#include "Calc.h"

/* START_EDIT (Calc) */

/* STOP_EDIT (Calc) */

/*
 * begin of interface Calc
 */

/*============================================================*/
/* ARGSUSED */
CORBA_long
Calc_Add(
	Calc _o,
	CORBA_long val1, // in (fixed length)
	CORBA_long val2, // in (fixed length)
	CORBA_Environment * _ev
)
{
/* START_EDIT (Calc_Add) */
	return val1 + val2;
/* STOP_EDIT (Calc_Add) */
}


/*============================================================*/
/* ARGSUSED */
CORBA_long
Calc_Div(
	Calc _o,
	CORBA_long val1, // in (fixed length)
	CORBA_long val2, // in (fixed length)
	CORBA_Environment * _ev
)
{
	static Calc_DivisionByZero _Calc_DivisionByZero;
/* START_EDIT (Calc_Div) */
	if (0 == val2)
	{
		CORBA_exception_set(_ev, CORBA_USER_EXCEPTION, ex_Calc_DivisionByZero, &_Calc_DivisionByZero);
		return 0;
	}
	else
	{
		return val1 / val2;
	}
/* STOP_EDIT (Calc_Div) */
}


/*============================================================*/
/* ARGSUSED */
CORBA_long
Calc_Mul(
	Calc _o,
	CORBA_long val1, // in (fixed length)
	CORBA_long val2, // in (fixed length)
	CORBA_Environment * _ev
)
{
/* START_EDIT (Calc_Mul) */
	return val1 * val2;
/* STOP_EDIT (Calc_Mul) */
}


/*============================================================*/
/* ARGSUSED */
CORBA_long
Calc_Sub(
	Calc _o,
	CORBA_long val1, // in (fixed length)
	CORBA_long val2, // in (fixed length)
	CORBA_Environment * _ev
)
{
/* START_EDIT (Calc_Sub) */
	return val1 - val2;
/* STOP_EDIT (Calc_Sub) */
}

/*
 * end of interface Calc
 */

/* end of file : skel_Calc.c */
