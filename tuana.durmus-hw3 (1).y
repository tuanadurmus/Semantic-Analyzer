%{
#ifdef YYDEBUG
extern int yydebug;
#endif

#define SAFE_SNPRINTF(buf, fmt, ...)                     \
    do {                                                 \
        int __n = snprintf(buf, sizeof(buf), fmt, __VA_ARGS__); \
        if (__n < 0 || __n >= sizeof(buf))               \
            buf[sizeof(buf)-1] = '\0';                   \
    } while (0)


#define AST_IMPLEMENTATION
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "hw3.h"
#include "ast.h"

int yylex();
void yyerror (const char *msg);

extern int yylineno;
extern int identifier_line;

Error errors[1024];
FunctionInfo functions[26];
int error_count = 0;
int current_func_index = -1;
int current_calculate_line = 0;
CalcResult calc_results[512];
int calc_count = 0;

static inline unsigned int id_to_bit(char c) {
    if (c < 'a' || c > 'z') return 0;
    return 1u << (c - 'a');
}



static ParamUsage merge_usage(ParamUsage a, ParamUsage b) {
    ParamUsage r;
    memset(&r, 0, sizeof(ParamUsage));
    r.set = a.set | b.set;
    for (int i = 0; i < 26; i++) {
        if (a.line_of[i]) r.line_of[i] = a.line_of[i];
        if (b.line_of[i]) r.line_of[i] = b.line_of[i];
    }
    return r;
}





void init_semantic();
int cmp_error(const void *a, const void *b);
void add_error(int line, const char *msg);



%}

%union {
	char id;
	int ival;
	unsigned int set;
	ExprListInfo exprlist;
    ExprInfo expr;
    ParamUsage usage;
    struct paramList{
        char params[26];
        int count;
    } paramList;
    char raw[4096];
}

%token tPLUS tMINUS tMUL tEXP tLPR tRPR tASSIGN tCOMMA tSEMICOLON tDERIVATION tINTEGRATION tCALCULATE 
%token <id> tIDENTIFIER
%token <ival> tINTEGER
%type <paramList> var_parameters
%type <usage> oe oe1 oe2
%type <expr> ee ee1 ee2
%type <exprlist> ee3
%type <expr> integration
%type <expr> derivation
%type <ival> midrule_line

%nonassoc LOWEST
%right tEXP

%start program

%%

program:	
			 fn_list calc_list
			|  fn_list
			| calc_list
			|  empty
;

fn_list:	  fn_def
			| fn_def fn_list
;

fn_def:
      tIDENTIFIER tLPR 
      {
          int idx = $1 - 'a';

          if (functions[idx].defined) {
              char buf[128];
              snprintf(buf, sizeof(buf), "_REDEFINED_FUNCTION_(%c)", $1);
              add_error(yylineno, buf);
              current_func_index = -1;
          } else {
              current_func_index = idx;
              functions[idx].defined = 1;
              functions[idx].line = yylineno;
              functions[idx].arity = 0;
              functions[idx].param_mask = 0;
          }
      }
      var_parameters tRPR tASSIGN oe tSEMICOLON
      {
          int idx = current_func_index;
          if (idx >= 0) {

            
              functions[idx].arity = $4.count;
              for (int i = 0; i < $4.count; i++) {
                  char p = $4.params[i];
                  functions[idx].params[i] = p;
                  functions[idx].param_mask |= id_to_bit(p);
              }

          
              unsigned int params = functions[idx].param_mask;
              unsigned int undef = $7.set & ~params;

              for (int i = 0; i < 26; i++) {
                  if (undef & (1u << i)) {
                      int ln = $7.line_of[i];
                      char name = 'a' + i;
                      char buf[128];
                      snprintf(buf, sizeof(buf),
                               "_UNDEFINED_FUNCTION_PARAMETER_(%c)", name);
                      add_error(ln, buf);
                  }
              }

              functions[idx].body = $7.node;
          }
      }
    |

      tIDENTIFIER tLPR 
      {
          int idx = $1 - 'a';

          if (functions[idx].defined) {
              char buf[128];
              snprintf(buf, sizeof(buf), "_REDEFINED_FUNCTION_(%c)", $1);
              add_error(yylineno, buf);
              current_func_index = -1;
          } else {
              current_func_index = idx;
              functions[idx].defined = 1;
              functions[idx].line = yylineno;
              functions[idx].arity = 0;
              functions[idx].param_mask = 0;
          }
      }
      tRPR tASSIGN oe tSEMICOLON
      {
          int idx = current_func_index;

          functions[idx].arity = 0;
          functions[idx].param_mask = 0;

          unsigned int undef = $6.set;

          for (int i = 0; i < 26; i++) {
              if (undef & (1u << i)) {
                  int ln = $6.line_of[i];
                  char name = 'a' + i;
                  char buf[128];
                  snprintf(buf, sizeof(buf),
                           "_UNDEFINED_FUNCTION_PARAMETER_(%c)", name);
                  add_error(ln, buf);
              }
          }

          functions[idx].body = $6.node;
      }
;






var_parameters:
      tIDENTIFIER
      {
          $$.params[0] = $1;
          $$.count = 1;
      }
    | var_parameters tCOMMA tIDENTIFIER
      {
          memcpy($$.params, $1.params, $1.count);
          $$.params[$1.count] = $3;
          $$.count = $1.count + 1;
      }
;


oe:
      oe tPLUS oe1
      {
       
          $$.set = $1.set | $3.set;
          for (int i = 0; i < 26; i++) {
              $$.line_of[i] = $1.line_of[i] ? $1.line_of[i] : $3.line_of[i];
          }
       
          $$.node = make_add($1.node, $3.node);
      }
    | oe tMINUS oe1
      {
          $$.set = $1.set | $3.set;
          for (int i = 0; i < 26; i++) {
              $$.line_of[i] = $1.line_of[i] ? $1.line_of[i] : $3.line_of[i];
          }
          $$.node = make_sub($1.node, $3.node);
      }
    | oe1
      {
          $$.set = $1.set;
          memcpy($$.line_of, $1.line_of, sizeof($1.line_of));
          $$.node = $1.node;
      }
;


oe1:
      oe1 tMUL oe2
      {
  
          $$.set = $1.set | $3.set;
          for (int i = 0; i < 26; i++) {
              $$.line_of[i] = $1.line_of[i] ? $1.line_of[i] : $3.line_of[i];
          }
      
          $$.node = make_mul($1.node, $3.node);
      }
    | oe1 oe2
      {
      
          $$.set = $1.set | $2.set;
          for (int i = 0; i < 26; i++) {
              $$.line_of[i] = $1.line_of[i] ? $1.line_of[i] : $2.line_of[i];
          }
        
          $$.node = make_mul($1.node, $2.node);
      }
    | oe2
      {
          $$.set = $1.set;
          memcpy($$.line_of, $1.line_of, sizeof($1.line_of));
          $$.node = $1.node;
      }
;


oe2:			  tINTEGER     {
                    memset(&$$, 0, sizeof(ParamUsage));
                    $$.node = make_int($1);
                }
				| tIDENTIFIER     {
                    memset(&$$, 0, sizeof(ParamUsage));
                    $$.set = id_to_bit($1);
                    $$.line_of[$1 - 'a'] = yylineno;
                    $$.node = make_var($1);
                }
				| tLPR oe tRPR    
                {
                    $$.set = $2.set;
                    memcpy($$.line_of, $2.line_of, sizeof($2.line_of));
                    $$.node = $2.node;
                }
				| oe2 tEXP oe2     
                {
                    
                    $$.set = $1.set | $3.set;
                    memcpy($$.line_of, $1.line_of, sizeof($1.line_of));

          
                    $$.node = make_exp($1.node, $3.node);

                    
                   
                    
                    
                }
				
;

calc_list: 	  calc
			| calc calc_list
;

calc:		  tCALCULATE {current_calculate_line = yylineno;} ee tSEMICOLON {
    
    

       
    PolyEnv empty_env;
    memset(&empty_env, 0, sizeof(empty_env));
    Poly p = eval_poly($3.node, &empty_env);
    CalcResult *cr = &calc_results[calc_count++];
    strcpy(cr->raw_expr, $3.raw);
    cr->poly = p;
    cr->line = current_calculate_line;
        
        
    

}
;

ee:		ee1 %prec LOWEST
    {
        $$.node = $1.node;
        $$.previous_multiplicant = $1.previous_multiplicant;
     
        strcpy($$.raw, $1.raw);
          
        $$.begins_with_id = $1.begins_with_id;
        $$.is_paren_expr =  $1.is_paren_expr;
        $$.is_fn_paren =  $1.is_fn_paren;
        $$.first_id = $1.first_id;
        $$.arg_count =  $1.arg_count;
        $$.id_line = $1.id_line;
        if ($1.is_paren_expr && $1.arg_count > 1 && !$1.is_fn_paren) {
            add_error(current_calculate_line, "_MISSING_FUNCTION_NAME");
            $$.node = NULL;
        }
    }
    | ee tPLUS ee1
      {
        $$.node = make_add($1.node, $3.node);
        SAFE_SNPRINTF($$.raw, "%s+%s", $1.raw, $3.raw);
          $$.set = $1.set | $3.set;
          $$.begins_with_id = 0;
          $$.is_paren_expr = 0;
          $$.is_fn_paren = 0;
          $$.first_id = 0;
          $$.arg_count = 0;
          if ($3.is_paren_expr && $3.arg_count > 1 )
              add_error(current_calculate_line, "_MISSING_FUNCTION_NAME");
      }
    | ee tMINUS ee1
      {
        $$.node = make_sub($1.node, $3.node);
        SAFE_SNPRINTF($$.raw, "%s-%s", $1.raw, $3.raw);
          $$.set = $1.set | $3.set;
          $$.begins_with_id = 0;
          $$.is_paren_expr = 0;
          $$.is_fn_paren = 0;
          $$.first_id = 0;
          $$.arg_count = 0;
          if ($3.is_paren_expr && $3.arg_count > 1 )
              add_error(current_calculate_line, "_MISSING_FUNCTION_NAME");
      }
;

ee1:		ee2  {$$.node = $1.node;
           
                $$.previous_multiplicant = $1.previous_multiplicant;
                strcpy($$.raw, $1.raw);
                 $$.begins_with_id = $1.begins_with_id;
                 $$.is_paren_expr =  $1.is_paren_expr;
                 $$.is_fn_paren =  $1.is_fn_paren;
                 $$.first_id = $1.first_id;
                 $$.arg_count =  $1.arg_count;
                 $$.id_line = $1.id_line;
                 if ($1.is_paren_expr && $1.arg_count > 1 )
                    add_error(current_calculate_line, "_MISSING_FUNCTION_NAME");
                }
            |  ee1 tMUL ee2 
            {
            
                $$.node = make_mul($1.node, $3.node);
                $$.previous_multiplicant = $1.node;
                SAFE_SNPRINTF($$.raw, "%s*%s", $1.raw, $3.raw);
                $$.set = $1.set | $3.set;
                if($3.begins_with_id==1){
                    
                    $$.begins_with_id = 1;
                    $$.first_id = $3.first_id;
                }
                else{
                    $$.begins_with_id = 0;
                    $$.first_id = $1.first_id;
                }
                
                $$.is_paren_expr = 0;
                $$.is_fn_paren = 0;
                
                $$.arg_count = 0;
                if ($3.is_paren_expr && $3.arg_count > 1 )
              add_error(current_calculate_line, "_MISSING_FUNCTION_NAME");
            }
			| ee1 ee2
            {
            
                SAFE_SNPRINTF($$.raw, "%s%s", $1.raw, $2.raw);
                if ($1.begins_with_id && $2.is_paren_expr)
                {
                    char f = $1.first_id;
                    int idx = f - 'a';
                    int argc = $2.arg_count;


                    if (!functions[idx].defined && argc != 1)
                    {
                        char buf[128];
                        snprintf(buf, sizeof(buf), "_UNDEFINED_FUNCTION_(%c)", f);
                        add_error($1.id_line, buf);
                    }
                    else
                    {
                        
                        if (functions[idx].arity != argc && argc>1)
                        {
                           char buf[128];
                            snprintf(buf, sizeof(buf), "_ARITY_CONTRADICTION_(%c)", f);
                            

                            add_error($$.id_line, buf);
                        }
        
                    }
                    $$.id_line = $1.id_line;
                    $$.set = $1.set | $2.set;
                    $$.begins_with_id = 0;
                    $$.first_id = 0;
                    $$.is_fn_paren = 1;
                    $$.is_paren_expr = 0;
                    $$.arg_count = 0;
                    ASTNode** arr = malloc(argc * sizeof(ASTNode*));
                    for (int i = 0; i < argc; i++) {
                        arr[i] = $2.node_list[i]; 
                    }
                    if(functions[idx].defined){
                        $$.node = make_func_call(f, arr, argc);
                        $$.node = make_mul($$.previous_multiplicant, $$.node);
                        SAFE_SNPRINTF($$.raw, "%s%s", $1.raw, $2.raw); 

                    }
                    else{$$.node = make_mul($1.node, $2.node);}
                     
                }
                else if (!$1.begins_with_id && $2.is_paren_expr && $2.arg_count > 1)
                {
                    add_error(current_calculate_line, "_MISSING_FUNCTION_NAME");
                }
                else{
                   
                    $$.previous_multiplicant = $1.node;
                    $$.node = make_mul($1.node, $2.node);
                    
                }
                $$.set = $1.set | $2.set;
                $$.is_paren_expr = 0;
                $$.is_fn_paren = 0;
                $$.arg_count = 0;
               
                if ($2.begins_with_id)
                {
                    $$.begins_with_id = 1;
                    $$.first_id = $2.first_id;
                    $$.id_line = $2.id_line;
                }
                else
                {
                    $$.begins_with_id = $1.begins_with_id;
                    $$.first_id = $1.first_id;
                    $$.id_line = $1.id_line;
                }

            }

;

ee2:		 
		      tINTEGER    
              {
                snprintf($$.raw,sizeof($$.raw), "%d", $1);
                $$.node = make_int($1);
                $$.set = 0;
                $$.begins_with_id = 0;
                $$.is_paren_expr = 0;
                $$.is_fn_paren = 0;
                $$.first_id = 0;
                $$.arg_count = 0;
                $$.previous_multiplicant = make_int(1);
                }
			| tIDENTIFIER  
            {
                snprintf($$.raw,sizeof($$.raw), "%c", $1);
                $$.node = make_var($1);
                $$.set = id_to_bit($1);
                $$.begins_with_id = 1;
                $$.is_paren_expr = 0;
                $$.is_fn_paren = 0;
                $$.first_id = $1;
                $$.arg_count = 0;
                $$.id_line = identifier_line;
                $$.previous_multiplicant = make_int(1);
            }
			| tLPR tRPR  
            {
                snprintf($$.raw,sizeof($$.raw), "()");
                $$.set = 0;
                $$.begins_with_id = 0;
                $$.is_paren_expr = 1;
                $$.is_fn_paren = 0;
                $$.first_id = 0;
                $$.arg_count = 0;
                $$.previous_multiplicant = make_int(1);
            }
			| tLPR ee3 tRPR 
			{
                SAFE_SNPRINTF($$.raw, "(%s)", $2.raw);
				$$.node = $2.node;
				$$.set  = $2.set;
                $$.begins_with_id = 0;
                $$.is_paren_expr = 1;
                $$.is_fn_paren = 0;
                $$.first_id = 0;
                $$.arg_count = $2.count;
                $$.id_line = 0;
                memcpy($$.node_list, $2.list, sizeof($2.list));
                $$.previous_multiplicant = make_int(1);

			}
			| tIDENTIFIER tEXP tINTEGER 
            {
                snprintf($$.raw,sizeof($$.raw), "%c^%d", $1, $3);
                $$.set = id_to_bit($1);
                $$.begins_with_id = 1;
                $$.is_paren_expr = 0;
                $$.is_fn_paren = 0;
                $$.first_id = $1;
                $$.arg_count = 0;
                $$.previous_multiplicant = make_int(1);

                ASTNode* base  = make_var($1);
                ASTNode* power = make_int($3);
                $$.node = make_exp(base, power);
            }
			| tINTEGER tEXP tINTEGER  
            {
                snprintf($$.raw,sizeof($$.raw), "%d^%d", $1, $3);
                $$.set = 0;
                $$.begins_with_id = 0;
                $$.is_paren_expr = 0;
                $$.is_fn_paren = 0;
                $$.first_id = 0;
                $$.arg_count = 0;
                $$.id_line = identifier_line;
                $$.previous_multiplicant = make_int(1);
                ASTNode* base  = make_int($1);
                ASTNode* power = make_int($3);
                $$.node = make_exp(base, power);
            }
			| integration   
            {
                $$ = $1;
                $$.previous_multiplicant = make_int(1);
            }
			| derivation  
            {
                $$ = $1;
                $$.previous_multiplicant = make_int(1);
            }
;

ee3:
      ee
      {
        strcpy($$.raw, $1.raw);
        $$.node = $1.node;
        $$.list[0] = $1.node;
          $$.is_list = 0;
          $$.count = 1;
          $$.set = $1.set;
          
      }

    | ee3 tCOMMA ee
      {
        int n = snprintf($$.raw,sizeof($$.raw), "%s,%s", $1.raw, $3.raw);
        if(n<0 || n>= sizeof($$.raw)){
            $$.raw[sizeof($$.raw)-1] = '\0';
        }

        $$.node = NULL;
        $$.list[$1.count] = $3.node;
          $$.is_list = 1;
          $$.count = $1.count + 1;
          $$.set = $1.set | $3.set;
      }
;


integration:  tINTEGRATION tLPR tIDENTIFIER midrule_line tCOMMA tIDENTIFIER tCOMMA tINTEGER tRPR
				{
          char f = $3;
          char v = $6;
          int idx = f - 'a';
          int func_line = $4;
          int n = $8;

 

     
    
          if (!functions[idx].defined) {
              char buf[128];
              snprintf(buf, sizeof(buf),
                       "_UNDEFINED_FUNCTION_FOR_INTEGRATION_(%c)", f);
              add_error(func_line, buf);
          } else {
              
              if (!(functions[idx].param_mask & id_to_bit(v))) {
                  char buf[128];
                  snprintf(buf, sizeof(buf),
                           "_UNDEFINED_VARIABLE_FOR_INTEGRATION_(%c)", v);
                  add_error(identifier_line, buf);
              }
          }
          FunctionInfo* fi = &functions[idx];
        ASTNode** args = calloc(fi->arity, sizeof(ASTNode*));

            for (int i = 0; i < fi->arity; i++) {
                args[i] = make_var(fi->params[i]);   
            }

            ASTNode* fcall = make_func_call(f, args, fi->arity);
            snprintf($$.raw,sizeof($$.raw), "I(%c,%c,%d)", f, v, n);


          $$.node = make_integral(fcall, v, n);

          $$.set = 0;
          $$.begins_with_id = 0;
          $$.is_paren_expr = 0;
          $$.is_fn_paren   = 0;
          $$.first_id = 0;
          $$.arg_count = 0;
        $$.id_line  = func_line;
      }
;

derivation:   tDERIVATION tLPR tIDENTIFIER midrule_line tCOMMA tIDENTIFIER tCOMMA tINTEGER tRPR
				{
          char f = $3;
          char v = $6;
          int idx = f - 'a';
          int func_line = $4;
          int n = $8;

          

          if (!functions[idx].defined) {
              char buf[128];
              snprintf(buf, sizeof(buf),
                       "_UNDEFINED_FUNCTION_FOR_DERIVATION_(%c)", f);
              add_error(func_line, buf);
          } else {
              if (!(functions[idx].param_mask & id_to_bit(v))) {
                  char buf[128];
                  snprintf(buf, sizeof(buf),
                           "_UNDEFINED_VARIABLE_FOR_DERIVATION_(%c)", v);
                  add_error(identifier_line, buf);
              }
          }
          FunctionInfo* fi = &functions[idx];
            ASTNode** args = calloc(fi->arity, sizeof(ASTNode*));

            for (int i = 0; i < fi->arity; i++) {
                 args[i] = make_var(fi->params[i]); 
                }

            ASTNode* fcall = make_func_call(f, args, fi->arity);
            snprintf($$.raw,sizeof($$.raw), "D(%c,%c,%d)", f, v, n);


          $$.node = make_derivative(fcall, v, n);

    $$.set = 0;
    $$.begins_with_id = 0;
    $$.is_paren_expr = 0;
    $$.is_fn_paren   = 0;
    $$.first_id = 0;
    $$.arg_count = 0;
    $$.id_line  = func_line;
      }
;
midrule_line:
     { $$ = identifier_line; }
;

empty: 
;
			
%%

void yyerror(const char *msg)
{
    printf("SYNTAX_ERROR\n");
    exit(0);
}

void add_error(int line, const char *msg){
	if(error_count >= 1024) return;
	errors[error_count].line = line;
	strncpy(errors[error_count].msg, msg, 127);
	errors[error_count].msg[127] = '\0';
	error_count++;
}

int cmp_error(const void *a, const void *b){
	const Error *e1 = (const Error *)a;
	const Error *e2 = (const Error *)b;
	if (e1->line != e2->line) return e1->line - e2->line;
	return strcmp(e1->msg, e2->msg);
}



void init_semantic() {
    int i;
    error_count = 0;
    for (i = 0; i < 26; i++) {
        functions[i].defined = 0;
        functions[i].line = -1;
        functions[i].arity = 0;
        functions[i].param_mask = 0;
        functions[i].body = NULL;
    }
}


int main()
{

  
	init_semantic();
	
  


	if (yyparse()) {
	
		return 1;
	}
	if (error_count > 0){
		qsort(errors, error_count, sizeof(Error), cmp_error);
		for (int i = 0; i < error_count; i++){
			printf("%d%s\n", errors[i].line, errors[i].msg);
        }
        return 0;
		
	}
    else{}

    for (int i = 0; i<calc_count; i++){
        char buf[4096];
        poly_to_string(calc_results[i].poly, buf, sizeof(buf));
        printf("%s=%s\n", calc_results[i].raw_expr, buf);
    }

	
	
	return 0;
	
}