



This report was automatically generated with the R package **knitr**
(version 1.14).


```r
# Run this knintr::stitch_rmd line below (in the console) for easier communication to other developers.
#   It runs everything below and save the results to an md & html file.
#   Notice the 'sessionInfo()' at the bottom of the output.
# knitr::stitch_rmd(script="./tests/manual/test-varchar.R", output="./tests/manual/stitched-output/test-varchar.md")

rm(list=ls(all=TRUE)) #Clear the memory for any variables set from any previous runs.
```

```r
requireNamespace("RODBC")
requireNamespace("RODBCext")
requireNamespace("testit")
```

```r
set.seed(234) #To make the results easier to compare.

dsn_13_1 <- "rodbcext-test-13-1" #ODBC Driver 13.1: https://www.microsoft.com/en-us/download/details.aspx?id=53339
dsn_11_0 <- "rodbcext-test-11-0" #ODBC Driver 11: https://www.microsoft.com/en-us/download/details.aspx?id=36434
row_count <- 5L

sql_delete   <- "DELETE FROM dbo.tbl_chracter_test_1"
sql_insert   <- "INSERT INTO dbo.tbl_chracter_test_1 VALUEs (?, ?, ?, ?, ?)"
sql_retrieve <- "SELECT * FROM dbo.tbl_chracter_test_1"

ds_write <- data.frame(
	ID               = seq_len(row_count),
	char_5           = replicate(row_count, paste(sample(letters, size=   5L, replace=T), collapse="")),
	char_255         = replicate(row_count, paste(sample(letters, size= 255L, replace=T), collapse="")),
	char_256         = replicate(row_count, paste(sample(letters, size= 256L, replace=T), collapse="")),
	char_8000        = replicate(row_count, paste(sample(letters, size=8000L, replace=T), collapse="")),
	# char_max       = replicate(row_count, paste(sample(letters, size=8001L, replace=T), collapse="")), #Is there a column/condition that makes sense for max?
	stringsAsFactors = FALSE
)
```

```r
channel <- RODBC::odbcConnect(dsn_13_1)
getSqlTypeInfo("Microsoft SQL Server")
```

```
## $double
## [1] "float"
## 
## $integer
## [1] "int"
## 
## $character
## [1] "varchar(255)"
## 
## $logical
## [1] "varchar(5)"
```

```r
channel_info <- odbcGetInfo(channel)
channel_info["Server_Name"] <- "redacted" #Clear the database name
print(channel_info)
```

```
##              DBMS_Name               DBMS_Ver        Driver_ODBC_Ver 
## "Microsoft SQL Server"           "10.00.6241"                "03.80" 
##       Data_Source_Name            Driver_Name             Driver_Ver 
##   "rodbcext-test-13-1"      "msodbcsql13.dll"           "13.01.0811" 
##               ODBC_Ver            Server_Name 
##           "03.80.0000"             "redacted"
```

```r
base::tryCatch(
  expr = {
    
    RODBCext::sqlExecute(channel, sql_delete)
    RODBCext::sqlExecute(channel, sql_insert, ds_write)
    
    ds_read_13_1 <- RODBCext::sqlExecute(channel, sql_retrieve, data=NULL, fetch=TRUE, stringsAsFactors=FALSE)
    
  }, finally = {
    RODBC::odbcClose(channel)
    rm(channel)
  }
)

sapply(ds_read_13_1, function(x ) max(nchar(x)))
```

```
##        id    char_5  char_255  char_256 char_8000 
##         1         5       255       255      7999
```

```r
# > sapply(ds_read_13_1, function(x ) max(nchar(x)))
#        id    char_5  char_255  char_256 char_8000 
#         1         5       255       255      7999 
        
testit::assert("The `id` column should be correct.", identical(ds_read_13_1$id, 1L:5L))

testit::assert("The 5-character column should have.the correct length", all(nchar(ds_read_13_1$char_5)==5L))
testit::assert("The 5-character column should be correct.", identical(ds_read_13_1$char_5, ds_write$char_5))

testit::assert("The 255-character column should have.the correct length", all(nchar(ds_read_13_1$char_255)==255L))
testit::assert("The 255-character column should be correct.", identical(ds_read_13_1$char_255, ds_write$char_255))

#This fails.  All elements are 255 (not 256)
testit::assert("The 256-character column should have.the correct length", all(nchar(ds_read_13_1$char_256)==256L))
```

```
## assertion failed: The 256-character column should have.the correct length
```

```
## Error: all(nchar(ds_read_13_1$char_256) == 256L) is not TRUE
```

```r
testit::assert("The 256-character column should be correct.", identical(ds_read_13_1$char_256, ds_write$char_256))
```

```
## assertion failed: The 256-character column should be correct.
```

```
## Error: identical(ds_read_13_1$char_256, ds_write$char_256) is not TRUE
```

```r
#This fails.  All elements are 7999
testit::assert("The 8000-character column should have.the correct length", all(nchar(ds_read_13_1$char_8000)==8000L))
```

```
## assertion failed: The 8000-character column should have.the correct length
```

```
## Error: all(nchar(ds_read_13_1$char_8000) == 8000L) is not TRUE
```

```r
testit::assert("The 8000-character column should be correct.", identical(ds_read_13_1$char_8000, ds_write$char_8000))
```

```
## assertion failed: The 8000-character column should be correct.
```

```
## Error: identical(ds_read_13_1$char_8000, ds_write$char_8000) is not TRUE
```

```r
channel <- RODBC::odbcConnect(dsn_11_0)
getSqlTypeInfo("Microsoft SQL Server")
```

```
## $double
## [1] "float"
## 
## $integer
## [1] "int"
## 
## $character
## [1] "varchar(255)"
## 
## $logical
## [1] "varchar(5)"
```

```r
channel_info <- odbcGetInfo(channel)
channel_info["Server_Name"] <- "redacted" #Clear the database name
print(channel_info)
```

```
##              DBMS_Name               DBMS_Ver        Driver_ODBC_Ver 
## "Microsoft SQL Server"           "10.00.6241"                "03.80" 
##       Data_Source_Name            Driver_Name             Driver_Ver 
##   "rodbcext-test-11-0"      "msodbcsql11.dll"           "11.00.2270" 
##               ODBC_Ver            Server_Name 
##           "03.80.0000"             "redacted"
```

```r
base::tryCatch(
  expr = {
    
    RODBCext::sqlExecute(channel, sql_delete)
    RODBCext::sqlExecute(channel, sql_insert, ds_write)
    
    ds_read_11_0 <- RODBCext::sqlExecute(channel, sql_retrieve, data=NULL, fetch=TRUE, stringsAsFactors=FALSE)
    
  }, finally = {
    RODBC::odbcClose(channel)
    rm(channel)
  }
)

sapply(ds_read_11_0, function(x ) max(nchar(x)))
```

```
##        id    char_5  char_255  char_256 char_8000 
##         1         5       255       255      7999
```

```r
# > sapply(ds_read_11_0, function(x ) max(nchar(x)))
#        id    char_5  char_255  char_256 char_8000 
#         1         5       255       255      7999 
        
testit::assert("The `id` column should be correct.", identical(ds_read_11_0$id, 1L:5L))

testit::assert("The 5-character column should have.the correct length", all(nchar(ds_read_11_0$char_5)==5L))
testit::assert("The 5-character column should be correct.", identical(ds_read_11_0$char_5, ds_write$char_5))

testit::assert("The 255-character column should have.the correct length", all(nchar(ds_read_11_0$char_255)==255L))
testit::assert("The 255-character column should be correct.", identical(ds_read_11_0$char_255, ds_write$char_255))

#This fails.  All elements are 255 (not 256)
testit::assert("The 256-character column should have.the correct length", all(nchar(ds_read_11_0$char_256)==256L))
```

```
## assertion failed: The 256-character column should have.the correct length
```

```
## Error: all(nchar(ds_read_11_0$char_256) == 256L) is not TRUE
```

```r
testit::assert("The 256-character column should be correct.", identical(ds_read_11_0$char_256, ds_write$char_256))
```

```
## assertion failed: The 256-character column should be correct.
```

```
## Error: identical(ds_read_11_0$char_256, ds_write$char_256) is not TRUE
```

```r
#This fails.  All elements are 7999
testit::assert("The 8000-character column should have.the correct length", all(nchar(ds_read_11_0$char_8000)==8000L))
```

```
## assertion failed: The 8000-character column should have.the correct length
```

```
## Error: all(nchar(ds_read_11_0$char_8000) == 8000L) is not TRUE
```

```r
testit::assert("The 8000-character column should be correct.", identical(ds_read_11_0$char_8000, ds_write$char_8000))
```

```
## assertion failed: The 8000-character column should be correct.
```

```
## Error: identical(ds_read_11_0$char_8000, ds_write$char_8000) is not TRUE
```

The R session information (including the OS info, R version and all
packages used):


```r
sessionInfo()
```

```
## R version 3.3.1 Patched (2016-08-12 r71089)
## Platform: x86_64-w64-mingw32/x64 (64-bit)
## Running under: Windows 7 x64 (build 7601) Service Pack 1
## 
## locale:
## [1] LC_COLLATE=English_United States.1252 
## [2] LC_CTYPE=English_United States.1252   
## [3] LC_MONETARY=English_United States.1252
## [4] LC_NUMERIC=C                          
## [5] LC_TIME=English_United States.1252    
## 
## attached base packages:
## [1] stats     graphics  grDevices utils     datasets  methods   base     
## 
## other attached packages:
## [1] RODBCext_0.2.7 RODBC_1.3-13  
## 
## loaded via a namespace (and not attached):
## [1] magrittr_1.5  formatR_1.4   tools_3.3.1   stringi_1.1.1 knitr_1.14   
## [6] stringr_1.1.0 testit_0.5    evaluate_0.9
```

```r
Sys.time()
```

```
## [1] "2016-09-03 12:19:01 CDT"
```

