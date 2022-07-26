#steps : see if the json file exists or not
# if it does not exists create the json file and add data
# if the file exists check for duplicates by reading the file 
# then append the data to the json file.

#return successful write or log it if requried later.

writeToJson<- function(file_name, file_path_json, data, type)
{
  
  current_data <- NULL
  
  if(type == "idlist")
  {
    current_data<- data.frame(data$osti_id)
    colnames(current_data)<-"osti_id"
  }
  else
  {
    current_data<- data
  }
  
  fullPath<- paste0(file_path_json,file_name)
  if(file.exists( fullPath))
  {
    existing_data<-fromJSON(fullPath)
    new_data<-NULL
    final_data<-NULL
    if(type == "idlist")
    {
      #setdiff(x,y) : present in x but not in y
      new_data <- setdiff(current_data,existing_data) 
      new_data<- data.frame(new_data)
      colnames(new_data)<-"osti_id"
    }
    else
    {
      #filter duplicate data using osti_id
      #setdiff(x,y) : present in x but not in y
      new_id<- setdiff(current_data$osti_id,existing_data$osti_id)
      new_data<- dplyr::filter(current_data, osti_id %in% new_id)
    }
    #bind_rows works with unequal columns
    final_data<-bind_rows(existing_data,new_data)
    write( jsonlite::toJSON(final_data), fullPath)
    print(paste0("Write to json file completed successfully for file ",file_name))
  }
  else
  {
    write(jsonlite::toJSON(current_data), fullPath)
    print(paste0("Write to json file completed successfully for file ",file_name))
    
  }
}

#TODO ; remove character(0)
writeToDb <- function(connection, data)
{
  api_record_table<-NULL
  if(dbExistsTable(connection,"records"))
  {
    #filtering out duplicate data
    existing_id <- dbGetQuery(connection, "SELECT osti_id FROM records")
    new_id <- setdiff(data$osti_id ,existing_id$osti_id) 
    new_data<- dplyr::filter(data, osti_id %in% new_id)
    
    #first insert to records table
    #api_final_record <- new_data[, -which(names(new_data) %in% c("author_details","links"))]
    #change to Data table
    api_temp <-data.table(new_data)
    api_record_table<-api_temp
  }
  else
  {
    print("Datatable not present, creating table")
    #script to create datatable if table does not exists
    dbGetQuery(connection,"CREATE TABLE datamine.records (
                        id INT NOT NULL AUTO_INCREMENT,
                        osti_id VARCHAR(20) NULL,             
                        title TEXT CHARACTER SET utf8 NULL,                  
                        doi    VARCHAR(500) NULL,             
                        product_type  VARCHAR(200) NULL,      
                        language  VARCHAR(200) NULL,          
                        country_publication VARCHAR(500) NULL,
                        description    TEXT CHARACTER SET utf8 NULL,     
                        publication_date   DATETIME NULL, 
                        entry_date       DATETIME NULL,   
                        format         VARCHAR(500) NULL,     
                        authors        LONGTEXT CHARACTER SET utf8 NULL,     
                        article_type     TEXT NULL,   
                        doe_contract_number TEXT NULL,
                        subjects     LONGTEXT CHARACTER SET utf8 NULL,      
                        sponsor_orgs   TEXT CHARACTER SET utf8 NULL,    
                        research_orgs  TEXT CHARACTER SET utf8 NULL,     
                        other_identifiers    TEXT CHARACTER SET utf8 NULL,              
                        publisher    TEXT CHARACTER SET utf8 NULL,       
                        journal_name  TEXT NULL,      
                        journal_issue  VARCHAR(200) NULL,     
                        journal_volume VARCHAR(200) NULL,      
                        journal_issn  VARCHAR(200) NULL,      
                        report_number  VARCHAR(200) NULL,     
                        conference_info  TEXT CHARACTER SET utf8 NULL,   
                        contributing_org  TEXT CHARACTER SET utf8 NULL,  
                        availability TEXT CHARACTER SET utf8 NULL,       
                        type_qualifier  TEXT NULL, 
                        author_details  LONGTEXT CHARACTER SET utf8 NULL, 
                        links  TEXT CHARACTER SET utf8 NULL, 
                        coverage TEXT NULL,           
                        org_research LONGTEXT CHARACTER SET utf8 NULL,
                        PRIMARY KEY (id));")
    print("Datatable not present in current database. Automatically created datatable")
    
    api_record_table<-data
  }
  
  #add extra columns if needed as per data
  column_names<-names(api_record_table)
  column_existing<- dbGetQuery(connection,"DESCRIBE Records")
  column_names_existing<-column_existing$Field
  new_columns<- setdiff(column_names,column_names_existing)
  for(col in new_columns)
  {
    query<- paste0("ALTER TABLE records ADD ",col," TEXT CHARACTER SET utf8 NULL")
    dbGetQuery(connection,query)
  }
  
  
  
  #Transform
  #update column type from list to char for specific columns so they can be stored in DB
  change_columns <- c("authors","subjects","sponsor_orgs","research_orgs","other_identifiers","org_research","links","author_details")
  change_columns<- intersect(change_columns,column_names)
  api_record_table[,(change_columns) := lapply(.SD, as.character),.SDcols=change_columns]

  #transform date
  final_date<-sapply(api_record_table$publication_date, function(x)gsub('T', ' ', x))
  final_date<-sapply(api_record_table$publication_date, function(x)gsub('Z', '', x))
  api_record_table$publication_date<-final_date
  
  final_date2<-sapply(api_record_table$entry_date, function(x)gsub('T', ' ', x))
  final_date2<-sapply(api_record_table$entry_date, function(x)gsub('Z', '', x))
  api_record_table$entry_date<-final_date2
  
  
  #write to records table
  dbWriteTable(connection, "Records", api_record_table,overwrite=FALSE,append=TRUE)
  print(paste0("Write to database completed successfully for table ","records"))
  dbDisconnect(connection)
}


writeToElastic <- function(connection,data,indexName,field)
{
  if(!index_exists(connection, indexName))
  {
    index_create(connection,indexName) 
    mapping_create(connection,index = indexName, body ='{ "dynamic": "false"}' )
  }
  current_data <- if(indexName == "idlist") data$osti_id else data
  
  #get existing field data
  time<-1
  res <- Search(connection, index = indexName, time_scroll="5m",source = field,asdf = TRUE,size = 100)
  existing_data <- res$hits$hits
  hits <- 1
  
  while(hits != 0){
    res <- scroll(connection, res$`_scroll_id`, time_scroll="5m" ,source = field,asdf = TRUE,size = 100)
    hits <- length(res$hits$hits)
    if(hits > 0)
      existing_data <- c(existing_data, res$hits$hit)
  }
  new_data<-NULL
  if(indexName == "idlist")
  {
    new_data <- setdiff(current_data,existing_data$osti_id) 
    new_data<- data.frame(new_data)
    colnames(new_data)<-"osti_id"
  }
  else
  {
    new_id<- setdiff(current_data$osti_id,existing_data$osti_id)
    new_data<- dplyr::filter(current_data, osti_id %in% new_id)
  }

  # clear scroll
  scroll_clear(connection, res$`_scroll_id`)

  #write to index
  docs_bulk(connection,new_data, index = indexName)
  print(paste0("Write to elasticsearch completed successfully for index ",indexName))
  
}






