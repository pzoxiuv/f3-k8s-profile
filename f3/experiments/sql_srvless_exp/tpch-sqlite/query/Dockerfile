FROM ubuntu:latest as build
WORKDIR /src
COPY test_sql.cpp /src
RUN apt-get update 
RUN apt-get install -y build-essential
RUN apt-get install libsqlite3-dev
RUN g++ -o test_sql test_sql.cpp -lsqlite3