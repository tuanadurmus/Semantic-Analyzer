#ifndef __HELPER_H
#define __HELPER_H
#include "ast.h"
struct ASTNode;
typedef struct ASTNode ASTNode;



typedef struct DefExprInfo {
    unsigned int set;
    int line_of[26];
    ASTNode* node;
} DefExprInfo;

typedef struct ParamUsage{
    unsigned int set;
    int line_of[26];
    ASTNode* node;
} ParamUsage;

typedef struct ExprInfo{
    unsigned int set;
    int is_paren_expr;
    int begins_with_id;
    int is_fn_paren;
    char first_id;
    int arg_count;
    int id_line;
    ASTNode* previous_multiplicant;
    ASTNode* node;
    ASTNode* node_list[32];
    char raw[512];
} ExprInfo;

typedef struct ExprListInfo {
	int is_list;
    int count;
    char raw[512];
	unsigned int set;
    ASTNode* list[32];
    ASTNode* node;
} ExprListInfo;

typedef struct Error {
	int line;
	char msg[128];
} Error;



typedef struct CalcResult {
    char raw_expr[2048];
    Poly poly;
    int line;
} CalcResult;
extern CalcResult calc_results[512];
extern int calc_count;




#endif
