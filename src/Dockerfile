# Base image https://hub.docker.com/u/rocker/
FROM rocker/r-apt:bionic

## Install R-packages
RUN apt-get update && \
    apt-get install -y -qq \
    	r-cran-httr \
    	r-cran-jsonlite \
    	r-cran-dplyr \
		# r-cran-MariaDB \
        r-cran-data.table \
        r-cran-elastic

## Copy packages files
COPY /install_packages.R /install_packages.R
COPY ./ ./src

## install R-packages
RUN Rscript /install_packages.R
CMD Rscript /src/AssignmentR.R
