%define parse.error verbose
%{
#include<iostream>
#include<string>
#include<vector>
#include<map>
#include<fstream>

using namespace std;

struct conditionCommandsContainer {
	vector<string> *commands;
	long long index;
};

struct identifierCommandsContainer {
	vector<string> *commands;
	long long index;
	bool isIterator;
	string variableName;
};

struct variableContainer {
	long long address;
	long long size;
	bool isArray;
	bool initialized;
	long long minIndex;
	long long maxIndex;
	bool isIterator;
};

long long index = 20;
long long currentLabel = 1;
string outputFile;
typedef struct identifierCommandsContainer identifierContainer;
typedef struct conditionCommandsContainer conditionContainer;
typedef struct variableContainer variable;
map<string, variable> memory;

extern FILE *yyin;
extern int yylineno;

int yylex();
void yyerror(const char *message);

void printOutputCode(vector<string> *commands);
void newVariable(string name, bool isArray, long long minIndex, long long maxIndex, bool  isIterator, int currentLine);
void deleteVariable(string name);

vector<string> *generateNumber(long long number);
vector<string> *generateNumberInRegisterA(long long number);
vector<string> *readNumber(identifierContainer *identifier);
vector<string> *add(vector<string> *first, vector<string> *second);
vector<string> *subtract(vector<string> *first, vector<string> *second);
vector<string> *multiply(vector<string> *first, vector<string> *second);
vector<string> *divide(vector<string> *first, vector<string> *second);
vector<string> *modulo(vector<string> *first, vector<string> *second);

conditionContainer *equal(vector<string> *first, vector<string> *second);
conditionContainer *notEqual(vector<string> *first, vector<string> *second);
conditionContainer *lessThan(vector<string> *first, vector<string> *second);
conditionContainer *lessOrEqual(vector<string> *first, vector<string> *second);
conditionContainer *greaterThan(vector<string> *first, vector<string> *second);
conditionContainer *greaterOrEqual(vector<string> *first, vector<string> *second);

vector<string> *createIf(conditionContainer *condition, vector<string> *commands);
vector<string> *createIfElse(conditionContainer *condition, vector<string> *ifCommands, vector<string> *elseCommands);
vector<string> *createWhile(conditionContainer *condition, vector<string> *commands, long long inLoopLabel);
vector<string> *createDoWhile(conditionContainer *condition, vector<string> *commands, long long inLoopLabel);
vector<string> *createFor(string *name, vector<string> *from, vector<string> *to, vector<string> *commands, long long inLoopLabel, long long loopIndex);
vector<string> *createForDownto(string *name, vector<string> *from, vector<string> *to, vector<string> *commands, long long inLoopLabel, long long loopIndex);
vector<string> *storeValueInMemory(identifierContainer *identifier, vector<string> *expression);

%}

%union{
	std::string *pidentifier;
	std::vector<std::string> *str_vec;
	void *idContainer;
	void *condContainer;
	long long num;
}

%type <str_vec> program value commands command expression
%type <condContainer> condition
%type <idContainer> identifier

%token <pidentifier> PIDENTIFIER
%token <num> NUM
%token DECLARE IN END
%token READ WRITE
%token IF THEN ELSE ENDIF
%token FOR FROM TO DOWNTO ENDFOR
%token WHILE DO ENDWHILE ENDDO
%token EQ NEQ GE LE GEQ LEQ
%token ERROR
%token SEM COL LPA RPA ASGN
%token ADD SUB MUL DIV MOD

%%


program:
	DECLARE declarations IN commands END			{
														$4->push_back("HALT");
														printOutputCode($4);
													}
;

declarations:
	declarations PIDENTIFIER SEM					{
														newVariable(*$2, false, 1, 1, false, yylineno);
													}
|	declarations PIDENTIFIER LPA NUM COL NUM RPA SEM
													{
														newVariable(*$2, true, $4, $6, false, yylineno);
													}
|
;

commands:
	commands command								{
									    				$$ = $1;
														$$->insert($$->end(), $2->begin(), $2->end());
													}
|	command											{
														$$ = $1;
													}
;

command:
	identifier ASGN expression SEM					{
														identifierContainer *identifier = (identifierContainer*) $1;
														memory[identifier->variableName].initialized = true;

														if(identifier->isIterator == true)
														{
															yyerror(("Line " + to_string(yylineno) + ": Loop iterator cannot be modified inside the loop.").c_str());
															YYERROR;
														}

														$$ = storeValueInMemory((identifierContainer*) identifier, $3);
													}
|	IF condition THEN commands ELSE commands ENDIF	{
														$$ = createIfElse((conditionContainer*) $2, $4, $6);
													}
|	IF condition THEN commands ENDIF				{
														$$ = createIf((conditionContainer*) $2, $4);
													}
|	WHILE condition									{
														$<num>$ = currentLabel; currentLabel+=2;
													}
	DO commands ENDWHILE							{
														$$ = createWhile((conditionContainer*) $2, $5, $<num>3);
													}
|	DO commands	WHILE condition ENDDO							{
														long long tmp = currentLabel;
														currentLabel++;
														$$ = createDoWhile((conditionContainer*) $4, $2, tmp);
													}
|	FOR PIDENTIFIER FROM value TO value DO 			{
														$<num>$ = currentLabel;
														currentLabel +=2;
													}
													{
														newVariable(*$2, false, 1, 1, true, yylineno);
														memory[*$2].initialized = true;
														$<num>$ = index;
														index += 2;
													}
commands ENDFOR
													{
														index -= 2;
														$$ = createFor($2, $4, $6, $10, $<num>8, $<num>9);
														deleteVariable(*$2);
													}
|	FOR PIDENTIFIER FROM value DOWNTO value DO		{
														$<num>$ = currentLabel;
														currentLabel +=2;
													}
													{
														newVariable(*$2, false, 1, 1, true, yylineno);
														memory[*$2].initialized = true;
														$<num>$ = index;
														index += 2;
													}
	commands ENDFOR									{
														index -= 2;
														$$ = createForDownto($2, $4, $6, $10, $<num>8, $<num>9);
														deleteVariable(*$2);
													}
|	READ identifier SEM								{
														identifierContainer *identifier = (identifierContainer*) $2;

														if(identifier->isIterator == true)
														{
															yyerror(("Line " + to_string(yylineno) + ": Loop iterator cannot be modified inside the loop.").c_str());
															YYERROR;
														}

														auto commands = readNumber(identifier);
														memory[identifier->variableName].initialized = true;
														$$ = commands;
													}
|	WRITE value SEM									{
														auto commands = $2;
														commands->push_back("PUT B");
														$$ = commands;
													}
;

expression:
	value											{
														$$ = $1;
													}
|	value ADD value									{
														$$ = add($1, $3);
													}
|	value SUB value									{
														$$ = subtract($1, $3);
													}
|	value MUL value									{
														$$ = multiply($1, $3);	
													}
|	value DIV value									{
														$$ = divide($1, $3);
													}
|	value MOD value									{
														$$ = modulo($1, $3);
													}
;

condition:
	value EQ value									{
														$$ = equal($1, $3);
													}
|	value NEQ value									{
														$$ = notEqual($1, $3);
													}
|	value LE value									{
														$$ = lessThan($1, $3);
													}
|	value GE value									{
														$$ = greaterThan($1, $3);
													}
|	value LEQ value									{
														$$ = lessOrEqual($1, $3);
													}
|	value GEQ value									{
														$$ = greaterOrEqual($1, $3);
													}
;

value:
	NUM												{
														auto number = generateNumber($1);
														$$ = number;
													}
|	identifier										{
														vector<string> *commands = new vector<string>();
														auto identifier = (identifierContainer*)$1;

														if(!memory[identifier->variableName].initialized)
														{
															yyerror(("Line " + to_string(yylineno) + ": Variable \'" + identifier->variableName + "\' not initialized.").c_str());
															YYERROR;
														}

														if (identifier->index < 0)
														{
															commands->insert(commands->begin(), identifier->commands->begin(), identifier->commands->end());
															commands->push_back("COPY A B");
															commands->push_back("LOAD B");
														}
														else
														{
															auto memoryNumInA = generateNumberInRegisterA(identifier->index);
															commands->insert(commands->begin(), memoryNumInA->begin(), memoryNumInA->end());
															commands->push_back("LOAD B");
														}
														$$ = commands;
													}
;

identifier:
	PIDENTIFIER										{
														map<string, variable>::iterator it = memory.find(*$1);

														if(it == memory.end())
														{
															yyerror(("Line " + to_string(yylineno) + ": Variable \'" + *$1 + "\' not declared.").c_str());
															YYERROR;
														}

														if(memory[*$1].isArray)
														{
															yyerror(("Line " + to_string(yylineno) + ": Accessing array \'" + *$1 + "\' as a variable.").c_str());
															YYERROR;
														}

														identifierContainer *identifier = new identifierContainer();
														identifier->index = memory[*$1].address;
														identifier->isIterator = memory[*$1].isIterator;
														identifier->variableName = *$1;
										 				$$ = identifier;
													}
|	PIDENTIFIER LPA NUM RPA							{
														map<string, variable>::iterator it = memory.find(*$1);
														if(it == memory.end())
														{
															yyerror(("Line " + to_string(yylineno) + ": Array \'" + *$1 + "\' not declared.").c_str());
															YYERROR;
														}

														if(!memory[*$1].isArray)
														{
															yyerror(("Line " + to_string(yylineno) + ": Accessing variable \'" + *$1 + "\' as an array.").c_str());
															YYERROR;
														}

														if(memory[*$1].minIndex > $3 || memory[*$1].maxIndex < $3)
														{
															yyerror(("Line " + to_string(yylineno) + ": Array \'" + *$1 + "\' index out of bounds.").c_str());
															YYERROR;
														}

														identifierContainer *identifier = new identifierContainer();
														identifier->index = memory[*$1].address + $3 - memory[*$1].minIndex;
														identifier->isIterator = memory[*$1].isIterator;
														identifier->variableName = *$1;
										 				$$ = identifier;
													}
|	PIDENTIFIER LPA PIDENTIFIER RPA					{
														map<string, variable>::iterator it = memory.find(*$1);
														map<string, variable>::iterator it1 = memory.find(*$3);
														if(it == memory.end())
														{
															yyerror(("Line " + to_string(yylineno) + ": Array \'" + *$1 + "\' not declared.").c_str());
															YYERROR;
														}

														if(it1 == memory.end())
														{
															yyerror(("Line " + to_string(yylineno) + ": Variable \'" + *$3 + "\' not declared.").c_str());
															YYERROR;
														}

														if(!memory[*$1].isArray)
														{
															yyerror(("Line " + to_string(yylineno) + ": Accessing variable \'" + *$1 + "\' as an array.").c_str());
															YYERROR;
														}

														identifierContainer *identifier = new identifierContainer();
														identifier->index = -1;
														vector<string> *commands = new vector<string>();

														auto tmp = generateNumber(memory[*$1].minIndex);
														tmp->push_back("COPY D B");
														commands->insert(commands->end(), tmp->begin(), tmp->end());

														tmp = generateNumber(memory[*$1].address);
														commands->insert(commands->end(), tmp->begin(), tmp->end());

														tmp = generateNumberInRegisterA(memory[*$3].address);
														commands->insert(commands->end(), tmp->begin(), tmp->end());

														commands->push_back("LOAD A");
														commands->push_back("SUB A D");
														commands->push_back("ADD B A");

														identifier->commands = commands;
														identifier->isIterator = memory[*$1].isIterator;
														identifier->variableName = *$1;
														$$ = identifier;
													}
;

%%

void printOutputCode(vector<string> *commands)
{
	map<string, int> labels;

	for(int i = 0; i < commands->size(); i++) {
		if ((*commands)[i].substr(0, 5) == "LABEL") {
			labels[(*commands)[i].substr(6)] = i;
		}
	}

	for(int i = 0; i < commands->size(); i++)
	{
		if((*commands)[i].substr(0, 4) == "JUMP")
		{
			(*commands)[i] = "JUMP " + to_string(labels[(*commands)[i].substr(5)]);
		}
		else if((*commands)[i].substr(0, 5) == "JZERO")
		{
			(*commands)[i] = (*commands)[i].substr(0, 8) + to_string(labels[(*commands)[i].substr(8)]);

		}
		else if((*commands)[i].substr(0, 4) == "JODD")
		{
			(*commands)[i] = (*commands)[i].substr(0, 6) + to_string(labels[(*commands)[i].substr(7)]);
		}
	}

	for(int i = 0; i < commands->size(); i++)
	{
		if((*commands)[i].substr(0, 5) == "LABEL")
		{
			(*commands)[i] = "JUMP " + to_string(i + 1);
		}
	}

	ofstream resultFile;
	resultFile.open(outputFile);

	for(int i = 0; i < commands->size(); i++)
	{
		resultFile<<(*commands)[i]<<endl;
	}

	resultFile.close();
}

int main(int argc, char *argv[])
{
	if(argc != 3)
	{
		cout<<"Write "<<argv[0]<<" <input_file> <output_file>"<<endl;
		return 0;
	}

	yyin = fopen(argv[1], "r");
	outputFile = argv[2];
	yyparse();
	return 0;
}

void yyerror(const char *message)
{
	cout<<message<<endl;
}

void newVariable(string name, bool isArray, long long minIndex, long long maxIndex, bool isIterator, int currentLine)
{
	map<string, variable>::iterator it = memory.find(name);
	if(it != memory.end())
	{
		yyerror(("Line " + to_string(yylineno) + ": Variable \'" + name + "\' previosly declared.").c_str());
		exit(0);
	}

	if(isArray && minIndex > maxIndex)
	{
		yyerror(("Line " + to_string(yylineno) + ": Array \'" + name + "\' with first index greater than the second.").c_str());
		exit(0);
	}

	long long size = maxIndex - minIndex + 1;
	variable var;

	if(isArray)
	{
		var = {index, size, isArray, true, minIndex, maxIndex, isIterator};
	}
	else
	{
		var = {index, size, isArray, false, minIndex, maxIndex, isIterator};
	}

	index += size;
	memory[name] = var;
}

void deleteVariable(string name)
{
	index -= memory[name].size;
	memory.erase(name);
}

vector<string> *generateNumber(long long number)
{
	vector<string> *commands = new vector<string>();
	vector<int> binary;

	while(number != 0)
	{
		binary.push_back(number % 2);
		number /= 2;
	}

	commands->push_back("SUB B B");

	for(int i = binary.size() - 1; i >= 0; i--)
	{
		if(binary[i] == 1)
		{
			commands->push_back("INC B");
		}

		if(i != 0)
		{
			commands->push_back("ADD B B");
		}
	}

	return commands;
}

vector<string> *generateNumberInRegisterA(long long number)
{
	vector<string> *commands = new vector<string>();
	vector<int> binary;

	while(number != 0)
	{
		binary.push_back(number % 2);
		number /= 2;
	}

	commands->push_back("SUB A A");

	for(int i = binary.size() - 1; i >= 0; i--)
	{
		if(binary[i] == 1)
		{
			commands->push_back("INC A");
		}

		if(i != 0)
		{
			commands->push_back("ADD A A");
		}
	}

	return commands;
}

vector<string> *readNumber(identifierContainer *identifier)
{
	vector<string> *commands = new vector<string>();
	if (identifier->index < 0) {
		commands->insert(commands->begin(), identifier->commands->begin(), identifier->commands->end());
		commands->push_back("COPY A B");
		commands->push_back("GET B");
		commands->push_back("STORE B");
	} else {
		auto memoryNumInA = generateNumberInRegisterA(identifier->index);
		commands->insert(commands->begin(), memoryNumInA->begin(), memoryNumInA->end());
		commands->push_back("GET B");
		commands->push_back("STORE B");
	}
	return commands;
}

vector<string> *add(vector<string> *first, vector<string> *second)
{
	vector<string> *commands = new vector<string>();
	commands->insert(commands->end(), second->begin(), second->end());
	commands->push_back("COPY C B");
	commands->insert(commands->end(), first->begin(), first->end());
	commands->push_back("ADD B C");

	return commands;
}

vector<string> *subtract(vector<string> *first, vector<string> *second)
{
	vector<string> *commands = new vector<string>();
	commands->insert(commands->end(), second->begin(), second->end());
	commands->push_back("COPY C B");
	commands->insert(commands->end(), first->begin(), first->end());
	commands->push_back("SUB B C");

	return commands;
}

vector<string> *multiply(vector<string> *first, vector<string> *second)
{
	vector<string> *commands = new vector<string>();
	commands->push_back("SUB E E");
	commands->insert(commands->end(), second->begin(), second->end());
	commands->push_back("COPY C B");
	commands->push_back("JZERO C " + to_string(currentLabel));
	commands->insert(commands->end(), first->begin(), first->end());
	commands->push_back("COPY D B");

	commands->push_back("LABEL " + to_string(currentLabel + 1));
	commands->push_back("JZERO D " + to_string(currentLabel));
	commands->push_back("JODD D " + to_string(currentLabel + 3));
	commands->push_back("JUMP " + to_string(currentLabel + 2));
	commands->push_back("LABEL " + to_string(currentLabel + 3));
	commands->push_back("ADD E C");
	commands->push_back("LABEL " + to_string(currentLabel + 2));
	commands->push_back("ADD C C");
	commands->push_back("HALF D");
	commands->push_back("JUMP " + to_string(currentLabel + 1));
	commands->push_back("LABEL " + to_string(currentLabel));
	commands->push_back("COPY B E");
	currentLabel += 4;

	return commands;
}

vector<string> *divide(vector<string> *first, vector<string> *second)
{
	vector<string> *commands = new vector<string>();
	commands->push_back("SUB E E");
	commands->push_back("SUB F F");
	commands->push_back("INC F");
	commands->insert(commands->end(), first->begin(), first->end());
	commands->push_back("COPY C B");
	commands->insert(commands->end(), second->begin(), second->end());
	commands->push_back("COPY D B");
	commands->push_back("JZERO C " + to_string(currentLabel));
	commands->push_back("JZERO D " + to_string(currentLabel + 1));

	commands->push_back("LABEL " + to_string(currentLabel + 4));
	commands->push_back("COPY G C");
	commands->push_back("SUB G D");
	commands->push_back("JZERO G " + to_string(currentLabel + 2));
	commands->push_back("ADD D D");
	commands->push_back("ADD F F");
	commands->push_back("JUMP " + to_string(currentLabel + 4));

	commands->push_back("LABEL " + to_string(currentLabel + 2));
	commands->push_back("COPY G C");
	commands->push_back("INC G");
	commands->push_back("SUB G D");
	commands->push_back("JZERO G " + to_string(currentLabel + 3));
	commands->push_back("SUB C D");
	commands->push_back("ADD E F");

	commands->push_back("LABEL " + to_string(currentLabel + 3));
	commands->push_back("HALF D");
	commands->push_back("HALF F");

	commands->push_back("JZERO F " + to_string(currentLabel));
	commands->push_back("JUMP " + to_string(currentLabel + 2));
	commands->push_back("LABEL " + to_string(currentLabel + 1));
	commands->push_back("SUB C C");
	commands->push_back("LABEL " + to_string(currentLabel));
	commands->push_back("COPY B E");
	currentLabel += 5;

	return commands;
}

vector<string> *modulo(vector<string> *first, vector<string> *second)
{
	vector<string> *commands = new vector<string>();
	commands->push_back("SUB E E");
	commands->push_back("SUB F F");
	commands->push_back("INC F");
	commands->insert(commands->end(), first->begin(), first->end());
	commands->push_back("COPY C B");
	commands->insert(commands->end(), second->begin(), second->end());
	commands->push_back("COPY D B");
	commands->push_back("JZERO C " + to_string(currentLabel));
	commands->push_back("JZERO D " + to_string(currentLabel + 1));

	commands->push_back("LABEL " + to_string(currentLabel + 4));
	commands->push_back("COPY G C");
	commands->push_back("SUB G D");
	commands->push_back("JZERO G " + to_string(currentLabel + 2));
	commands->push_back("ADD D D");
	commands->push_back("ADD F F");
	commands->push_back("JUMP " + to_string(currentLabel + 4));

	commands->push_back("LABEL " + to_string(currentLabel + 2));
	commands->push_back("COPY G C");
	commands->push_back("INC G");
	commands->push_back("SUB G D");
	commands->push_back("JZERO G " + to_string(currentLabel + 3));
	commands->push_back("SUB C D");
	commands->push_back("ADD E F");

	commands->push_back("LABEL " + to_string(currentLabel + 3));
	commands->push_back("HALF D");
	commands->push_back("HALF F");

	commands->push_back("JZERO F " + to_string(currentLabel));
	commands->push_back("JUMP " + to_string(currentLabel + 2));
	commands->push_back("LABEL " + to_string(currentLabel + 1));
	commands->push_back("SUB C C");
	commands->push_back("LABEL " + to_string(currentLabel));
	commands->push_back("COPY B C");
	currentLabel += 5;

	return commands;
}

conditionContainer *equal(vector<string> *first, vector<string> *second)
{
	vector<string> *commands = new vector<string>();

	commands->insert(commands->begin(), second->begin(), second->end());
	commands->push_back("COPY C B");

	commands->insert(commands->end(), first->begin(), first->end());
	commands->push_back("INC B");
	commands->push_back("SUB B C");
	commands->push_back("JZERO B " + to_string(currentLabel));
	commands->push_back("DEC B");
	commands->push_back("JZERO B " + to_string(currentLabel + 1));
	commands->push_back("JUMP " + to_string(currentLabel));
	commands->push_back("LABEL " + to_string(currentLabel + 1));

	conditionContainer *condition = new conditionContainer();
	condition->commands = commands;
	condition->index = currentLabel;
	currentLabel += 2;

	return condition;
}

conditionContainer *notEqual(vector<string> *first, vector<string> *second)
{
	vector<string> *commands = new vector<string>();

	commands->insert(commands->begin(), second->begin(), second->end());
	commands->push_back("COPY C B");

	commands->insert(commands->end(), first->begin(), first->end());
	commands->push_back("INC B");
	commands->push_back("SUB B C");
	commands->push_back("JZERO B " + to_string(currentLabel + 1));
	commands->push_back("DEC B");
	commands->push_back("JZERO B " + to_string(currentLabel));
	commands->push_back("LABEL " + to_string(currentLabel + 1));

	conditionContainer *condition = new conditionContainer();
	condition->commands = commands;
	condition->index = currentLabel;
	currentLabel += 2;

	return condition;
}

conditionContainer *lessThan(vector<string> *first, vector<string> *second)
{
	vector<string> *commands = new vector<string>();

	commands->insert(commands->begin(), first->begin(), first->end());
	commands->push_back("COPY C B");
	commands->insert(commands->end(), second->begin(), second->end());
	commands->push_back("SUB B C");
	commands->push_back("JZERO B " + to_string(currentLabel));

	conditionContainer *condition = new conditionContainer();
	condition->commands = commands;
	condition->index = currentLabel;
	currentLabel++;

	return condition;
}

conditionContainer *lessOrEqual(vector<string> *first, vector<string> *second)
{
	vector<string> *commands = new vector<string>();

	commands->insert(commands->begin(), first->begin(), first->end());
	commands->push_back("COPY C B");
	commands->insert(commands->end(), second->begin(), second->end());
	commands->push_back("INC B");
	commands->push_back("SUB B C");
	commands->push_back("JZERO B " + to_string(currentLabel));

	conditionContainer *condition = new conditionContainer();
	condition->commands = commands;
	condition->index = currentLabel;
	currentLabel++;

	return condition;
}

conditionContainer *greaterThan(vector<string> *first, vector<string> *second)
{
	vector<string> *commands = new vector<string>();

	commands->insert(commands->begin(), second->begin(), second->end());
	commands->push_back("COPY C B");
	commands->insert(commands->end(), first->begin(), first->end());
	commands->push_back("SUB B C");
	commands->push_back("JZERO B " + to_string(currentLabel));

	conditionContainer *condition = new conditionContainer();
	condition->commands = commands;
	condition->index = currentLabel;
	currentLabel++;

	return condition;
}

conditionContainer *greaterOrEqual(vector<string> *first, vector<string> *second)
{
	vector<string> *commands = new vector<string>();

	commands->insert(commands->begin(), second->begin(), second->end());
	commands->push_back("COPY C B");
	commands->insert(commands->end(), first->begin(), first->end());
	commands->push_back("INC B");
	commands->push_back("SUB B C");
	commands->push_back("JZERO B " + to_string(currentLabel));

	conditionContainer *condition = new conditionContainer();
	condition->commands = commands;
	condition->index = currentLabel;
	currentLabel++;

	return condition;
}

vector<string> *createIf(conditionContainer *condition, vector<string> *commands)
{
	vector<string> *resultCommands = new vector<string>();

	resultCommands->insert(resultCommands->end(), condition->commands->begin(), condition->commands->end());
	resultCommands->insert(resultCommands->end(), commands->begin(), commands->end());
	resultCommands->push_back("LABEL " + to_string(condition->index));

	return resultCommands;
}

vector<string> *createIfElse(conditionContainer *condition, vector<string> *ifCommands, vector<string> *elseCommands)
{
	vector<string> *commands = new vector<string>();

	commands->insert(commands->end(), condition->commands->begin(), condition->commands->end());
	commands->insert(commands->end(), ifCommands->begin(), ifCommands->end());
	commands->push_back("JUMP " + to_string(currentLabel + 1));
	commands->push_back("LABEL " + to_string(condition->index));
	commands->insert(commands->end(), elseCommands->begin(), elseCommands->end());
	commands->push_back("LABEL " + to_string(currentLabel + 1));
	currentLabel += 2;

	return commands;
}

vector<string> *createWhile(conditionContainer *condition, vector<string> *commands, long long inLoopLabel)
{
	vector<string> *resultCommands = new vector<string>();

	resultCommands->push_back("LABEL " + to_string(inLoopLabel + 1));
	resultCommands->insert(resultCommands->end(), condition->commands->begin(), condition->commands->end());
	resultCommands->insert(resultCommands->end(), commands->begin(), commands->end());
	resultCommands->push_back("JUMP " + to_string(inLoopLabel + 1));
	resultCommands->push_back("LABEL " + to_string(condition->index));

	return resultCommands;
}

vector<string> *createDoWhile(conditionContainer *condition, vector<string> *commands, long long inLoopLabel)
{
	vector<string> *resultCommands = new vector<string>();

	resultCommands->push_back("LABEL " + to_string(inLoopLabel));
	resultCommands->insert(resultCommands->end(), commands->begin(), commands->end());
	resultCommands->insert(resultCommands->end(), condition->commands->begin(), condition->commands->end());
	resultCommands->push_back("JUMP " + to_string(inLoopLabel));
	resultCommands->push_back("LABEL " + to_string(condition->index));

	return resultCommands;
}

vector<string> *createFor(string *name, vector<string> *from, vector<string> *to, vector<string> *commands, long long inLoopLabel, long long loopIndex)
{
	vector<string> *resultCommands = new vector<string>();
	long long loopIterator = memory[*name].address;

	resultCommands->insert(resultCommands->end(), to->begin(), to->end());
	auto memoryNumInA = generateNumberInRegisterA(loopIndex);
	resultCommands->insert(resultCommands->end(), memoryNumInA->begin(), memoryNumInA->end());
	resultCommands->push_back("STORE B");

	resultCommands->insert(resultCommands->end(), from->begin(), from->end());
	memoryNumInA = generateNumberInRegisterA(loopIterator);
	resultCommands->insert(resultCommands->end(), memoryNumInA->begin(), memoryNumInA->end());
	resultCommands->push_back("STORE B");

	resultCommands->push_back("LABEL " + to_string(inLoopLabel + 1));
	memoryNumInA = generateNumberInRegisterA(loopIndex);
	resultCommands->insert(resultCommands->end(), memoryNumInA->begin(), memoryNumInA->end());
	resultCommands->push_back("LOAD B");
	resultCommands->push_back("INC B");
	memoryNumInA = generateNumberInRegisterA(loopIterator);
	resultCommands->insert(resultCommands->end(), memoryNumInA->begin(), memoryNumInA->end());
	resultCommands->push_back("LOAD C");
	resultCommands->push_back("SUB B C");
	resultCommands->push_back("JZERO B " + to_string(inLoopLabel));

	resultCommands->insert(resultCommands->end(), commands->begin(), commands->end());

	memoryNumInA = generateNumberInRegisterA(loopIterator);
	resultCommands->insert(resultCommands->end(), memoryNumInA->begin(), memoryNumInA->end());
	resultCommands->push_back("LOAD B");
	resultCommands->push_back("INC B");
	resultCommands->push_back("STORE B");
	resultCommands->push_back("JUMP " + to_string(inLoopLabel + 1));
	resultCommands->push_back("LABEL " + to_string(inLoopLabel));

	return resultCommands;
}

vector<string> *createForDownto(string *name, vector<string> *from, vector<string> *to, vector<string> *commands, long long inLoopLabel, long long loopIndex)
{
	vector<string> *resultCommands = new vector<string>();
	long long loopIterator = memory[*name].address;
	long long counter = loopIndex + 1;

	resultCommands->insert(resultCommands->end(), to->begin(), to->end());
	auto memoryNumInA = generateNumberInRegisterA(loopIndex);
	resultCommands->insert(resultCommands->end(), memoryNumInA->begin(), memoryNumInA->end());
	resultCommands->push_back("STORE B");
	resultCommands->push_back("COPY C B");

	resultCommands->insert(resultCommands->end(), from->begin(), from->end());
	memoryNumInA = generateNumberInRegisterA(loopIterator);
	resultCommands->insert(resultCommands->end(), memoryNumInA->begin(), memoryNumInA->end());
	resultCommands->push_back("STORE B");

	resultCommands->push_back("SUB B C");
	resultCommands->push_back("INC B");
	memoryNumInA = generateNumberInRegisterA(counter);
	resultCommands->insert(resultCommands->end(), memoryNumInA->begin(), memoryNumInA->end());
	resultCommands->push_back("STORE B");

	resultCommands->push_back("LABEL " + to_string(inLoopLabel + 1));
	memoryNumInA = generateNumberInRegisterA(counter);
	resultCommands->insert(resultCommands->end(), memoryNumInA->begin(), memoryNumInA->end());
	resultCommands->push_back("LOAD B");
	resultCommands->push_back("JZERO B " + to_string(inLoopLabel));

	resultCommands->insert(resultCommands->end(), commands->begin(), commands->end());

	memoryNumInA = generateNumberInRegisterA(loopIterator);
	resultCommands->insert(resultCommands->end(), memoryNumInA->begin(), memoryNumInA->end());
	resultCommands->push_back("LOAD B");
	resultCommands->push_back("DEC B");
	resultCommands->push_back("STORE B");

	memoryNumInA = generateNumberInRegisterA(counter);
	resultCommands->insert(resultCommands->end(), memoryNumInA->begin(), memoryNumInA->end());
	resultCommands->push_back("LOAD B");
	resultCommands->push_back("DEC B");
	resultCommands->push_back("STORE B");

	resultCommands->push_back("JUMP " + to_string(inLoopLabel + 1));
	resultCommands->push_back("LABEL " + to_string(inLoopLabel));

	return resultCommands;
}

vector<string> *storeValueInMemory(identifierContainer *identifier, vector<string> *expression)
{
	vector<string> *commands = new vector<string>();
	commands->insert(commands->end(), expression->begin(), expression->end());
	commands->push_back("COPY C B");

	if(identifier->index < 0)
	{
		commands->insert(commands->end(), identifier->commands->begin(), identifier->commands->end());
		commands->push_back("COPY A B");
	}
	else
	{
		auto memoryNumInA = generateNumberInRegisterA(identifier->index);
		commands->insert(commands->end(), memoryNumInA->begin(), memoryNumInA->end());
	}
	
	commands->push_back("STORE C");

	return commands;
}