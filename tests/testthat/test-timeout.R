context('timeout - MS SQL Server')

test_timeout = function(source, sleepSql, shouldPass) {
  con = odbcConnect(source)
  on.exit(odbcClose(con))
  
  sleepSql = sprintf(sleepSql, 3)
  
  if (shouldPass) {
    test_that('setting timeout works', {
      query = sqlPrepare(con, "SELECT 1")
      expect_equal(odbcGetQueryTimeout(con), 0)
      
      query = sqlPrepare(con, "SELECT 1", query_timeout = 5)
      expect_equal(odbcGetQueryTimeout(con), 5)
      
      odbcSetQueryTimeout(con, 10)
      expect_equal(odbcGetQueryTimeout(con), 10)
      
      query = sqlExecute(con, "SELECT 1", query_timeout = 20)
      expect_equal(odbcGetQueryTimeout(con), 20)
    })
    
    test_that('enforcing timeout works', {
      expect_equal(sqlExecute(con, "SELECT 1 AS a", query_timeout = 1, fetch = TRUE), data.frame(a = 1L))
    
      query = sqlPrepare(con, "SELECT 1 AS a", query_timeout = 2)
      expect_equal(sqlExecute(con, fetch = TRUE), data.frame(a = 1L))
      
      expect_equal(suppressWarnings(sqlExecute(con, sleepSql, query_timeout = 1, errors = FALSE)), -1)
      
      query = sqlPrepare(con, sleepSql)
      expect_equal(suppressWarnings(sqlExecute(con, query_timeout = 1, errors = FALSE)), -1)
    })
  } else {
    test_that('setting timeout fails', {
      sqlPrepare(con, "SELECT 1 AS a")
      expect_error(odbcSetQueryTimeout(con, 10), 'the timeout was not set')
      
      expect_error(sqlPrepare(con, "SELECT 1 AS a", query_timeout = 10), 'the timeout was not set')
      
      expect_error(sqlExecute(con, "SELECT 1 AS a", query_timeout = 10), 'the timeout was not set')
    })
  }
}

sleepQueries = c(
  test_postgresql = "SELECT pg_sleep(%d)", 
  test_mssql11 = "WAITFOR DELAY '00:%d'", 
  test_mssql13 = "WAITFOR DELAY '00:%d'",
  test_mariadb = 'SELECT sleep(%d)'
)
expectedResults = c(
  test_postgresql = FALSE, 
  test_mssql11 = TRUE, 
  test_mssql13 = TRUE,
  test_mariadb = FALSE
)
for (source in names(sleepQueries)) {
  test_timeout(source, sleepQueries[source], expectedResults[source])
}
