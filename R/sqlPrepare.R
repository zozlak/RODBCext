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

#' @title Prepares a query for execution
#' @useDynLib RODBCext
#' @description
#' Prepares a query for execution.
#' 
#' If data given, executes query using \link{sqlExecute}.
#' 
#' Optionally fetches results using \link{sqlFetch}.
#' @details
#' Return value depends on the combination of parameters:
#' \itemize{
#'   \item if there were errors during query preparation (or execution or fetching results)
#'     return value depends on errors parameter - if errors=TRUE error is thrown,
#'     otherwise -1 will be returned
#'   \item if fetch=FALSE or data were not provided and there were no errors during query preparation 
#'     (and execution), invisible(1) will be returned
#'   \item if fetch=TRUE and data were provided and there were no errors during query preparation,
#'     execution and fetching results, data.frame with results will be returned
#' }
#' @param channel ODBC connection obtained by odbcConnect()
#' @param query query string
#' @param data data to pass to sqlExecute (as data.frame)
#' @param fetch whether to automatically fetch results (if data provided)
#' @param errors whether to display errors
#' @param ... parameters to pass to \link{sqlFetchMore} (if data provided and fetch=TRUE)
#' @return see datails
#' @export
#' @examples
#' \dontrun{
#'   conn = odbcConnect('MyDataSource')
#'   
#'   # prepare, execute and fetch results separatly
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?")
#'   sqlExecute(conn, 'myValue')
#'   sqlFetchMore(conn)
#'   
#'   # prepare and execute at one time, fetch results separately
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?", 'myValue')
#'   sqlFetch(conn)
#'   
#'   # prepare, execute and fetch at one time
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?", 'myValue', TRUE)
#'   
#'   # prepare, execute and fetch at one time, pass additional parameters to sqlFetch()
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?", 'myValue', TRUE, stringsAsFactors=FALSE)
#' }
sqlPrepare <- function(channel, query, data = NULL, fetch=FALSE, errors = TRUE, ...)
{
  if(!odbcValidChannel(channel))
    stop("first argument is not an open RODBC channel")
  if(missing(query))
    stop("missing argument 'query'")
  
  if(nchar(enc <- attr(channel, "encoding")))
    query <- iconv(query, to=enc)
  
  stat <- .Call("RODBCPrepare", attr(channel, "handle_ptr"), as.character(query))
  if(stat == -1L) {
    if(errors) stop(paste0(odbcGetErrMsg(channel), collapse='\n'))
    else return(stat)
  }
  if(is.null(data)){
    return(invisible(stat))
  }
  stat <- sqlExecute(channel, data, errors=errors)
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