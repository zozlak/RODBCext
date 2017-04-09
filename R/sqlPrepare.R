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
#' @import RODBC
#' @description
#' Prepares a query for execution.
#' @param channel ODBC connection obtained by \link{odbcConnect}
#' @param query query string
#' @param errors whether to display errors
#' @param query_timeout the query timeout value in seconds
#'        (0 means "no timeout", NULL does not change the default value)
#' @return invisible(1) on success, -1 or an error (depending on errors parameter) on error
#' @export
#' @examples
#' \dontrun{
#'   conn = odbcConnect('MyDataSource')
#'   
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?")
#'   sqlExecute(conn, NULL, 'myValue')
#'   sqlFetchMore(conn)
#'   
#'   # with a query timeout
#'   sqlPrepare(conn, "SELECT * FROM myTable WHERE column = ?", query_timeout=60)
#'   sqlExecute(conn, data='myValue', fetch=TRUE)
#' }
sqlPrepare = function(channel, query, errors = TRUE, query_timeout = NULL)
{
  stopifnot(
    odbcValidChannel(channel),
    is.vector(query), is.character(query), length(query) == 1, all(!is.na(query)),
    is.vector(query_timeout) & is.numeric(query_timeout) & length(query_timeout) == 1 & all(!is.na(query_timeout)) | is.na(query_timeout)
  )

  enc = attr(channel, "encoding")
  if (nchar(enc) > 0) {
    query = iconv(query, to = enc)
  }
  query = as.character(query)
  
  stat = .Call("RODBCPrepare", attr(channel, "handle_ptr"), query)
  if (stat == -1L) {
    if (errors) {
      stop(paste0(RODBC::odbcGetErrMsg(channel), collapse = '\n'))
    } else {
      return(stat)
    }
  }
  
  attr(channel, 'query') = query
  
  # Set the query timeout
  if (!is.null(query_timeout)) {
    if (!errors) {
      tryCatch(
        odbcSetQueryTimeout(channel, query_timeout),
        error = return
      )
    } else {
      odbcSetQueryTimeout(channel, query_timeout)
    }
  }

  return(invisible(stat))
}