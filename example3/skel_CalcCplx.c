/* This file is partialy generated.*/
/* START_EDIT */

/* STOP_EDIT */

#include "CalcCplx.h"

/*
 * begin of module Cplx
 */
/* START_EDIT (Cplx_CalcCplx) */

/* STOP_EDIT (Cplx_CalcCplx) */

/*
 * begin of interface Cplx_CalcCplx
 */

/*============================================================*/
/* ARGSUSED */
Cplx_Complex
Cplx_CalcCplx_Add(
	Cplx_CalcCplx _o,
	Cplx_Complex * val1, // in (fixed length)
	Cplx_Complex * val2, // in (fixed length)
	CORBA_Environment * _ev
)
{
/* START_EDIT (Cplx_CalcCplx_Add) */
	Cplx_Complex _ret;

	_ret.re = val1->re + val2->re;
	_ret.im = val1->im + val2->im;
	return _ret;
/* STOP_EDIT (Cplx_CalcCplx_Add) */
}


/*============================================================*/
/* ARGSUSED */
Cplx_Complex
Cplx_CalcCplx_Sub(
	Cplx_CalcCplx _o,
	Cplx_Complex * val1, // in (fixed length)
	Cplx_Complex * val2, // in (fixed length)
	CORBA_Environment * _ev
)
{
/* START_EDIT (Cplx_CalcCplx_Sub) */
	Cplx_Complex _ret;

	_ret.re = val1->re - val2->re;
	_ret.im = val1->im - val2->im;
	return _ret;
/* STOP_EDIT (Cplx_CalcCplx_Sub) */
}

/*
 * end of interface Cplx_CalcCplx
 */
/*
 * end of module Cplx
 */

/* end of file : skel_CalcCplx.c0 */
