/*
 *  RODDCext/src/RODBC.h by M. Lapsley, B. D. Ripley and Mateusz Zoltak
 *    Copyright (C) 1999-2014
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  A copy of the GNU General Public License is available at
 *  http://www.r-project.org/Licenses/
 *
 *  This file and "RODBC.c" are parts of RODBC package by M. Lapsley and B. D.
 *  Ripley needed to complile RODBCext.c
 */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdlib.h>

#ifdef WIN32
#include <windows.h>
#undef ERROR
/* enough of the internals of graphapp objects to allow us to find the
   handle of the RGui main window */
typedef struct objinfo {
  int  kind, refcount;
  HANDLE  handle;
} *window;
__declspec(dllimport) window RConsole;
#else
#include <unistd.h>
#endif

#include <string.h>
#include <limits.h> /* for INT_MAX */

#define MAX_CHANNELS 1000
#include <sql.h>
#include <sqlext.h>

#include <R.h>
#include <Rdefines.h>

#ifdef ENABLE_NLS
#include <libintl.h>
#define _(String) dgettext ("RODBC", String)
#else
#define _(String) (String)
#endif
#define my_min(a,b) ((a < b)?a:b)

#define COLMAX 256
#define DOUBLE_COL_SIZE 15
#ifndef SQL_NO_DATA
#define SQL_NO_DATA_FOUND /* for iODBC */
#endif
#define NCOLS thisHandle->nColumns /* save some column space for typing*/
#define NROWS thisHandle->nRows

/* For 64-bit ODBC, Microsoft did some redefining, see
   http://msdn.microsoft.com/library/default.asp?url=/library/en-us/odbc/htm/dasdkodbcoverview_64bit.asp
   Some people think this corresponded to increasing the version to 3.52,
   but none of MinGW, unixODBC or iodbc seem to have done so.

   Given that, how do we know what these mean?

   MinGW[-w64]: if _WIN64 is defined, they are 64-bit, otherwise (unsigned) long.

   unixODBC: if SIZEOF_LONG == 8 && BUILD_REAL_64_BIT_MODE they are
   64-bit.  In applications, SIZEOF_LONG == 8 is determined by
   if defined(__alpha) || defined(__sparcv9) || defined(__LP64__)
   We have no way of knowing if BUILD_REAL_64_BIT_MODE was defined,
   but Debian which does define also modifies the headers.

   iobdc: if _WIN64 is defined, they are 64-bit
   Otherwise, they are (unsigned) long.
 */
#ifndef HAVE_SQLLEN
#define SQLLEN SQLINTEGER
#endif

#ifndef HAVE_SQLULEN
#define SQLULEN SQLUINTEGER
#endif


/* Note that currently we will allocate large buffers for long char
   types whatever rows_at_time is. */
#define MAX_ROWS_FETCH  1024

typedef struct cols {
    SQLCHAR  ColName[256];
    SQLSMALLINT  NameLength;
    SQLSMALLINT  DataType;
    SQLULEN  ColSize;
    SQLSMALLINT  DecimalDigits;
    SQLSMALLINT  Nullable;
    char  *pData;
    int datalen;
    SQLDOUBLE  RData [MAX_ROWS_FETCH];
    SQLREAL  R4Data[MAX_ROWS_FETCH];
    SQLINTEGER  IData [MAX_ROWS_FETCH];
    SQLSMALLINT  I2Data[MAX_ROWS_FETCH];
    SQLLEN  IndPtr[MAX_ROWS_FETCH];
} COLUMNS;

typedef struct mess {
    SQLCHAR  *message;
    struct mess  *next;
} SQLMSG;

typedef struct rodbcHandle {
    SQLHDBC  hDbc;         /* connection handle */
    SQLHSTMT  hStmt;        /* statement handle */
    SQLLEN  nRows;        /* number of rows and columns in result set */
    SQLSMALLINT  nColumns;
    int    channel;      /* as stored on the R-level object */
    int         id;           /* ditto */
    int         useNRows;     /* value of believeNRows */
    /* entries used to bind data for result sets and updates */
    COLUMNS  *ColData;  /* this will be allocated as an array */
    int    nAllocated;     /* how many cols were allocated */
    SQLUINTEGER  rowsFetched;  /* use to indicate the number of rows fetched */
    SQLUINTEGER  rowArraySize;  /* use to indicate the number of rows we expect back */
    SQLUINTEGER  rowsUsed;  /* for when we fetch more than we need */
    SQLMSG  *msglist;  /* root of linked list of messages */
    SEXP        extPtr;    /* address of external pointer for this 
           channel, so we can clear it */
} RODBCHandle, *pRODBCHandle;

char* mystrdup(const char *s);
void errlistAppend(pRODBCHandle thisHandle, const char *string);
void errorFree(SQLMSG *node);
void geterr(pRODBCHandle thisHandle);
void clearresults(pRODBCHandle thisHandle);
void cachenbind_free(pRODBCHandle thisHandle);
int cachenbind(pRODBCHandle thisHandle, int nRows);
SEXP RODBCcheckchannel(SEXP chan, SEXP id);
