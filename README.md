Prerequisities:
1. Install docker and docker-compose.

Docker (Used for ETL pipeline):
1. Traverse to folder "/src" where the Dockerfile resides.
2. Build:
`docker build -t r-data-pipeline .`
3. Run:
`docker run -it -v $(pwd)/file:/src/file/ r-data-pipeline`

Docker compose (Used for hosting MySQL and Elastic Server)
1. Stay on the root folder path.
2. Elastic server: `docker-compose up -d elastic`
3. MySQL DB: `docker-compose up -d db`

File JSON is stored in:
`src/file` folder path.

R# Scripts

AssignmentR.R is the main R script which contains all the ETL operation for the datapipeline
UtilFunctions.R is a seperate R files which has all the functions required for AssignmentR.R

#Connections
Datebase is connected using a cnf file
Elasticsearch has been implemented locally, with SSH disabled

#packages used
httr
jsonlite
dplyr
RMariaDB
data.tabl
elastic
