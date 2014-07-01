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
#' Executes a parameterized query. 
#' 
#' Optionally (fetch=TRUE) fetches results using \link[RODBC]{sqlFetchMore}.
#' 
#' Optionally (query=NULL) uses query already prepared by \link{sqlPrepare}.
#' @details
#' Return value depends on the combination of parameters:
#' \itemize{
#'   \item if there were errors during query preparation or execution or fetching results
#'     return value depends on errors parameter - if errors=TRUE error is thrown,
#'     otherwise -1 will be returned
#'   \item if fetch=FALSE and there were no errors invisible(1) will be returned
#'   \item if fetch=TRUE and there were no errors a data.frame with results will be returned
#' }
#' @param channel ODBC connection obtained by \link[RODBC]{odbcConnect}
#' @param query a query string (NULL if query already prepared using \link{sqlPrepare})
#' @param data data to pass to sqlExecute (as data.frame)
#' @param fetch whether to automatically fetch results (if data provided)
#' @param errors whether to display errors
#' @param rows_at_time number of rows to fetch at one time - see details of \link[RODBC]{sqlQuery}
#' @param ... parameters to pass to \link[RODBC]{sqlFetchMore} (if fetch=TRUE)
#' @return see datails
#' @export
#' @examples
#' \dontrun{
#'   conn = odbcConnect('MyDataSource')
#'   
#'   # prepare, execute and fetch results separatly
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?")
#'   sqlExecute(conn, NULL, 'myValue')
#'   sqlFetch(conn)
#'   
#'   # prepare and execute at one time, fetch results separately
#'   sqlExecute(conn, "SELECT * FROM myTable WHERE column = ?", 'myValue')
#'   sqlFetchMore(conn)
#'   
#'   # prepare, execute and fetch at one time
#'   sqlExecute(conn, "SELECT * FROM myTable WHERE column = ?", 'myValue', TRUE)
#'   
#'   # prepare, execute and fetch at one time, pass additional parameters to sqlFetch()
#'   sqlExecute(conn, "SELECT * FROM myTable WHERE column = ?", 'myValue', TRUE, stringsAsFactors=FALSE)
#' }
sqlExecute <- function(channel, query=NULL, data=NULL, fetch=FALSE, errors=TRUE, rows_at_time=attr(channel, "rows_at_time"), ...)
{
  if(!odbcValidChannel(channel)){
    stop("first argument is not an open RODBC channel")
  }
  
  # Prepare query (if proveded)
  if(!is.null(query)){
    stat <- sqlPrepare(channel, query, errors)
    if(stat == -1L){
      return(stat); # there is no need to check if error should be thrown - this is being done by sqlPrepare()
    }
  }
  
  # Prepare data
  data = as.data.frame(data)
  for(k in seq_along(data)){
    if(is.factor(data[, k])){
      data[, k] = levels(data[, k])[data[, k]]
    }
  }
  
  # If there is no need to fetch results or no query parameters were provided,
  # call RODBCExecute once on whole data
  if(fetch == FALSE | nrow(data) < 1){
    stat <- .Call(
      "RODBCExecute", 
      attr(channel, "handle_ptr"), 
      data, 
      as.integer(rows_at_time)
    )
    if(stat == -1L) {
      if(errors){
        stop(paste0(RODBC::odbcGetErrMsg(channel), collapse='\n'))
      }
      else{
        return(stat)
      }
    }
    
    if(fetch == FALSE){
      return(invisible(stat))
    }
    
    # Fetch results
    stat = RODBC::sqlFetchMore(channel, ...)
    if(!is.data.frame(stat)) {
      if(errors){
        stop(paste0(RODBC::odbcGetErrMsg(channel), collapse='\n'))
      }
      else{
        return(stat)
      }
    }
    return(stat)
  }
  
  # If results should be fetched and query parameters were provided

  # For each row of query parameters execute the query and fetch results
  results = NULL
  for(row in 1:nrow(data)){
    stat <- .Call(
      "RODBCExecute", 
      attr(channel, "handle_ptr"), 
      as.list(data[row, ]), 
      as.integer(rows_at_time)
    )
    if(stat == -1L) {
      if(errors){
        stop(paste0(RODBC::odbcGetErrMsg(channel), collapse='\n'))
      }
      else{
        return(stat)
      }
    }      
    
    stat <- RODBC::sqlFetchMore(channel, ...)
    if(!is.data.frame(stat)) {
      if(errors){
        stop(paste0(RODBC::odbcGetErrMsg(channel), collapse='\n'))
      }
      else{
        return(stat)
      }
    }
    
    if(is.null(results)){
      results <- stat
    }else{
      results <- rbind(results, stat)
    }
  }
  return(results)
}
