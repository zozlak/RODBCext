context('varchar')

test_varchar = function(con, param) {
  param[['textLimWrite']] = min(c(70000, param[['textLimWrite']]))

  on.exit({
    try(sqlExecute(con, "DROP TABLE test_char"))
  })
  createQuery = paste0(
    paste0(
      "CREATE TABLE test_char (
        char_5 varchar(5), 
        char_255 varchar(255), 
        char_256 varchar(256), 
        char_4000 varchar(4000), 
        char_text ", param[['textType']], 
      ")"
    )
  )
  sqlExecute(con, createQuery)

  count = 3
  data = data.frame(
    char_5           = rep('abcde', count),
    char_255         = rep(paste0(letters[(1:255 %% 26) + 1], collapse = ''), count),
    char_256         = rep(paste0(letters[(1:256 %% 26) + 1], collapse = ''), count),
    char_4000        = rep(paste0(letters[(1:4000 %% 26) + 1], collapse = ''), count),
    char_text        = rep(paste0(letters[(1:param[['textLimWrite']] %% 26) + 1], collapse = ''), count),
    stringsAsFactors = FALSE
  )
  
  test_that('prepare works', {
    expect_equal(sqlPrepare(con, "INSERT INTO test_char (char_5, char_255, char_256, char_4000, char_text) VALUES (?, ?, ?, ?, ?)"), 1)
  })
  
  test_that('insert works', {
    expect_equal(sqlExecute(con, NULL, data), 1)
    
    lenQuery = paste0(
      "SELECT ",
      param[['lenFunc']], '(char_5) AS n_5, ',
      param[['lenFunc']], '(char_255) AS n_255, ',
      param[['lenFunc']], '(char_256) AS n_256, ',
      param[['lenFunc']], '(char_4000) AS n_4000, ',
      param[['lenFunc']], '(char_text) AS n_text ',
      "FROM test_char"
    )
    res = sqlExecute(con, lenQuery, NULL, TRUE)
    names(res) = tolower(names(res))
    expect_equal(res, data.frame(
      n_5 = rep(5, count),
      n_255 = rep(min(c(255, param[['varcharLim']])), count),
      n_256 = rep(min(c(256, param[['varcharLim']])), count),
      n_4000 = rep(min(c(4000, param[['varcharLim']])), count),
      n_text = rep(param[['textLimWrite']], count)
    ))
  })
  
  test_that('select works', {
    d = sqlExecute(con, "SELECT * FROM test_char", NULL, TRUE, stringsAsFactors = FALSE)
    names(d) = tolower(names(d))
    dataAdj = data
    dataAdj$char_255 = substr(dataAdj$char_255, 1, min(c(255, param[['varcharLim']])))
    dataAdj$char_256 = substr(dataAdj$char_256, 1, min(c(256, param[['varcharLim']])))
    dataAdj$char_4000 = substr(dataAdj$char_4000, 1, min(c(4000, param[['varcharLim']])))
    dataAdj$char_text = substr(dataAdj$char_text, 1, min(c(param[['textLimWrite']], param[['textLimRead']])))
    expect_equal(d, dataAdj)
  })
}

# Remarks:
# - Postgresql textLimitWrite/Read value of 8190 is a default of the Postgresql ODBC driver but can be adjust in the ODBC data source settings
# - MySQL varcharLim is in fact 65535 bytes for the whole row
# - MsSQL textLimRead is determined by RODBCext DEFAULT_BUFF_SIZE constant (and is equal DEFAULT_BUFF_SIZE - 1)
param = list(
  postgresql = list(textType = 'text',         lenFunc = 'length', varcharLim = 255,   textLimWrite = 8190, textLimRead = 8190),
  mssql11    = list(textType = 'varchar(max)', lenFunc = 'len',    varcharLim = Inf,   textLimWrite = Inf,  textLimRead = 65535),
  mssql13    = list(textType = 'varchar(max)', lenFunc = 'len',    varcharLim = Inf,   textLimWrite = Inf,  textLimRead = 65535),
  mariadb    = list(textType = 'longtext',     lenFunc = 'length', varcharLim = 65535, textLimWrite = Inf,  textLimRead = 16776960),
  oracle     = list(textType = 'clob',         lenFunc = 'length', varcharLim = 4000,  textLimWrite = Inf,  textLimRead = 16776960)
)

for (source in names(sources)) {
  test_varchar(sources[[source]], param[[source]])
}
