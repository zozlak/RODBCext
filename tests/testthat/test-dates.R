context('dates')

test_dates = function(source, timestamp) {
  con = odbcConnect(source)
  on.exit({
    try(sqlExecute(con, "DROP TABLE test_date", errors = FALSE))
    try(sqlExecute(con, "DROP TABLE test_timestamp", errors = FALSE))
    odbcClose(con)
  })
  sqlExecute(con, "CREATE TABLE test_date (a date)")
  sqlExecute(con, paste0("CREATE TABLE test_timestamp (a ", timestamp, ")"))
  
  test_that('date is casted properly', {
    sqlExecute(con, "DELETE FROM test_date")
    
    expect_equal(sqlExecute(con, "INSERT INTO test_date VALUES (?)", '2015-01-01'), 1)
    expect_equal(sqlExecute(con, "INSERT INTO test_date VALUES (?)", as.Date('2015-02-01')), 1)
    expect_equal(sqlExecute(con, "INSERT INTO test_date VALUES (?)", as.POSIXct('2015-03-01')), 1)
    expect_equal(sqlExecute(con, "INSERT INTO test_date VALUES (?)", as.POSIXlt('2015-04-01')), 1)

    expect_equal(sqlExecute(con, "SELECT a FROM test_date WHERE a = ?", '2015-02-01', fetch = TRUE), data.frame(a = as.Date('2015-02-01')))
    expect_equal(sqlExecute(con, "SELECT a FROM test_date WHERE a = ?", as.Date('2015-03-01'), fetch = TRUE), data.frame(a = as.Date('2015-03-01')))
    expect_equal(sqlExecute(con, "SELECT a FROM test_date WHERE a = ?", as.POSIXct('2015-04-01'), fetch = TRUE), data.frame(a = as.Date('2015-04-01')))
    expect_equal(sqlExecute(con, "SELECT a FROM test_date WHERE a = ?", as.POSIXlt('2015-01-01'), fetch = TRUE), data.frame(a = as.Date('2015-01-01')))
  })
  
  test_that('data and time is casted properly', {
    sqlExecute(con, "DELETE FROM test_timestamp")
    
    expect_equal(sqlExecute(con, "INSERT INTO test_timestamp VALUES (?)", '2015-01-01 01:01:01'), 1)
    expect_equal(sqlExecute(con, "INSERT INTO test_timestamp VALUES (?)", as.Date('2015-02-01 01:01:01')), 1)
    expect_equal(sqlExecute(con, "INSERT INTO test_timestamp VALUES (?)", as.POSIXct('2015-03-01 01:01:01')), 1)
    expect_equal(sqlExecute(con, "INSERT INTO test_timestamp VALUES (?)", as.POSIXlt('2015-04-01 01:01:01')), 1)
    
    expect_equal(sqlExecute(con, "SELECT a FROM test_timestamp WHERE a = ?", '2015-02-01 00:00:00', fetch = TRUE), data.frame(a = as.POSIXct('2015-02-01 00:00:00')))
    expect_equal(sqlExecute(con, "SELECT a FROM test_timestamp WHERE a = ?", as.Date('2015-02-01'), fetch = TRUE), data.frame(a = as.POSIXct('2015-02-01 00:00:00')))
    expect_equal(sqlExecute(con, "SELECT a FROM test_timestamp WHERE a = ?", as.Date('2015-03-01'), fetch = TRUE), data.frame(a = character(), stringsAsFactors = FALSE))
    expect_equal(sqlExecute(con, "SELECT a FROM test_timestamp WHERE a = ?", as.POSIXct('2015-04-01 01:01:01'), fetch = TRUE), data.frame(a = as.POSIXct('2015-04-01 01:01:01')))
    expect_equal(sqlExecute(con, "SELECT a FROM test_timestamp WHERE a = ?", as.POSIXlt('2015-01-01 01:01:01'), fetch = TRUE), data.frame(a = as.POSIXct('2015-01-01 01:01:01')))
  })
}

timestampType = c(
  test_postgresql = 'timestamp', 
  test_mssql11 = 'datetime', 
  test_mssql13 = 'datetime',
  test_mariadb = 'timestamp'
)
for (source in names(timestampType)) {
  test_dates(source, timestampType[source])
}
