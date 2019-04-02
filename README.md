#Compiler
Compiler of simple imperative language to register machine code. File `lexer.l` contains lexer and `parser.y` the parser and functions that generate result code.

#How to run
In order to compile sources run `make` command (uses `g++`, `bison`, `flex`) and the run the compiler with a command:
`./kompilator <file_in> <file_out>`

If you want to run result code, go to `register-machine` directory, run `make` (requires `cln` library) and `./maszyna-rejestrowa <your_file>`.