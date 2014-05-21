/*
 *  RODDCext/src/RODBC.c by M. Lapsley, B. D. Ripley and Mateusz Zoltak
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
 *  This file and "RODBC.h" are parts of RODBC package by M. Lapsley and B. D.
 *  Ripley needed to complile RODBCext.c
 */

#include "RODBC.h"

#define BIND(type, buf, size) \
      retval = SQLBindCol(thisHandle->hStmt, i+1, type,\
        thisHandle->ColData[i].buf, size,\
        thisHandle->ColData[i].IndPtr);\
            break;

/**********************
 * Check for valid channel since invalid
 * will cause segfault on most functions
 */

SEXP RODBCcheckchannel(SEXP chan, SEXP id)
{
    SEXP ptr = getAttrib(chan, install("handle_ptr"));
    pRODBCHandle thisHandle = R_ExternalPtrAddr(ptr);

    return ScalarLogical(thisHandle && TYPEOF(ptr) == EXTPTRSXP &&
  		 thisHandle->channel == asInteger(chan) &&
			 thisHandle->id == asInteger(id));
}

/**********************************************************
 *
 * Some utility routines to build, count, read and free a linked list
 * of diagnostic record messages
 * This is implemented as a linked list against the possibility
 * of using SQLGetDiagRec which returns an unknown number of messages.
 *
 * Don't use while !SQL_NO_DATA 'cause iodbc does not support it
 *****************************************/
char* mystrdup(const char *s)
{
    char *s2;
    s2 = Calloc(strlen(s) + 1, char);
    strcpy(s2, s);
    return s2;
}

void errlistAppend(pRODBCHandle thisHandle, const char *string)
{
    SQLMSG *root;
    SQLCHAR *buffer;

  /* do this strdup so that all the message chain can be freed*/
  if((buffer = (SQLCHAR *) mystrdup(string)) == NULL) {
    REprintf("RODBC.c: Memory Allocation failure for message string\n");
    return;
  }
  root = thisHandle->msglist;

  if(root) {
    while(root->message) {
      if(root->next)
        root = root->next;
      else 
        break;
    }
    root->next = Calloc(1, SQLMSG);
    root = root->next;
  } 
  else {
    root = thisHandle->msglist = Calloc(1, SQLMSG);
  }
  root->next = NULL;
  root->message = buffer;
}

void errorFree(SQLMSG *node)
{
    if(!node) return;
    if(node->next)
  errorFree(node->next);
    if(node) {
  Free(node->message);
  Free(node);
  node = NULL;
    }
}

void geterr(pRODBCHandle thisHandle)
{
  SQLCHAR sqlstate[6], msg[SQL_MAX_MESSAGE_LENGTH];
  SQLINTEGER NativeError;
  SQLSMALLINT i = 1, MsgLen;
  char message[SQL_MAX_MESSAGE_LENGTH + 16];
  SQLRETURN retval;

  while(1) {  /* exit via break */
    retval =  SQLGetDiagRec(SQL_HANDLE_STMT,
              thisHandle->hStmt, i++,
              sqlstate, &NativeError, msg, sizeof(msg),
              &MsgLen);

    if(retval != SQL_SUCCESS && retval != SQL_SUCCESS_WITH_INFO)
      break;
    sprintf(message,"%s %d %s", sqlstate, (int)NativeError, msg);
    errlistAppend(thisHandle, message);
  }
}

/********************************************
 *
 *  Common column cache and bind for query-like routines
 *      This is used to bind the columns for all queries that
 *      produce a result set, which is uses by RODBCFetchRows.
 *
 ********************************************/

/* called before SQL queries (indirect and direct) */
void clearresults(pRODBCHandle thisHandle)
{
  if(thisHandle->hStmt) {
    (void)SQLFreeStmt(thisHandle->hStmt, SQL_CLOSE);
    (void)SQLFreeHandle(SQL_HANDLE_STMT, thisHandle->hStmt);
    thisHandle->hStmt = NULL;
  }
  errorFree(thisHandle->msglist);
  thisHandle->msglist = NULL;
}

void cachenbind_free(pRODBCHandle thisHandle)
{
  SQLUSMALLINT i;
  if(thisHandle->ColData) {
    for (i = 0; i < thisHandle->nAllocated; i++){
      if(thisHandle->ColData[i].pData)
        Free(thisHandle->ColData[i].pData);
    }
    Free(thisHandle->ColData);
    thisHandle->ColData = NULL; /* to be sure */
  }   
}

/* returns 1 for success, -1 for failure */
int cachenbind(pRODBCHandle thisHandle, int nRows)
{
  SQLUSMALLINT i;
  SQLRETURN retval;

  /* Now cache the number of columns, rows */
  retval = SQLNumResultCols(thisHandle->hStmt, &NCOLS);
  if( retval != SQL_SUCCESS && retval != SQL_SUCCESS_WITH_INFO ) {
    /* assume this is not an error but that no rows found */
    NROWS = 0;
    return 1 ;
  }
  retval = SQLRowCount(thisHandle->hStmt, &NROWS);
  if( retval != SQL_SUCCESS && retval != SQL_SUCCESS_WITH_INFO ) {
    geterr(thisHandle);
    errlistAppend(thisHandle, _("[RODBC] ERROR: SQLRowCount failed"));
    goto error;
  }
  /* Allocate storage for ColData array,
     first freeing what was there before */
  cachenbind_free(thisHandle);
  thisHandle->ColData = Calloc(NCOLS, COLUMNS);
  /* this allocates Data as zero */
  thisHandle->nAllocated = NCOLS;

  /* attempt to set the row array size */
  thisHandle->rowArraySize = my_min(nRows, MAX_ROWS_FETCH);

  /* passing unsigned integer values via casts is a bad idea.
     But here double casting works because long and a pointer
     are the same size on all relevant platforms (since
     Win64 is not relevant). */
  retval = SQLSetStmtAttr(thisHandle->hStmt, SQL_ATTR_ROW_ARRAY_SIZE,
           (SQLPOINTER) (unsigned long) thisHandle->rowArraySize, 0 );
  if (retval != SQL_SUCCESS)
    thisHandle->rowArraySize = 1;
  
  thisHandle->rowsUsed = 0;

  /* Set pointer to report number of rows fetched */

  if (thisHandle->rowArraySize != 1) {
    retval = SQLSetStmtAttr(thisHandle->hStmt,
             SQL_ATTR_ROWS_FETCHED_PTR,
             &thisHandle->rowsFetched, 0);
    if (retval != SQL_SUCCESS) {
      thisHandle->rowArraySize = 1;
      SQLSetStmtAttr(thisHandle->hStmt, SQL_ATTR_ROW_ARRAY_SIZE,
         (SQLPOINTER) 1, 0 );
    }
  }
  nRows = thisHandle->rowArraySize;

  /* step through each col and cache metadata: cols are numbered from 1! */
  for (i = 0; i < NCOLS; i++) {
    retval = SQLDescribeCol(thisHandle->hStmt, i+1,
        thisHandle->ColData[i].ColName, 256,
        &thisHandle->ColData[i].NameLength,
        &thisHandle->ColData[i].DataType,
        &thisHandle->ColData[i].ColSize,
        &thisHandle->ColData[i].DecimalDigits,
        &thisHandle->ColData[i].Nullable);
    if( retval != SQL_SUCCESS && retval != SQL_SUCCESS_WITH_INFO ) {
      geterr(thisHandle);
      errlistAppend(thisHandle, 
        _("[RODBC] ERROR: SQLDescribeCol failed"));
      goto error;
    }
    /* now bind the col to its data buffer */
    /* MSDN say the BufferLength is ignored for fixed-size
       types, but this is not so for UnixODBC */
    /* We could add other types here, in particular
       SQL_C_USHORT
       SQL_C_ULONG (map to double)
       SQL_C_BIT
       SQL_C_WCHAR (map to UTF-8)
     */
    switch(thisHandle->ColData[i].DataType) {
      case SQL_DOUBLE:
        BIND(SQL_C_DOUBLE, RData, sizeof(double));
      case SQL_REAL:
        BIND(SQL_C_FLOAT, R4Data, sizeof(float));
      case SQL_INTEGER:
        BIND(SQL_C_SLONG, IData, sizeof(int));
      case SQL_SMALLINT:
        BIND(SQL_C_SSHORT, I2Data, sizeof(short));
      case SQL_BINARY:
      case SQL_VARBINARY:
      case SQL_LONGVARBINARY:
      {
        /* should really use SQLCHAR (unsigned) */
        SQLLEN datalen = thisHandle->ColData[i].ColSize;
        thisHandle->ColData[i].datalen = datalen;
        thisHandle->ColData[i].pData =
          Calloc(nRows * (datalen + 1), char);
        BIND(SQL_C_BINARY, pData, datalen);
      }
      default:
      {
        SQLLEN datalen = thisHandle->ColData[i].ColSize;
        if (datalen <= 0 || datalen < COLMAX)
          datalen = COLMAX;
        /* sanity check as the reports are sometimes unreliable */
        if (datalen > 65535)
          datalen = 65535;
        thisHandle->ColData[i].pData =
          Calloc(nRows * (datalen + 1), char);
        thisHandle->ColData[i].datalen = datalen;
        BIND(SQL_C_CHAR, pData, datalen);
      }
    }

    if( retval != SQL_SUCCESS && retval != SQL_SUCCESS_WITH_INFO ) {
      geterr(thisHandle);
      errlistAppend(thisHandle, _("[RODBC] ERROR: SQLBindCol failed"));
      goto error;
    }
  }
  return 1;

error:
  (void)SQLFreeStmt(thisHandle->hStmt, SQL_CLOSE);
  (void)SQLFreeHandle(SQL_HANDLE_STMT, thisHandle->hStmt);
  thisHandle->hStmt = NULL;
  return -1;
}
