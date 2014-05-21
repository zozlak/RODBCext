# Copyright (C) 2014 Mateusz Zoltak
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 or 3 of the License
#  (at your option).
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  A copy of the GNU General Public License is available at
#  http://www.r-project.org/Licenses/

#' @title Executes an already prepared query
#' @useDynLib RODBCext
#' @description
#' Executes an already prepared query. You may prepare query using \link{sqlPrepare}.
#' 
#' Optionally fetches results using \link{sqlFetch}.
#' @details
#' Return value depends on the combination of parameters:
#' \itemize{
#'   \item if there were errors during query execution (or fetching results)
#'     return value depends on errors parameter - if errors=TRUE error is thrown,
#'     otherwise -1 will be returned
#'   \item if fetch=FALSE and there were no errors during query execution, invisible(1) will be returned
#'   \item if fetch=TRUE and there were no errors during query execution and fetching results, 
#'     data.frame with results will be returned
#' }
#' @param channel ODBC connection obtained by odbcConnect()
#' @param data data to pass to sqlExecute (as data.frame)
#' @param fetch whether to automatically fetch results (if data provided)
#' @param errors whether to display errors
#' @param rows_at_time number of rows to fetch at one time - see details of \link{sqlQuery}
#' @param ... parameters to pass to \link{sqlFetchMore} (if fetch=TRUE)
#' @return see datails
#' @export
#' @examples
#' \dontrun{
#'   conn = odbcConnect('MyDataSource')
#'   
#'   # prepare, execute and fetch results separatly
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?")
#'   sqlExecute(conn, 'myValue')
#'   sqlFetch(conn)
#'   
#'   # prepare and execute at one time, fetch results separately
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?", 'myValue')
#'   sqlFetchMore(conn)
#'   
#'   # prepare, execute and fetch at one time
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?", 'myValue', TRUE)
#'   
#'   # prepare, execute and fetch at one time, pass additional parameters to sqlFetch()
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?", 'myValue', TRUE, stringsAsFactors=FALSE)
#' }
sqlExecute <- function(channel, data=NULL, fetch=FALSE, errors = TRUE, rows_at_time = attr(channel, "rows_at_time"), ...)
{
  if(!odbcValidChannel(channel))
    stop("first argument is not an open RODBC channel")
  if(is.null(data)){
    data = data.frame()
  }
  data = as.data.frame(data)
  for(k in seq_along(data)){
    if(is.factor(data[, k])){
      data[, k] = levels(data[, k])[data[, k]]
    }
  }
  stat <- .Call(
    "RODBCExecute", 
    attr(channel, "handle_ptr"), 
    data, 
    as.integer(rows_at_time)
  )
  if(stat == -1L) {
    if(errors) stop(paste0(odbcGetErrMsg(channel), collapse='\n'))
    else return(stat)
  }
  
  if(fetch == FALSE){
    return(invisible(stat))    
  }
  stat <- sqlFetchMore(channel, ...)
  if(!is.data.frame(stat)) {
    if(errors) stop(paste0(odbcGetErrMsg(channel), collapse='\n'))
    else return(stat)
  }
  return(stat)
}