/* This file was partialy generated (by C:\Perl\bin\idl2xs_c.pl).*/
/* From file : CalcCplx.idl, 192 octets, Tue May 21 09:33:22 2002
 */

/* START_EDIT */

/* STOP_EDIT */

#include "CalcCplx.h"

/* START_EDIT (CalcCplx) */

/* STOP_EDIT (CalcCplx) */

/*
 * begin of interface CalcCplx
 */

/*============================================================*/
/* ARGSUSED */
Cplx_Complex
CalcCplx_Add(
	CalcCplx _o,
	Cplx_Complex * val1, // in (fixed length)
	Cplx_Complex * val2, // in (fixed length)
	CORBA_Environment * _ev
)
{
/* START_EDIT (CalcCplx_Add) */
	Cplx_Complex _ret;

	_ret.re = val1->re + val2->re;
	_ret.im = val1->im + val2->im;
	return _ret;
/* STOP_EDIT (CalcCplx_Add) */
}


/*============================================================*/
/* ARGSUSED */
Cplx_Complex
CalcCplx_Sub(
	CalcCplx _o,
	Cplx_Complex * val1, // in (fixed length)
	Cplx_Complex * val2, // in (fixed length)
	CORBA_Environment * _ev
)
{
/* START_EDIT (CalcCplx_Sub) */
	Cplx_Complex _ret;

	_ret.re = val1->re - val2->re;
	_ret.im = val1->im - val2->im;
	return _ret;
/* STOP_EDIT (CalcCplx_Sub) */
}

/*
 * end of interface CalcCplx
 */

/* end of file : skel_CalcCplx.c */
