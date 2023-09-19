%{
  #include <stdio.h>
  #include <stdlib.h>
  #include "defs.h"
  #include "symtab.h"
  #include "codegen.h"
  #include <string.h>

  int yyparse(void);
  int yylex(void);
  int yyerror(char *s);
  void warning(char *s);

  extern int yylineno;
  int out_lin = 0;
  char char_buffer[CHAR_BUFFER_LENGTH];
  int error_count = 0;
  int warning_count = 0;
  int var_num = 0;
  int fun_idx = -1;
  int fcall_idx = -1;
  int lab_num = -1;
  FILE *output;
  
  int case_count = 0;
  int case_array[100];
  int switch_id = -1;
%}

%union {
  int i;
  char *s;
}

%token <i> _TYPE
%token _IF
%token _ELSE
%token _RETURN
%token <s> _ID
%token <s> _INT_NUMBER
%token <s> _UINT_NUMBER
%token _LPAREN
%token _RPAREN
%token _LBRACKET
%token _RBRACKET
%token _ASSIGN
%token _SEMICOLON
%token <i> _AROP
%token <i> _RELOP
%token _BRANCH
%token _FIRST
%token _SECOND
%token _THIRD
%token _OTHERWISE
%token _COMMA
%token _ITERATE
%token _TO
%token _SWITCH
%token _CASE
%token _BREAK
%token _DEFAULT
%token _COLON
%token _FOR
%token _POSTINC
%token _QMARK


%type <i> num_exp exp literal
%type <i> function_call argument rel_exp if_part
%type <i> default_statement
%type <i> cond_exp

%nonassoc ONLY_IF
%nonassoc _ELSE

%%

program
  : function_list
      {  
        if(lookup_symbol("main", FUN) == NO_INDEX)
          err("undefined reference to 'main'");
      }
  ;

function_list
  : function
  | function_list function
  ;

function
  : _TYPE _ID
      {
        fun_idx = lookup_symbol($2, FUN);
        if(fun_idx == NO_INDEX)
          fun_idx = insert_symbol($2, FUN, $1, NO_ATR, NO_ATR);
        else 
          err("redefinition of function '%s'", $2);

        code("\n%s:", $2);
        code("\n\t\tPUSH\t%%14");
        code("\n\t\tMOV \t%%15,%%14");
      }
    _LPAREN parameter _RPAREN body
      {
       // clear_symbols(fun_idx + 1);
        var_num = 0;
        
        code("\n@%s_exit:", $2);
        code("\n\t\tMOV \t%%14,%%15");
        code("\n\t\tPOP \t%%14");
        code("\n\t\tRET");
      }
  ;

parameter
  : /* empty */
      { set_atr1(fun_idx, 0); }

  | _TYPE _ID
      {
        insert_symbol($2, PAR, $1, 1, NO_ATR);
        set_atr1(fun_idx, 1);
        set_atr2(fun_idx, $1);
      }
  ;

body
  : _LBRACKET variable_list
      {
        if(var_num)
          code("\n\t\tSUBS\t%%15,$%d,%%15", 4*var_num);
        code("\n@%s_body:", get_name(fun_idx));
      }
    statement_list _RBRACKET
  ;

variable_list
  : /* empty */
  | variable_list variable
  ;

variable
  : _TYPE _ID _SEMICOLON
      {
        if(lookup_symbol($2, VAR|PAR) == NO_INDEX)
           insert_symbol($2, VAR, $1, ++var_num, NO_ATR);
        else 
           err("redefinition of '%s'", $2);
      }
  ;

statement_list
  : /* empty */
  | statement_list statement
  ;

statement
  : compound_statement
  | assignment_statement
  | if_statement
  | return_statement
  | branch_statement
  | iterate_statement
  | switch_statement
  | for_statement

  ;
  
branch_statement
  : _BRANCH _LPAREN _ID _SEMICOLON literal _COMMA literal _COMMA literal
    {
		int idx = lookup_symbol($3, VAR|PAR);
		if (idx == NO_INDEX) {
			err("'%s' undeclared", $3);
		}
		
		if (get_type(idx) != get_type($5) || get_type(idx) != get_type($7) || get_type(idx) != get_type($9)) {
			err("incompatible types...");
		}
		$<i>$ = ++lab_num;
	}
	_RPAREN _FIRST 
	{
		int idx = lookup_symbol($3, VAR|PAR);
		code("\n@first%d:", $<i>10);
		gen_cmp(idx, $5);
		code("\n\t\tJNE \t@second%d", $<i>10);
	}
	statement
	{
		code("\n\t\tJMP \t@branch_end%d", $<i>10);
	}
	_SECOND
	{
		int idx = lookup_symbol($3, VAR|PAR);
		code("\n@second%d:", $<i>10);
		gen_cmp(idx, $7);
		code("\n\t\tJNE \t@third%d", $<i>10);
	}
	statement
	{
		code("\n\t\tJMP \t@branch_end%d", $<i>10);
	}
	_THIRD
	{
		int idx = lookup_symbol($3, VAR|PAR);
		code("\n@third%d:", $<i>10);
		gen_cmp(idx, $9);
		code("\n\t\tJNE \t@otherwise%d", $<i>10);
	}
	statement
	{
		code("\n\t\tJMP \t@branch_end%d", $<i>10);
	}
	_OTHERWISE
	{
		code("\n@otherwise%d:", $<i>10);
	}
	statement
	{
		code("\n@branch_end%d:", $<i>10);
	}
	;
iterate_statement
  : _ITERATE _ID 
    {
		int i = lookup_symbol($2, VAR|PAR);
		
		code("\n\t\tMOV \t$1, ");
		gen_sym_name(i);
		
		$<i>$ = ++lab_num;
		code("\n@iterate%d:", lab_num);
	}
	literal _TO literal
	{
		int i = lookup_symbol($2, VAR|PAR);
		
		gen_cmp(i, $6);
		if (get_type(i) == INT) {
			code("\n\t\tJGTS \t");
		} else {
			code("\n\t\tJGTU \t");
		}
		code("@iterator_end%d", $<i>3);
	}
	statement
	{
		int i = lookup_symbol($2, VAR|PAR);
		if (get_type(i) == INT) {
			code("\n\t\tADDS \t");
		} else {
			code("\n\t\tADDU \t");
		}
		gen_sym_name(i);
		code(",");
		gen_sym_name($4);
		code(",");
		gen_sym_name(i);
		
		code("\n\t\tJMP\t@iterate%d", $<i>3);
		code("\n@iterator_end%d:", $<i>3);
	}
	
  ;
  
switch_statement
  : _SWITCH _LPAREN _ID
	{
		if((switch_id = lookup_symbol($3, VAR)) == -1) {
			err("'%s' undeclared", $3);
		}
		lab_num ++;
		code("\n@switch%d:", lab_num);
		code("\n\t\tJMP \t@test%d", lab_num);
	}
	_RPAREN _LBRACKET case_statements default_statement _RBRACKET
	{
		code("\n\t\tJMP \t@exit%d", lab_num);
		code("\n@test%d:", lab_num);
		int i;
		for (i = 0; i < case_count; i ++) {
			gen_cmp(switch_id, case_array[i]);
			case_array[i] = 1;
			code("\n\t\tJEQ \t");
			code("@case%d_%d",  lab_num, i);
		}
		if ($8) {
			code("\n\t\tJMP \t@default%d", lab_num);
		}
		code("\n@exit%d:", lab_num);
		case_count = 0;
	}
  ;
  
case_statements
  : case_statement
  | case_statements case_statement
  ;
  
case_statement
  : _CASE literal _COLON
	{
		int i = 0;
		while (i < case_count) {
			if ($2 == case_array[i]) {
				err("duplicated constant in case");
				break;
			}
			i++;
		}
		if (i == case_count) {
			case_array[case_count] = $2;
			code("\n@case%d_%d:", lab_num, case_count);
			case_count++;
		}
		if (get_type($2) != get_type(switch_id)) {
			err("wrong type of constant");
		}
	}
	statement break_statement
  ;

break_statement
  : 
  | _BREAK _SEMICOLON
	{
		code("\n\t\tJMP \t@exit%d", lab_num);
	}
  ;
  
default_statement
  :
	{
		$$ = 0;
	}
  | _DEFAULT _COLON
    {
		code("\n@default%d:", lab_num);
	}
	statement
	{
		$$ = 1;
	}
  ;
  
for_statement
  : _FOR _LPAREN _ID
	{
		$<i>$ = lookup_symbol($3, VAR|PAR);
		if ($<i>$ == -1) {
			err("undeclared '%d'", $<i>$);
		}
	}
	{
		lab_num ++;
		$<i>$ = lab_num;
	}
  _ASSIGN literal
	{
		if (get_type($<i>4) != get_type($7)) {
			err("incompatible types");
		}
		gen_mov($7, $<i>4);
		code("\n@for%d:", lab_num);
	}
  _SEMICOLON rel_exp 
	{
		code("\n\t\t%s\t@exit%d", opp_jumps[$10], $<i>5);
	}
  _SEMICOLON _ID 
	{
		$<i>$ = lookup_symbol($13, VAR|PAR);
		if (get_type($<i>4) != get_type($<i>$)) {
			err("different ids");
		}
	}
  _POSTINC _RPAREN statement
	{
		if (get_type($<i>14) == INT) {
			code("\n\t\tADDS\t");
		} else {
			code("\n\t\tADDU\t");
		}
		gen_sym_name($<i>14);
		code(", $1,");
		gen_sym_name($<i>14);
		
		code("\n\t\tJMP\t@for%d", $<i>5);
		code("\n@exit%d:", $<i>5);
	}
  ;
  
  
compound_statement
  : _LBRACKET statement_list _RBRACKET
  ;

assignment_statement
  : _ID _ASSIGN num_exp _SEMICOLON
      {
        int idx = lookup_symbol($1, VAR|PAR);
        if(idx == NO_INDEX)
          err("invalid lvalue '%s' in assignment", $1);
        else
          if(get_type(idx) != get_type($3))
            err("incompatible types in assignment");
        gen_mov($3, idx);
      }
  ;

num_exp
  : exp

  | num_exp _AROP exp
      {
        if(get_type($1) != get_type($3))
          err("invalid operands: arithmetic operation");
        int t1 = get_type($1);    
        code("\n\t\t%s\t", ar_instructions[$2 + (t1 - 1) * AROP_NUMBER]);
        gen_sym_name($1);
        code(",");
        gen_sym_name($3);
        code(",");
        free_if_reg($3);
        free_if_reg($1);
        $$ = take_reg();
        gen_sym_name($$);
        set_type($$, t1);
      }
  ;

exp
  : literal

  | _ID
      {
        $$ = lookup_symbol($1, VAR|PAR);
        if($$ == NO_INDEX)
          err("'%s' undeclared", $1);
      }

  | function_call
      {
        $$ = take_reg();
        gen_mov(FUN_REG, $$);
      }
  
  | _LPAREN num_exp _RPAREN
      { $$ = $2; }
  | _LPAREN rel_exp _RPAREN _QMARK cond_exp _COLON cond_exp
    {
		int out = take_reg();
		lab_num++;
		if(get_type($5) != get_type($7)) {
			err("exp1 i exp2 nisu istog tipa");
		}
		
		code("\n\t\t%s\t@false%d", opp_jumps[$2],lab_num);
		code("\n@true%d:", lab_num);
		gen_mov($5, out);
		code("\n\t\tJMP \t@exit%d", lab_num);
		
		code("\n@false%d:", lab_num);
		gen_mov($7, out);
		
		code("\n@exit%d:", lab_num);
		
		$$ = out;
	}
  ;
  
cond_exp
  : _ID
	{
		if( ($$ = lookup_symbol($1, (VAR|PAR))) == NO_INDEX )
		err("'%s' undeclared", $1);
	}
  | literal
  ;
  
literal
  : _INT_NUMBER
      { $$ = insert_literal($1, INT); }

  | _UINT_NUMBER
      { $$ = insert_literal($1, UINT); }
  ;

function_call
  : _ID 
      {
        fcall_idx = lookup_symbol($1, FUN);
        if(fcall_idx == NO_INDEX)
          err("'%s' is not a function", $1);
      }
    _LPAREN argument _RPAREN
      {
        if(get_atr1(fcall_idx) != $4)
          err("wrong number of arguments");
        code("\n\t\t\tCALL\t%s", get_name(fcall_idx));
        if($4 > 0)
          code("\n\t\t\tADDS\t%%15,$%d,%%15", $4 * 4);
        set_type(FUN_REG, get_type(fcall_idx));
        $$ = FUN_REG;
      }
  ;

argument
  : /* empty */
    { $$ = 0; }

  | num_exp
    { 
      if(get_atr2(fcall_idx) != get_type($1))
        err("incompatible type for argument");
      free_if_reg($1);
      code("\n\t\t\tPUSH\t");
      gen_sym_name($1);
      $$ = 1;
    }
  ;

if_statement
  : if_part %prec ONLY_IF
      { code("\n@exit%d:", $1); }

  | if_part _ELSE statement
      { code("\n@exit%d:", $1); }
  ;

if_part
  : _IF _LPAREN
      {
        $<i>$ = ++lab_num;
        code("\n@if%d:", lab_num);
      }
    rel_exp
      {
        code("\n\t\t%s\t@false%d", opp_jumps[$4], $<i>3);
        code("\n@true%d:", $<i>3);
      }
    _RPAREN statement
      {
        code("\n\t\tJMP \t@exit%d", $<i>3);
        code("\n@false%d:", $<i>3);
        $$ = $<i>3;
      }
  ;

rel_exp
  : num_exp _RELOP num_exp
      {
        if(get_type($1) != get_type($3))
          err("invalid operands: relational operator");
        $$ = $2 + ((get_type($1) - 1) * RELOP_NUMBER);
        gen_cmp($1, $3);
      }
  ;

return_statement
  : _RETURN num_exp _SEMICOLON
      {
        if(get_type(fun_idx) != get_type($2))
          err("incompatible types in return");
        gen_mov($2, FUN_REG);
        code("\n\t\tJMP \t@%s_exit", get_name(fun_idx));        
      }
  ;

%%

int yyerror(char *s) {
  fprintf(stderr, "\nline %d: ERROR: %s", yylineno, s);
  error_count++;
  return 0;
}

void warning(char *s) {
  fprintf(stderr, "\nline %d: WARNING: %s", yylineno, s);
  warning_count++;
}

int main(int argc, char *argv[]) {
  int synerr;
  init_symtab();
  yyin = stdin;
  yyout = fopen("tokens.txt", "w");
 
  output = fopen("output.asm", "w+");
  
  synerr = yyparse();

  for (int i = 1; i < argc; i++) {
	if (strcmp(argv[i], "--symtable") == 0) {
		print_symtab();
		break;
    }
  }

  fclose(yyout);
  for (int i = 1; i < argc; i++) {
	if (strcmp(argv[i], "--tokens") == 0) {
		FILE *file = fopen("tokens.txt", "r");
		
		if (file == NULL) {
			perror("Error opening file");
			return 1;
		}
		
		printf("\n\nTokens:\n\n");

		char token[100];
		while (fgets(token, sizeof(token), file) != NULL) {
			printf("%s", token);
		}
		
		fclose(file);
		break;
    }
  }
  
  clear_symtab();
  
  fclose(output);

  if(warning_count)
    printf("\n%d warning(s).\n", warning_count);

  if(error_count) {
    remove("output.asm");
    printf("\n%d error(s).\n", error_count);
  }

  if(synerr)
    return -1;  //syntax error
  else if(error_count)
    return error_count & 127; //semantic errors
  else if(warning_count)
    return (warning_count & 127) + 127; //warnings
  else
    return 0; //OK
}

