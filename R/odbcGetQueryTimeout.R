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

#' @title Gets the current query timeout of a prepared query
#' @description A query has to be already prepared using SQLPrepare()
#' 
#' Throws an error if an error occured
#' @param channel an RODBC channel containing an open connection
#' @return The current query timeout value in seconds. 0 means "no timeout"
#' @seealso \code{\link{odbcSetQueryTimeout}}, \code{\link{odbcConnect}},
#'   \code{\link{odbcDriverConnect}}
#' @examples
#' \dontrun{
#'   conn = odbcConnect('MyDataSource')
#'   
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?")
#'   odbcGetQueryTimeout(conn)   # shows the current query timeout of the prepared statement
#'   sqlExecute(conn, 'myValue')
#'   sqlFetchMore(conn)
#' }
#' @export
odbcGetQueryTimeout = function(channel)
{
  stopifnot(odbcValidChannel(channel))

  stat = .Call("RODBCGetQueryTimeout", attr(channel, "handle_ptr"))
  
  if (stat == -1L) {
    stop(paste0(RODBC::odbcGetErrMsg(channel), collapse = '\n'))
  } else {
    return(stat)
  }
}
