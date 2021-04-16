%{
// This is ONLY a demo micro-shell whose purpose is to illustrate the need for and how to handle nested alias substitutions and how to use Flex start conditions.
// This is to help students learn these specific capabilities, the code is by far not a complete nutshell by any means.
// Only "alias name word", "cd word", and "bye" run.
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include<sys/wait.h>
#include <string.h>
#include "global.h"
#include <dirent.h>
#include <fcntl.h>
#define HOME varTable.word[2]
#define MAX_INDEX 129
int yylex(void);
int yyerror(char *s);
int runCD(char* arg);
int runSetAlias(char *name, char *word);
int runAlias();
int runRedirectAlias(char* output, char* file);
int runUnalias(char *name);
int runLS();
int runPrintEnv();
int runSetEnv(char *var, char* word);
int runRedirectPrintEnv(char* output, char* file);
int runUnsetEnv(char *var);
int runProcess(int index);
int runPiping();
bool inPath(int index , char* name);
%}

%union {char *string;
int number;}

%start cmd_line

%token <string> BYE CD STRING ALIAS END LS PRINTENV SETENV UNSETENV UNALIAS PIPE
%token <string> AMPERSAND ERR REDIRECT INREDIRECT
%type <number> process piping
%%
cmd_line    :
	BYE END 		                { exit(1); return 1; }
	| CD END										{ runCD(HOME); return 1; }
	| CD STRING END        			{ runCD($2); return 1; }
	| ALIAS REDIRECT STRING	END	{ runRedirectAlias($2, $3); return 1;}
	| ALIAS STRING STRING END		{ runSetAlias($2, $3); return 1; }
	| PRINTENV END							{ runPrintEnv(); return 1; }
	| PRINTENV REDIRECT STRING END {runRedirectPrintEnv($2, $3); return 1;}
	| SETENV STRING STRING END  { runSetEnv($2, $3); return 1; }
	| UNSETENV STRING END				{ runUnsetEnv($2); return 1; }
	| ALIAS END									{ runAlias(); return 1; }
	| UNALIAS STRING END				{ runUnalias($2); return 1;}
	|	amp END										{
																printf("O: %d, I: %d, E: %d\n", redirectedOutput, redirectedInput, redirectedErr);
																runPiping();


																for(int ci = 0; ci < commandIndex; ci++) commandTable[ci].argIndex = 0;
																commandIndex = 0;
																background,redirectedInput,redirectedErr,redirectedOutput = false;
																strcpy(inputFile, "");
																strcpy(outputFile, "");
																strcpy(errFile, "");
																return 1;}

	;

amp					: redirectErr {}
	| redirectErr AMPERSAND { background = true; }
	;
redirectErr : redirectOutput { }
	|	redirectOutput ERR					{ redirectedErr = true; strcpy(errFile, $2); }
	;

redirectOutput : redirectInput	{}
	| redirectInput REDIRECT STRING				{ redirectedOutput = true; strcpy(outputFile, $3); }
	;

redirectInput : piping				{}
	| piping INREDIRECT	STRING				{ redirectedInput = true; strcpy(inputFile, $2); }
	;

piping 			:
 	process											{ commandIndex++; }
	| piping PIPE process				{ commandIndex++; }

	;
process			:	STRING						{ $$ = commandIndex; strcpy(commandTable[commandIndex].command, $1); commandTable[commandIndex].argIndex = 0; }
	| process STRING							{	strcpy(commandTable[commandIndex].argList[commandTable[commandIndex].argIndex], $2); commandTable[commandIndex].argIndex++; }
	;

%%

int yyerror(char *s) {
  printf("%s\n",s);
  return 0;
  }

int runCD(char* arg) {
	if (arg[0] != '/') { // arg is relative path
		strcat(varTable.word[0], "/");
		strcat(varTable.word[0], arg);

		if(chdir(varTable.word[0]) == 0) {
			return 1;
		}
		else {
			getcwd(cwd, sizeof(cwd));
			strcpy(varTable.word[0], cwd);
			printf("Directory not found\n");
			return 1;
		}
	}
	else { // arg is absolute path
		if(chdir(arg) == 0){
			strcpy(varTable.word[0], arg);
			return 1;
		}
		else {
			printf("Directory not found\n");
                       	return 1;
		}
	}
}

int runSetAlias(char *name, char *word) {
	if(strcmp(name, word) == 0){
		printf("Error, expansion of \"%s\" would create a loop.\n", name);
		return 1;
	}
	for (int i = 0; i < aliasIndex; i++) {
		if((strcmp(aliasTable.name[i], name) == 0) && (strcmp(aliasTable.word[i], word) == 0)){
			printf("Error, expansion of \"%s\" would create a loop.\n", name);
			return 1;
		}
		else if(strcmp(aliasTable.name[i], name) == 0) {
			strcpy(aliasTable.word[i], word);
			return 1;
		}
	}
	strcpy(aliasTable.name[aliasIndex], name);
	strcpy(aliasTable.word[aliasIndex], word);
	aliasIndex++;

	return 1;
}

int runAlias() {
	for(int i = 0; i < aliasIndex; i++)
	{
		printf("%s=%s\n", aliasTable.name[i], aliasTable.word[i]);
	}
}
int runRedirectAlias(char* output, char* file) {
	FILE *redirectedOutput;
	redirectedOutput = (strlen(output) == 2) ? fopen(file, "a") : fopen(file, "w+");
	for(int i = 0; i < aliasIndex; i++)
	{
		fprintf(redirectedOutput,"%s=%s\n", aliasTable.name[i], aliasTable.word[i]);
	}
	fclose(redirectedOutput);
	return 1;
}
int runUnalias(char* name) {
	int unsetIndex = -1;
	for(int i = 0; i < aliasIndex; i++)
	{
		if(unsetIndex != -1)
		{
			strcpy(aliasTable.name[i-1],aliasTable.name[i]);
			strcpy(aliasTable.word[i-1],aliasTable.word[i]);
		}
		else if(strcmp(aliasTable.name[i], name) == 0)
		{
			unsetIndex = i;

		}
	}
	return 1;
}

int runLS() {
	DIR *dp;
	struct dirent *ep;
	dp = opendir ("./");
	if (dp != NULL)
	  {
	    while (ep = readdir (dp))
	      puts (ep->d_name);
	    (void) closedir (dp);
	  }
	else
	  printf("Couldn't open the directory\n");
	return 1;
}

int runPrintEnv() {
	//printf("-- Environment Variables -- \n");
	for(int i = 0; i < varIndex; i++)
	{
		printf("%s=%s\n", varTable.var[i], varTable.word[i]);
	}
	return 1;
}
int runRedirectPrintEnv(char* output, char* file) {
	FILE *redirectedOutput;
	redirectedOutput = (strlen(output) == 2) ? fopen(file, "a") : fopen(file, "w+");
	for(int i = 0; i < varIndex; i++)
	{
		fprintf(redirectedOutput,"%s=%s\n", varTable.var[i], varTable.word[i]);
	}
	fclose(redirectedOutput);
	return 1;
}
int runSetEnv(char *var, char *word) {
	for(int i = 0; i < varIndex; i++)
	{
		if(strcmp(varTable.var[i], var))
		{
			strcpy(varTable.word[i], word);
			return 1;
		}
	}
	if(varIndex == MAX_INDEX)
	{
		printf("Too many environment variables\n");
		return 1;
	}
	strcpy(varTable.var[varIndex], var);
	strcpy(varTable.word[varIndex], word);
	varIndex++;
	return 1;
}

int runUnsetEnv(char *var) {
	int unsetIndex = -1;

	if(strcmp(var, "PATH") == 0)
	{
		printf("Cannot unset PATH variable\n");
		return 1;
	}
	else if(strcmp(var, "HOME") == 0)
	{
		printf("Cannot unset HOME variable\n");
		return 1;
	}
	for(int i = 0; i < varIndex-1; i++)
	{
		if(strcmp(varTable.var[i], var) == 0)
		{
			strcpy(varTable.var[i], "");
		}
	}

	return 1;
}

int runProcess(int index) {

	/*printf("Process: %s\n", commandTable[index].command);
	for(int i = 0; i < commandTable[index].argIndex; i++)
	{
		printf("Arg %d: %s", i, commandTable[index].argList[i]);
	}*/

	pid_t childProcess;
	int status;
	switch(childProcess = fork())
	{
		case -1:
            printf("fork failed");
            return 1;
		case 0:
		{
			char ** argv = (char**)calloc(commandTable[index].argIndex + 1, sizeof(char*));
			argv[0] = strdup(commandTable[index].command);
			for(int i = 1; i < commandTable[index].argIndex+1; i++)
			{
				//printf("Command")
				argv[i] = strdup(commandTable[index].argList[i-1]);
			}
			argv[commandTable[index].argIndex+1] = NULL;
			if(execv(argv[0], argv) == -1)
				printf("Command failed\n");
			return 1;
		}
		default:
			if(!background)
			{

				pid_t temp;
				do {
					temp = wait(&status);

				} while(temp != childProcess);
				printf("Leaves loop");
			}
			return 1;

	}
}
int runPiping() {
	//int efd, ofd, ifd;
	pid_t bP= fork();
	int status;
	if(bP == -1)
	{
			perror("Failed to run command(s)\n");
			return 1;
	}
	else if(bP > 0)
	{
		if(!background)
		{
			pid_t temp;

			do { temp = wait(&status); } while(temp != bP);
			return 1;
		}
		return 1;
	}
	else //Child Process Follows
	{
		if(redirectedErr)
		{
			int efd = open(errFile, O_WRONLY | O_CREAT, S_IRWXO);
			if(efd == -1)
			{
				perror("Failed to redirect standard error, file may require elevated permission to access\n");
				exit(0);
			}
			if(dup2(efd, 2) == -1)
			{
				perror("Failed to redirect standard error, try again\n");
				exit(0);
			}
		}

		for(int i = 0; i < commandIndex; i++ )
		{
			if(!inPath(i, commandTable[i].command))
			{
				printf("%s", commandTable[i].command);
				perror("Command name not found in path");
				exit(0);
			}
			if(i == commandIndex-1 && redirectedOutput)
			{
				int ofd = append ? open(outputFile, O_WRONLY | O_CREAT | O_APPEND, S_IRWXO) : open(outputFile, O_WRONLY | O_CREAT, S_IRWXO);
				if(ofd == -1)
				{
					perror("Failed to redirect standard output, file may require elevated permission to access\n");
					exit(1);
				}
				if(dup2(ofd, 1) == -1)
				{
					perror("Failed to redirect standard output\n");
					exit(0);
				}
			}
			pid_t child;
			switch(child = fork())
			{
				case -1:
					perror("Fork failed\n");
					exit(0);
				case 0:
				{
					if(i == 0 && redirectedInput)
					{
						int ifd = open(inputFile, O_RDONLY);
						if( ifd == -1)
						{
							perror("Redirecting standard input failed, file name may be wrong\n");
							exit(0);
						}
						if(dup2(ifd, 0) == -1)
						{
							perror("Redirecting standard input failed on dup2\n");
							exit(0);
						}
					}
					char ** argv = (char**)calloc(commandTable[i].argIndex + 1, sizeof(char*));
					argv[0] = strdup(commandTable[i].command);
					for(int j = 1; j < commandTable[i].argIndex+1; j++)
					{
						argv[j] = strdup(commandTable[i].argList[j-1]);
					}
					argv[commandTable[i].argIndex+1] = NULL;
					if(execv(argv[0], argv) == -1)
					{
						perror("Command failed\n");
						exit(0);
					}
					exit(0);
				}
				default:
				{
						int commandStatus;
						pid_t tempB;
						do { tempB = wait(&commandStatus); } while(tempB != child);
				}
			}
		}
	}
	exit(0);
}



bool inPath(int index, char* name){
  char* temp = strdup(varTable.word[3]);
  char * token = strtok(temp, ":");
  while(token != NULL)
  {
    DIR *dp;
    struct dirent *ep;
    dp = opendir(token);
    if (dp!= NULL)
    {
      while (ep = readdir (dp))
      {

        if(strcmp(name, ep->d_name) == 0)
          {
            //*toReturn = (char*) malloc(strlen(token)+strlen(name)+1);
						char secondTemp[128];
            sprintf(secondTemp, "%s/%s", token, name);
						strcpy(commandTable[index].command, secondTemp);
            (void) closedir(dp);
            free(temp);
            return true;
          }
       }
       (void) closedir (dp);
    }
    token = strtok(NULL, ":");

  }
  free(temp);
  return false;
}
