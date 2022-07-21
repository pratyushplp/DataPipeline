#load Packages

library(httr)
library(jsonlite)
library(dplyr)
# library(RMariaDB)
library(data.table)
library(elastic)

source("src/UtilFunctions.R")

#building api url
#for theis api q = General query field
#1000 rows as it is the maximum number of search result available without an account

search_text <-"G10";
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

head(api_data)
api_data$osti_id

##JSON
#json file path
file_path_json<- "./src/file/"
file_name_idlist<-"IdList.json"
file_name_records <-"Records.json"

# output the record and id list to json files in local storage
#function(file_name, file_path_json, data, type)
# debug(writeToJson)

writeToJson(file_name_idlist,file_path_json, api_data,"idlist" )
writeToJson(file_name_records,file_path_json, api_data,"records" )

##MYSQL DATABASE
#connect to database using a setting file
# rmariadb.settingsfile<-"./src/datamine.cnf"
# rmariadb.db<-"datamine"
# connDataminedb<-connectToDB(rmariadb.settingsfile, rmariadb.db)

# #Note: generally there are 31 columns present, but few columns like author details and links have nested data
# #thus these fields are stored in different tables. However, org_research column is not stored in different table despite
# # it having multiple fields as the nested columns inside the field are inconsistent

#api_final_record <- api_data[, -which(names(api_data) %in% c("author_details","links"))]
writeToDb(connDataminedb, api_data)

##ELASTIC SEARCH
#connect to elastic search
host <- "127.0.0.1"
port<- "9200"
username<-"elastic"
pass<-"tKgSGz-6P3VhGQrbPoEf"
conn_elastic<- connect(host = host, port = port, user = username, pwd = pass,errors = "complete")

#write to elastic search
writeToElastic(conn_elastic,api_data,"idlist","osti_id")
writeToElastic(conn_elastic,api_data,"records","osti_id")









