%option noyywrap
%option yylineno
%{
	#include <iostream>
	#include <string>
	#include <vector>

	#include "parser.tab.h"
%}

%x COMMENT

%%

"["				BEGIN(COMMENT);
<COMMENT>{
	"]"			BEGIN(INITIAL);
	[ \t\r\n]+	;
	.			;
}

"DECLARE"	{return DECLARE;}
"IN"		{return IN;}
"END"		{return END;}

"WRITE"		{return WRITE;}
"READ"		{return READ;}

"IF"		{return IF;}
"THEN"		{return THEN;}
"ELSE"		{return ELSE;}
"ENDIF"		{return ENDIF;}
"WHILE"		{return WHILE;}
"DO"		{return DO;}
"ENDWHILE"	{return ENDWHILE;}
"ENDDO"		{return ENDDO;}
"FOR"		{return FOR;}
"FROM"		{return FROM;}
"TO"		{return TO;}
"DOWNTO"	{return DOWNTO;}
"ENDFOR"	{return ENDFOR;}


"+"			{return ADD;}
"-"			{return SUB;}
"*"			{return MUL;}
"/"			{return DIV;}
"%"			{return MOD;}
"("			{return LPA;}
")"			{return RPA;}
":="		{return ASGN;}
"="			{return EQ;}
"!="		{return NEQ;}
"<"			{return LE;}
">"			{return GE;}
"<="		{return LEQ;}
">="		{return GEQ;}
";"			{return SEM;}
":"			{return COL;}

[_a-z]+		{yylval.pidentifier = new std::string(yytext);
			 return PIDENTIFIER;}
[0-9]+		{yylval.num = atoll(yytext);
			 return NUM;}
[ \t\r\n]+	{;}
.			{return ERROR;}

%%