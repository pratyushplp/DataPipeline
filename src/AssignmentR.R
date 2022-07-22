#install packages
#install.packages("httr")
#install.packages("jsonlite")
#install.packages("dplyr")
#install.packages("RMariaDB")
#install.packages("data.table")
#install.packages("elastic")


#load Packages
library(httr)
library(jsonlite)
library(dplyr)
library(RMariaDB)
library(data.table)
library(elastic)

source("src/UtilFunctions.R")
source("src/config.R") 

#building api url
#for theis api q = General query field
#1000 rows as it is the maximum number of search result available without an account

#search_text <-"G10";
#taking search query input from command line
search_text <- commandArgs(trailingOnly = TRUE)
base_url<- "https://www.osti.gov/api/v1/records"
search_query <- paste0("?q=",search_text,"&rows=100") #"?q="+search_text+"&rows=1000"
full_url<- paste0(base_url,search_query)

#fetch api data
temp_api_data <- httr::GET(full_url)

#end program if data not fetched correctly
if(temp_api_data$status_code != "200"){
  stop("Error while fetching data")
}

#transform data
api_content_char<- base::rawToChar(temp_api_data$content)
api_data <- jsonlite::fromJSON(api_content_char, flatten = TRUE)
api_data[is.null(temp_api_data)] <- NA

#Note: file paths are taken from config.R file

##JSON
# output the record and id list to json files in local storage
writeToJson(file_name_idlist,file_path_json, api_data,"idlist" )
writeToJson(file_name_records,file_path_json, api_data,"records" )

##MYSQL DATABASE
#connect to database using a setting file
connDataminedb <- dbConnect(RMariaDB::MariaDB(), user= db_user , password=db_password, dbname=db_name, host=db_host)

#api_final_record <- api_data[, -which(names(api_data) %in% c("author_details","links"))]
writeToDb(connDataminedb, api_data)

##ELASTIC SEARCH
#connect to elastic search
conn_elastic<- connect(host = es_host, port = es_port, user = es_username, pwd = es_pass,errors = "complete")

#write to elastic search
writeToElastic(conn_elastic,api_data,"idlist","osti_id")
writeToElastic(conn_elastic,api_data,"records","osti_id")









