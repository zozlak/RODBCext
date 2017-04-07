# Copyright (C) 2017 Juergen Altfeld, Mateusz Zoltak
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



#' Get the current query timeout of a prepared query
#'
#' A query has to be already prepared using SQLPrepare()
#'
#' @param channel an RODBC channel containing an open connection
#'
#' @return The current query timeout value in seconds. 0 means "no timeout"
#' 
#' @description Throws any error if an error occured
#' 
#' @seealso \code{\link{odbcSetQueryTimeout}}, \code{\link{odbcConnect}}, \code{\link{odbcDriverConnect}}
#' 
#' @examples
#' \dontrun{
#'   conn = odbcConnect('MyDataSource')
#'   
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?")
#'   odbcGetQueryTimeout(conn)   # shows the current query timeout of the prepared statement
#'   sqlExecute(conn, 'myValue')
#'   sqlFetchMore(conn)
#' }
#' 
#' @export
odbcGetQueryTimeout <- function(channel)
{
  if (!odbcValidChannel(channel))
    stop("first argument is not an open RODBC channel")
  
  stat <- .Call("RODBCGetQueryTimeout", attr(channel, "handle_ptr"))
  
  if (stat == -1L) {
    stop(paste0(RODBC::odbcGetErrMsg(channel), collapse = '\n'))
  }
  else {
    return(stat)
  }
    
}



#' Sets the query timeout of a prepared query
#'
#' A query has to be already prepared using SQLPrepare()
#'
#' @param channel an open RODBC channel (connection)
#' @param timeout the new query timeout value in seconds (0 means "no timeout")
#'
#' @return  0 = success,
#'          1 = success but with an info message,
#'
#' @seealso \code{\link{odbcGetQueryTimeout}}, \code{\link{odbcConnect}}, \code{\link{odbcDriverConnect}}
#'
#' @description Throws an error if any error occured
#' 
#' @note Not all drivers will support a query timeout. You may get an error then
#'       or the query timeout values remains unchanged silently.
#' 
#' @examples
#' \dontrun{
#'   conn = odbcConnect('MyDataSource')
#'   
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?")
#'   odbcSetQueryTimeout(conn, 120)   # sets the query timeout of the prepared statement
#'   sqlExecute(conn, 'myValue')
#'   sqlFetchMore(conn)
#' }
#' 
#' @export
odbcSetQueryTimeout <- function(channel, timeout = 30)
{
  if (!odbcValidChannel(channel))
    stop("first argument is not an open RODBC channel")
  
  stat <- .Call("RODBCSetQueryTimeout", attr(channel, "handle_ptr"), timeout)

  if (stat == -1L) {
    stop(paste0(RODBC::odbcGetErrMsg(channel), collapse = '\n'))
  }
  else {
    return(stat)
  }
  
}
