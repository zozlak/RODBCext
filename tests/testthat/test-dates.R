context('dates')

test_dates = function(con) {
  on.exit({
    try(sqlExecute(con, "DROP TABLE test_date", errors = FALSE))
  })
  sqlExecute(con, "CREATE TABLE test_date (a date)")

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
}

test_timestamps = function(con, timestamp) {
  on.exit({
    try(sqlExecute(con, "DROP TABLE test_timestamp", errors = FALSE))
  })
  sqlExecute(con, paste0("CREATE TABLE test_timestamp (a ", timestamp, ")"))
  
  test_that('data and time is casted properly', {
    sqlExecute(con, "DELETE FROM test_timestamp")
    
    expect_equal(sqlExecute(con, "INSERT INTO test_timestamp VALUES (?)", '2015-01-01 01:01:01'), 1)
    expect_equal(sqlExecute(con, "INSERT INTO test_timestamp VALUES (?)", as.Date('2015-02-01 01:01:01')), 1)
    expect_equal(sqlExecute(con, "INSERT INTO test_timestamp VALUES (?)", as.POSIXct('2015-03-01 01:01:01')), 1)
    expect_equal(sqlExecute(con, "INSERT INTO test_timestamp VALUES (?)", as.POSIXlt('2015-04-01 01:01:01')), 1)
    
    expect_equal(setNames(sqlExecute(con, "SELECT a FROM test_timestamp WHERE a = ?", '2015-02-01 00:00:00', fetch = TRUE), 'a'), data.frame(a = as.POSIXct('2015-02-01 00:00:00')))
    expect_equal(setNames(sqlExecute(con, "SELECT a FROM test_timestamp WHERE a = ?", as.Date('2015-02-01'), fetch = TRUE), 'a'), data.frame(a = as.POSIXct('2015-02-01 00:00:00')))
    expect_equal(setNames(sqlExecute(con, "SELECT a FROM test_timestamp WHERE a = ?", as.Date('2015-03-01'), fetch = TRUE), 'a'), data.frame(a = character(), stringsAsFactors = FALSE))
    expect_equal(setNames(sqlExecute(con, "SELECT a FROM test_timestamp WHERE a = ?", as.POSIXct('2015-04-01 01:01:01'), fetch = TRUE), 'a'), data.frame(a = as.POSIXct('2015-04-01 01:01:01')))
    expect_equal(setNames(sqlExecute(con, "SELECT a FROM test_timestamp WHERE a = ?", as.POSIXlt('2015-01-01 01:01:01'), fetch = TRUE), 'a'), data.frame(a = as.POSIXct('2015-01-01 01:01:01')))
  })
}

timestampType = c(
  postgresql = 'timestamp', 
  mssql11 = 'datetime', 
  mssql13 = 'datetime',
  mariadb = 'timestamp',
  oracle = 'timestamp'
)

for (source in names(sources)) {
  if (source == 'oracle') {
    next # oracle always returns dates as ODBC timestamp
  }
  test_dates(sources[[source]])
}
for (source in names(sources)) {
  test_timestamps(sources[[source]], timestampType[source])
}
