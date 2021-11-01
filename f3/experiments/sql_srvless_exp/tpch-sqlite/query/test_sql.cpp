/*
param1: database path (.../TPC-H.db)
param2: sql query path (.../queries.sql)
*/
//udo 
#include <iostream>
#include <sqlite3.h>
#include <sys/stat.h>
#include <fstream>
#include <sstream>
#include <vector>
using namespace std;

vector<string> pSql; 
//const char *pSql[size];

/*
This is the callback function to display the select data in the table
*/
static int callback(void *NotUsed, int argc, char **argv, char **szColName)
{
	for(int i = 0; i < argc; i++)
	{
		std::cout << szColName[i] << " = " << argv[i] << std::endl;
	}

	std::cout << "\n";
	return 0;
}

/*
This function is used to insert sqlite queries
*/
void insertQuery(string query_path);

/*
This function validates path
*/
bool validatePath(int argc, char * argv[]);

/*
This function checks if path exists
*/
inline bool exists_test3 (const std::string& name);

/*
Open a file
*/
inline ifstream open_file(string query_path);

int main(int argc, char* argv[]) {
	sqlite3 *db;
	char *szErrMsg = 0;
	int rc;
	
	//check if database path is correct
	if(!validatePath(argc, argv)){
		cout<<"Please provide valid database path\n";
		return 0;
	} 
	
	//generating queries
	insertQuery(argv[2]);
	
	//creating database connection
	rc = sqlite3_open(argv[1], &db);
	
	if( rc ) {
		fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
		return(0);
	} else {
		fprintf(stderr, "Opened database successfully\n");
	}
	
	//running queries in loop
	for(int i = 0; i < 6; i++){
		cout <<pSql[i];
		rc = sqlite3_exec(db, pSql[i].c_str(), callback, 0, &szErrMsg);
		if(rc != SQLITE_OK)
    		{
      			std::cout << "SQL Error: " << szErrMsg << std::endl;
      			sqlite3_free(szErrMsg);
      			break;
    		}
	}
	
	if(db){
		sqlite3_close(db);
	}
	return (0);
}

bool validatePath(int argc, char * argv[]){
	if(argc<3){
		cout<<"database path is not provided\n";
		return false;
	}
	if(exists_test3(argv[1])==false){
		cout<<"Unable to find database file\n";
		return false;
	}
	if(exists_test3(argv[2])==false){
		cout<<"Unable to find sqlite queries file\n";
		return false;
	}
	return true;
}

inline bool exists_test3 (const std::string& name) {
	struct stat buffer;   
	return (stat (name.c_str(), &buffer) == 0); 
}

inline ifstream open_file(string query_path){
	std::ifstream myfile; 
	myfile.open(query_path);
	return myfile;
}

void insertQuery(string query_path){
	ifstream infile = open_file(query_path);
	std::string line, query="";
	while (std::getline(infile, line))
	{	
		if(line!=""){
			query+=line;
			if(line[line.size()-1]==';'){
				pSql.push_back(query);
				query="";
			}
		}			
	}
}