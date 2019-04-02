all: compiler

parser: parser.y
	bison -t -d parser.y

lexer: lexer.l
	flex lexer.l

compiler: lexer parser
	g++ -std=c++11 -o kompilator lex.yy.c parser.tab.c

clean:
	rm -f lex.yy.c parser.tab.h parser.tab.c kompilator