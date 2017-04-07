library(RODBC)
library(RODBCext)

# This file is used to test the query timeout feature of the package RODBCext
# with the Mircosoft SQL Server 2012 or higher.



# Connect to database -----------------------------------------------------

con <- RODBC::odbcConnect("your DSN")
RODBC::odbcGetInfo(con)

# Or use a dedicated connection string
# con.String <- "Driver={SQL Server Native Client 11.0};Server=<your DB URI>;Trusted_Connection=yes;database=<your DB name>"
# con <- RODBC::odbcDriverConnect(con.String)


# Prepare database for test cases -----------------------------------------

sqlQuery(con, "DROP TABLE dbo.test_querytimeout")

sqlQuery(con, "CREATE TABLE dbo.test_querytimeout (ID int, msg varchar(100))")

sqlQuery(con, "INSERT INTO dbo.test_querytimeout values( 1, 'hello'), (2, 'world'), (3, 'test'), (4, 'RODBCext now')")

sqlQuery(con, "SELECT * FROM dbo.test_querytimeout")



# RODBCext tests ----------------------------------------------------------

sqlExecute(con, "SELECT * FROM dbo.test_querytimeout", fetch=TRUE)
odbcGetQueryTimeout(con)
# should return 0 by default

sqlExecute(con, "SELECT * FROM dbo.test_querytimeout", fetch=TRUE, query_timeout=37)
odbcGetQueryTimeout(con)
# should return 37 seconds now

sqlPrepare(con, "SELECT * FROM dbo.test_querytimeout")
sqlExecute(con, fetch=TRUE)
odbcGetQueryTimeout(con)
# should return 0 by default

sqlPrepare(con, "SELECT * FROM dbo.test_querytimeout", query_timeout=47)
sqlExecute(con, fetch=TRUE)
odbcGetQueryTimeout(con)
# should return 47

sqlPrepare(con, "SELECT * FROM dbo.test_querytimeout WHERE ID = ?")
sqlExecute(con, data=2, fetch=TRUE)
odbcGetQueryTimeout(con)
# should return 0 (default value)

sqlPrepare(con, "SELECT * FROM dbo.test_querytimeout WHERE ID = ?", query_timeout=103)
sqlExecute(con, data=2, fetch=TRUE)
odbcGetQueryTimeout(con)
# should return 103

sqlPrepare(con, "SELECT * FROM dbo.test_querytimeout WHERE ID = ?")
odbcGetQueryTimeout(con)
# should return 0
sqlExecute(con, data=2, fetch=TRUE, query_timeout=111)
odbcGetQueryTimeout(con)
# should return 111

sqlPrepare(con, "SET NOCOUNT ON; WAITFOR DELAY '00:00:03'")
odbcGetQueryTimeout(con)
# should return 0
sqlExecute(con)
# must return without an error after 3 seconds

sqlExecute(con, query_timeout=2)
# must return with an error:
# HYT00 0 [Microsoft][SQL Server Native Client 11.0]Query timeout expired
# or
# HYT00 0 [Microsoft][SQL Server Native Client 11.0]Query timeout expired

sqlPrepare(con, "SET NOCOUNT ON; WAITFOR DELAY '00:00:03'", query_timeout=2)
odbcGetQueryTimeout(con)
# should return 2
sqlExecute(con)
# must return with an error: HYT00 ... (see above)

sqlPrepare(con, "SET NOCOUNT ON; WAITFOR DELAY '00:00:03'")
odbcGetQueryTimeout(con)
# should return 0
sqlExecute(con, query_timeout=2)
# must return with an error: HYT00 ... (see above)

sqlExecute(con, query_timeout="a")
# Must return:  Error: is.numeric(query_timeout) is not TRUE

sqlExecute(con, query_timeout=1:2)
# Must return:  Error: length(query_timeout) == 1 is not TRUE

sqlExecute(con, query_timeout=NA)
# Must return:  Error: is.numeric(query_timeout) is not TRUE

sqlExecute(con, query_timeout=NA_integer_)
# Must return:  [RODBCext] Error: 'SetQueryTimeout' failed (the timeout parameter is NA!)



# Shut down ---------------------------------------------------------------

RODBC::odbcClose(con)
