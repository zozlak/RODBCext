context('varchar')

con = sources[['oracle']]

# https://github.com/zozlak/RODBCext/issues/17
sqlExecute(con, "create table test_timestamp (dt timestamp(3))", errors = FALSE)
for (i in 1:200) {
  sqlExecute(con, "insert into test_timestamp values (sysdate)")
}
data = sqlExecute(con, "select dt from test_timestamp", fetch = TRUE, stringsAsFactors = FALSE)
expect_equal(nrow(data), 200)
sqlExecute(con, "drop table test_timestamp", errors = FALSE)
