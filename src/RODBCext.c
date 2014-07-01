/*
 *  copyright (C) 2014 Mateusz Zoltak
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
 */

#include "RODBC.h"

/* macro to check and handle ODBC API calls results */
#define SQL_RESULT_CHECK(res, handle, errorMessage, ret) \
  if(res != SQL_SUCCESS && res != SQL_SUCCESS_WITH_INFO){ \
    geterr(handle); \
    errlistAppend(handle, errorMessage); \
    FreeHandleResources(handle); \
    return ret; \
  }

/**
 * Free all handle resources except errors list.
 * 
 * @param thisHandle handle to ODBC connection
 */
void FreeHandleResources(pRODBCHandle thisHandle){
  if(thisHandle->hStmt) {
    (void)SQLFreeStmt(thisHandle->hStmt, SQL_CLOSE);
    (void)SQLFreeHandle(SQL_HANDLE_STMT, thisHandle->hStmt);
    thisHandle->hStmt = NULL;
  }
  cachenbind_free(thisHandle);
}

/**
 * Copy parameter values from R data structures to cols data structure
 * taking care of NA, too long character strings, etc.
 *
 * It takes the whole data with both rows and cols and separate row parameter 
 * because it would be a waste of time to rewrite data.frame-like structure 
 * (with columns as list) to a single list of columns for every row before
 * each call to CopyParameters.
 *
 * @param columns pointer to a table of cols structures describing query 
 *   parameters
 * @param data data.frame-like structure with query data (columns refer
 *   to query parameters, rows to query executions)
 * @param row number of row in data to copy values from
 * @param vtest debug level: 0-no debug, other-verbose
 */
void CopyParameters(COLUMNS *columns, SEXP data, int row){
  const char *cData;
  int ncol = LENGTH(data);
  if(ncol == NA_INTEGER){
    return;
  }
  for(int col = 0; col < ncol; col++) {
    COLUMNS *column = &(columns[col]);

    switch(TYPEOF(VECTOR_ELT(data, col))) { 
      case REALSXP:
        column->RData[0] = REAL(VECTOR_ELT(data, col))[row];
        if(ISNAN(column->IData[0])){
          column->IndPtr[0] = SQL_NULL_DATA;
        }else{
          column->IndPtr[0] = SQL_NTS;
        }
        break;
      case INTSXP:
        column->IData[0] = INTEGER(VECTOR_ELT(data, col))[row];
        if(column->IData[0] == NA_INTEGER){
          column->IndPtr[0] = SQL_NULL_DATA;
        }else{
          column->IndPtr[0] = SQL_NTS;
        }
        break;
      default:
        cData = translateChar(STRING_ELT(VECTOR_ELT(data, col), row));
        strncpy(column->pData, cData, column->ColSize);
        column->pData[column->ColSize] = '\0';
        if(strlen(cData) > column->ColSize){
          warning(_("character data '%s' truncated to %d bytes in parameter %d"),
            cData, column->ColSize, col + 1);
        }
        if(STRING_ELT(VECTOR_ELT(data, col), row) == NA_STRING){
            column->IndPtr[0] = SQL_NULL_DATA;
        }else{
            column->IndPtr[0] = SQL_NTS;
        }
        break;
    }
  }
}

/**
 * Fill cols data structure with parameters info and bind
 * query parameters to cols data fields.
 *
 * A query has to be already prepared using SQLPrepare()
 *
 * On error ODBC handle structure resources are cleared and error messages
 * are added to the error list.
 *
 * @param thisHandle ODBC handle structure with already prepared query
 * @param data data.frame-like structure with query data (columns refer
 *   to query parameters, rows to query executions) - used to determine
 *   query params C types
 * @param vtest debug level: 
 *   0-no debug, 
 *   1-verbose, 
 *   2-verbose with no query execution
 * @retval 1 on success, -1 on error
 */
SQLRETURN BindParameters(pRODBCHandle thisHandle, SEXP data){
  SQLRETURN res = 0;
  SQLSMALLINT nparams, col;

  /* Check the number of Query parameters */
  res = SQLNumParams(thisHandle->hStmt, &nparams);
  SQL_RESULT_CHECK(res, thisHandle, _("[RODBCext] Error: SQLNumParams failed"), res);
  if(nparams > 0 && nparams != LENGTH(data)){
  	SQL_RESULT_CHECK(
      SQL_ERROR, 
      thisHandle, 
      _("[RODBCext] Error: Number of parameters in query do not match number of columns in data"), 
      res
    );
  }
  
  cachenbind_free(thisHandle);
  thisHandle->ColData = Calloc(nparams, COLUMNS);
  thisHandle->nAllocated = nparams;

  for(col = 0; col < nparams; col++) {
    COLUMNS *column = &(thisHandle->ColData[col]);
    column->ColName[0] = '\0'; /* We don't know parameter name but we really don't need to */

    res = SQLDescribeParam(thisHandle->hStmt, col + 1, &column->DataType, 
          &column->ColSize, &column->DecimalDigits, &column->Nullable);
    /* ODBC driver does not support SQLDescribeParam - try to use default values and rely on the ODBC casting */
    if(res != SQL_SUCCESS && res != SQL_SUCCESS_WITH_INFO){
      switch(TYPEOF(VECTOR_ELT(data, col))) {
        case REALSXP:
          column->DataType = SQL_DOUBLE;
          column->ColSize = DOUBLE_COL_SIZE;
          break;
        case INTSXP:
          column->DataType = SQL_INTEGER;
          break;
        default:
          column->DataType = SQL_VARCHAR;
          column->ColSize = COLMAX;
          break;
      }
    }

    /* Bind parameter */
    switch(TYPEOF(VECTOR_ELT(data, col))) {
      case REALSXP:
        res = SQLBindParameter(
          thisHandle->hStmt,
          col + 1, SQL_PARAM_INPUT, SQL_C_DOUBLE,
          column->DataType, 
          column->ColSize,
          column->DecimalDigits,
          column->RData,  
          0,              
          column->IndPtr
        );
        break;
      case INTSXP:
        res = SQLBindParameter(
          thisHandle->hStmt,
          col + 1, SQL_PARAM_INPUT, SQL_C_SLONG,
          column->DataType,
          column->ColSize,
          column->DecimalDigits,
          column->IData,
          0,
          column->IndPtr
        );
        break;
      default:
        if(column->pData){
          Free(column->pData);
        }
        column->pData = Calloc(column->ColSize + 1, char);
        res = SQLBindParameter(
          thisHandle->hStmt,
          col + 1, SQL_PARAM_INPUT, SQL_C_CHAR,
          column->DataType,
          column->ColSize,
          column->DecimalDigits,
          column->pData,
          0,
          column->IndPtr
        );
        break;
    }
    SQL_RESULT_CHECK(res, thisHandle, _("[RODBCext] Error: SQLBindParameter failed"), res);
  }
  return 1;
}

/**
 * Check if query was executed
 * 
 * @param chan R ODBC handle
 * @retval 0 if query not executed, 1 if query executed, -1 on error
 */
SEXP RODBCQueryStatus(SEXP chan){
  pRODBCHandle thisHandle = R_ExternalPtrAddr(chan);
  SQLRETURN res = 0;
  SQLINTEGER len;
  SQLCHAR sqlState[6];
  SQLINTEGER nativeError;
  SQLSMALLINT msgLen;

  res = SQLGetStmtAttr(thisHandle->hStmt, SQL_ATTR_ROW_NUMBER, NULL, 0, &len);
  if(res != SQL_SUCCESS && res != SQL_SUCCESS_WITH_INFO){
    /* get the error code */
    res = SQLGetDiagRec(SQL_HANDLE_STMT, thisHandle->hStmt, 1, sqlState, &nativeError, NULL, 0, &msgLen);
    if(res != SQL_SUCCESS && res != SQL_SUCCESS_WITH_INFO){
      return ScalarInteger(-1);
    }
    /* check if it is an INVALID CURSOR STATE error */
    if(strncmp((const char *)sqlState, "24000", 5) == 0){
      return ScalarInteger(0);
    }
    /* check if it is an NOT POSITIONED ON A VALID ROW error */
    if(strncmp((const char *)sqlState, "07005", 5) == 0){
      return ScalarInteger(1);
    }
    warning(_("SQL error code: %s"), sqlState);
    return ScalarInteger(-1);
  }

  return ScalarInteger(1);
}

/**
 * Prepare a query for execution.
 * 
 * @param chan R ODBC handle
 * @param query character string with query
 * @retval 1 on success, -1 on error
 */
SEXP RODBCPrepare(SEXP chan, SEXP query)
{
  pRODBCHandle thisHandle = R_ExternalPtrAddr(chan);
  const char *cquery;
  SQLRETURN res = 0;

  FreeHandleResources(thisHandle);

  res = SQLAllocHandle(SQL_HANDLE_STMT, thisHandle->hDbc, &thisHandle->hStmt);
  SQL_RESULT_CHECK(res, thisHandle, _("[RODBCext] Error: SQLAllocStmt failed"), ScalarInteger(-1));
  
  cquery = translateChar(STRING_ELT(query, 0));
  res = SQLPrepare(thisHandle->hStmt, (SQLCHAR *) cquery,
          strlen(cquery) );
  SQL_RESULT_CHECK(res, thisHandle, _("[RODBCext] Error: SQLPrepare failed"), ScalarInteger(-1));
  
  return ScalarInteger(1);
}

/**
 * Execute already prepared query with data provided in data.frame-like data 
 * structure.
 * 
 * If query fetches data it may be read using sqlFetchMore().
 *
 * @param chan R ODBC handle
 * @param data data.frame-like structure with query data (columns refer
 *   to query parameters, rows to query executions)
 * @param row number of row in data to copy values from
 * @param vtest debug level: 
 *   0-no debug, 
 *   1-verbose, 
 *   2-verbose with no query execution
 * @retval 1 on success, -1 on error
 */
SEXP RODBCExecute(SEXP chan, SEXP data, SEXP nrows)
{
  pRODBCHandle thisHandle = R_ExternalPtrAddr(chan);
  int rows, row, stat = 1;
  SQLRETURN res = 0;

  /* Clear error list */
  errorFree(thisHandle->msglist);
  thisHandle->msglist = NULL;
  
  /* Bind Query parameters  */
  res = BindParameters(thisHandle, data);
  if(res != 1){
    return ScalarInteger(-1);
  }

  if(0 == LENGTH(data)){
    res = SQLExecute(thisHandle->hStmt);
    SQL_RESULT_CHECK(res, thisHandle, _("[RODBCext] Error: SQLExecute failed"), ScalarInteger(-1));
  }
  else{
    rows = LENGTH(VECTOR_ELT(data, 0));
    for(row = 0; row < rows; row++) {
      /* Discard any pending data from previous query executions */
      SQLCloseCursor(thisHandle->hStmt);

      CopyParameters(thisHandle->ColData, data, row);
  
      res = SQLExecute(thisHandle->hStmt);
      SQL_RESULT_CHECK(res, thisHandle, _("[RODBCext] Error: SQLExecute failed"), ScalarInteger(-1));
    }
  }
  
  /* Prepare result for fetching */
  stat = cachenbind(thisHandle, asInteger(nrows));

  return ScalarInteger(stat);
}

/*###########################################################################*/

#include <R_ext/Rdynload.h>

static const R_CallMethodDef CallEntries[] = {
    {"RODBCQueryStatus", (DL_FUNC) &RODBCQueryStatus, 1},
    {"RODBCPrepare", (DL_FUNC) &RODBCPrepare, 2},
    {"RODBCExecute", (DL_FUNC) &RODBCExecute, 3},
    {"RODBCcheckchannel", (DL_FUNC) &RODBCcheckchannel, 2},
    {NULL, NULL, 0}
};

void R_init_RODBC(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
