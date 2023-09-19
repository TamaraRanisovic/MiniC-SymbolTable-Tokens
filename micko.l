%option noyywrap yylineno
%{
   #include <string.h>
   #include "micko.tab.h"
   #include "defs.h"
   extern YYSTYPE yylval;
   
%}

%%

[ \t\n]+             { /* skip */ }

"int"                { fprintf(yyout, "INT\n"); yylval.i = INT; return _TYPE;  }
"unsigned"           { fprintf(yyout, "UINT\n"); yylval.i = UINT; return _TYPE;  }
"if"                 { fprintf(yyout, "_IF\n"); return _IF; }
"else"               { fprintf(yyout, "_ELSE\n"); return _ELSE; }
"return"             { fprintf(yyout, "_RETURN\n"); return _RETURN; }
"branch"			 { fprintf(yyout, "_BRANCH\n"); return _BRANCH; }
"first"				 { fprintf(yyout, "_FIRST\n"); return _FIRST; }
"second"			 { fprintf(yyout, "_SECOND\n"); return _SECOND; }
"third"				 { fprintf(yyout, "_THIRD\n"); return _THIRD; }
"otherwise"			 { fprintf(yyout, "_OTHERWISE\n"); return _OTHERWISE; }
","					 { fprintf(yyout, "_COMMA\n"); return _COMMA; }

"iterate"			 { fprintf(yyout, "_ITERATE\n"); return _ITERATE; }
"to"				 { fprintf(yyout, "_TO\n"); return _TO; }

"for"				 { fprintf(yyout, "_FOR\n"); return _FOR; }
"++"				 { fprintf(yyout, "_POSTINC\n"); return _POSTINC; }

"?"					 { fprintf(yyout, "_QMARK\n"); return _QMARK; }

"switch"			 { fprintf(yyout, "_SWITCH\n"); return _SWITCH; }
"case"				 { fprintf(yyout, "_CASE\n"); return _CASE; }
"break"				 { fprintf(yyout, "_BREAK\n"); return _BREAK; }
"default"			 { fprintf(yyout, "_DEFAULT\n"); return _DEFAULT; }
":"					 { fprintf(yyout, "_COLON\n"); return _COLON; }

"("                  { fprintf(yyout, "_LPAREN\n"); return _LPAREN; }
")"                  { fprintf(yyout, "_RPAREN\n"); return _RPAREN; }
"{"                  { fprintf(yyout, "_LBRACKET\n"); return _LBRACKET; }
"}"                  { fprintf(yyout, "_RBRACKET\n"); return _RBRACKET; }
";"                  { fprintf(yyout, "_SEMICOLON\n"); return _SEMICOLON; }
"="                  { fprintf(yyout, "_ASSIGN\n"); return _ASSIGN; }

"+"                  { fprintf(yyout, "ADD\n"); yylval.i = ADD; return _AROP; }
"-"                  { fprintf(yyout, "SUB\n"); yylval.i = SUB; return _AROP; }

"<"                  { fprintf(yyout, "LT\n"); yylval.i = LT; return _RELOP; }
">"                  { fprintf(yyout, "GT\n"); yylval.i = GT; return _RELOP; }
"<="                 { fprintf(yyout, "LE\n"); yylval.i = LE; return _RELOP; }
">="                 { fprintf(yyout, "GE\n"); yylval.i = GE; return _RELOP; }
"=="                 { fprintf(yyout, "EQ\n"); yylval.i = EQ; return _RELOP; }
"!="                 { fprintf(yyout, "NE\n"); yylval.i = NE; return _RELOP; }

[a-zA-Z][a-zA-Z0-9]* { fprintf(yyout, "_ID\n"); yylval.s = strdup(yytext); 
                       return _ID; }
[+-]?[0-9]{1,10}     { fprintf(yyout, "_INT_NUMBER\n"); yylval.s = strdup(yytext); 
                       return _INT_NUMBER;}
[0-9]{1,10}[uU]      { fprintf(yyout, "_UINT_NUMBER\n"); yylval.s = strdup(yytext); 
                       yylval.s[yyleng-1] = 0;
                       return _UINT_NUMBER;}

\/\/.*               { /* skip */ }
.                    { printf("line %d: LEXICAL ERROR on char %c\n", yylineno, *yytext);}
%%
