#include "stdbool.h"
#include <limits.h>

struct evTable {
   char var[128][100];
   char word[128][100];
};

struct aTable {
	char name[128][100];
	char word[128][100];
};
struct command {
  char command[128];
  char argList[128][100];
  int argIndex;
};

struct command commandTable[100];
int commandIndex;
bool background;
bool redirectedInput;
bool append;
char inputFile[128];
bool redirectedOutput;
char outputFile[128];
bool redirectedErr;
bool errToOut;
char errFile[128];
char cwd[PATH_MAX];
bool sunalias;
int wordCount;
struct evTable varTable;

struct aTable aliasTable;

int aliasIndex, varIndex;

char* subAliases(char* name);
