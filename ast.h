#ifndef __AST_H
#define __AST_H

typedef enum{
    AST_INT,
    AST_VAR,          
    AST_ADD,         
    AST_SUB,          
    AST_MUL,          
    AST_EXP,          
    AST_FUNC_CALL,    
    AST_INTEGRAL,     
    AST_DERIVATIVE    
} ASTType;

typedef struct ASTNode {
    ASTType type;

   
    int value;            
    char var;            

    
    struct ASTNode* left;
    struct ASTNode* right;

   
    char func_name;      
    struct ASTNode** args;
    int arg_count;

   
    char diff_var;    

   
    int level;
    char int_var;         

   
    struct ASTNode* expr;

} ASTNode;



ASTNode* make_int(int v);

ASTNode* make_var(char v);


ASTNode* make_add(ASTNode* l, ASTNode* r);
ASTNode* make_sub(ASTNode* l, ASTNode* r);
ASTNode* make_mul(ASTNode* l, ASTNode* r);
ASTNode* make_exp(ASTNode* l, ASTNode* r);

ASTNode* make_func_call(char name, ASTNode** args, int arg_count);


ASTNode* make_derivative(ASTNode* expr, char var, int level);


ASTNode* make_integral(ASTNode* expr, char var, int level);


typedef struct Fraction{
    long long num; 
    long long den; 
} Fraction;


long long gcd(long long a, long long b);
Fraction simplify_fraction(Fraction f);
Fraction make_fraction(long long num, long long den);
Fraction add_fractions(Fraction f1, Fraction f2);
Fraction mul_fractions(Fraction f1, Fraction f2);
Fraction negate_fraction(Fraction f);



typedef struct EvalEnv {
    char vars[26];           
    Fraction values[26];     
    int count;               
} EvalEnv;

Fraction eval(ASTNode* node, EvalEnv* env);
typedef struct Term{
    Fraction coef;      
    int pow[26];        
} Term;

typedef struct Poly {
    int term_count;
    Term* terms;        
} Poly;
Poly poly_zero();
Poly poly_from_int(int v);
Poly poly_from_var(char v);  

Poly poly_add(Poly a, Poly b);     
Poly poly_sub(Poly a, Poly b);    
Poly poly_mul(Poly a, Poly b);     
Poly poly_pow_int(Poly base, int e);


Poly poly_derivative(Poly f, int var_idx);    
Poly poly_integral(Poly f, int var_idx);       
typedef struct PolyEnv  {
   
    int has_mapping[26];  
    Poly mapping[26];     
} PolyEnv;

Poly eval_poly(ASTNode* node, PolyEnv* env);
Poly eval_func_call_poly(ASTNode* call, PolyEnv* outer_env);
Poly eval_derivative_poly(ASTNode* node, PolyEnv* env);
Poly eval_integral_poly(ASTNode* node, PolyEnv* env);
void poly_to_string(Poly p, char* out, size_t out_size);







#ifdef AST_IMPLEMENTATION

#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#include "hw3.h"


typedef struct FunctionInfo {
    int defined;          
    int line;               
    int arity;             
    unsigned int param_mask;
    char params[26];
    ASTNode* body;
} FunctionInfo;
FunctionInfo functions[26];

ASTNode* make_int(int v) {
    ASTNode* n = calloc(1, sizeof(ASTNode));
    n->type = AST_INT;
    n->value = v;
    return n;
}

ASTNode* make_var(char v) {
    ASTNode* n = calloc(1, sizeof(ASTNode));
    n->type = AST_VAR;
    n->var = v;
    return n;
}

ASTNode* make_binary(ASTType t, ASTNode* l, ASTNode* r) {
    ASTNode* n = calloc(1, sizeof(ASTNode));
    n->type = t;
    n->left = l;
    n->right = r;
    return n;
}

ASTNode* make_add(ASTNode* l, ASTNode* r) { return make_binary(AST_ADD, l, r); }
ASTNode* make_sub(ASTNode* l, ASTNode* r) { return make_binary(AST_SUB, l, r); }
ASTNode* make_mul(ASTNode* l, ASTNode* r) { return make_binary(AST_MUL, l, r); }
ASTNode* make_exp(ASTNode* l, ASTNode* r) { return make_binary(AST_EXP, l, r); }

ASTNode* make_func_call(char name, ASTNode** args, int arg_count) {
    ASTNode* n = calloc(1, sizeof(ASTNode));
    n->type = AST_FUNC_CALL;
    n->func_name = name;
    n->args = args;
    n->arg_count = arg_count;
    return n;
}

ASTNode* make_derivative(ASTNode* expr, char var, int level) {
    ASTNode* n = calloc(1, sizeof(ASTNode));
    n->type = AST_DERIVATIVE;
    n->expr = expr;
    n->diff_var = var;
    n->level = level;
    return n;
}

ASTNode* make_integral(ASTNode* expr, char var, int level) {
    ASTNode* n = calloc(1, sizeof(ASTNode));
    n->type = AST_INTEGRAL;
    n->expr = expr;
    n->int_var = var;
    n->level = level;
    return n;
}
long long gcd(long long a, long long b) {
    a = llabs(a); 
    b = llabs(b);
    while (b) {
        a %= b;
      
        long long temp = a;
        a = b;
        b = temp;
    }
    return a;
}


Fraction simplify_fraction(Fraction f) {
    if (f.den == 0) return f; 
    if (f.num == 0) {
        f.den = 1;
        return f;
    }

    long long common = gcd(f.num, f.den);
    f.num /= common;
    f.den /= common;

   
    if (f.den < 0) {
        f.num = -f.num;
        f.den = -f.den;
    }
    return f;
}


Fraction make_fraction(long long num, long long den) {
    if (den == 0) {
       
        return (Fraction){0, 0};
    }
    return simplify_fraction((Fraction){num, den});
}


Fraction add_fractions(Fraction f1, Fraction f2) {
    long long num = f1.num * f2.den + f2.num * f1.den;
    long long den = f1.den * f2.den;
    return make_fraction(num, den);
}


Fraction mul_fractions(Fraction f1, Fraction f2) {
    long long num = f1.num * f2.num;
    long long den = f1.den * f2.den;
    return make_fraction(num, den);
}

Fraction negate_fraction(Fraction f) {
    f.num = -f.num;
    return simplify_fraction(f);
}

static Fraction get_var_value(char var, EvalEnv* env) {
    for (int i = 0; i < env->count; i++) {
        if (env->vars[i] == var)
            return env->values[i];
    }
 
    Fraction zero = {0,1};
    return zero;
}



static Fraction eval_function_call(ASTNode* node, EvalEnv* env) {
    char fname = node->func_name;
    int idx = fname - 'a';

    FunctionInfo* fi = &functions[idx];
    ASTNode* body = fi->body;

    int argc = node->arg_count;

  
    EvalEnv new_env;
    new_env.count = fi->arity;

    int pos = 0;
    for (int i = 0; i < 26; i++) {
        if (fi->param_mask & (1u << i)) {
            new_env.vars[pos] = 'a' + i;

            if (pos < argc)
                new_env.values[pos] = eval(node->args[pos], env);
            else {
                Fraction zero = {0,1};
                new_env.values[pos] = zero;
            }
            pos++;
        }
    }

    return eval(body, &new_env);
}



Fraction eval(ASTNode* node, EvalEnv* env) {

    if(node==NULL){
        return make_fraction(0,1);
    }
    switch (node->type) {

        case AST_INT: {
            return make_fraction(node->value, 1);
        }

        case AST_VAR: {
            return get_var_value(node->var, env);
        }

        case AST_ADD: {
            Fraction L = eval(node->left, env);
            Fraction R = eval(node->right, env);
            return add_fractions(L, R);
        }

        case AST_SUB: {
            Fraction L = eval(node->left, env);
            Fraction R = eval(node->right, env);
            Fraction negR = negate_fraction(R);
            return add_fractions(L, negR);
        }

        case AST_MUL: {
            Fraction L = eval(node->left, env);
            Fraction R = eval(node->right, env);
            return mul_fractions(L, R);
        }

        case AST_EXP: {
            
            Fraction base = eval(node->left, env);
            Fraction exponent = eval(node->right, env);

         
            long long e = exponent.num / exponent.den;

            Fraction result = make_fraction(1,1);
            for (int i = 0; i < e; i++)
                result = mul_fractions(result, base);

            return result;
        }

        case AST_FUNC_CALL:
            return eval_function_call(node, env);

        case AST_DERIVATIVE:
           
        {
            Fraction zero = {0,1};
            return zero;
        }

        case AST_INTEGRAL:
            
        {
            Fraction zero = {0,1};
            return zero;
        }
    }


    Fraction zero = {0,1};
    return zero;
}




extern FunctionInfo functions[26];

Fraction eval(ASTNode* node, EvalEnv* env);  

#include <string.h>

Poly poly_zero() {
    Poly p;
    p.term_count = 0;
    p.terms = NULL;
    return p;
}

Poly poly_from_int(int v) {
    Poly p;
    if (v == 0) return poly_zero();

    p.term_count = 1;
    p.terms = calloc(1, sizeof(Term));
    p.terms[0].coef = make_fraction(v, 1);
    for (int i = 0; i < 26; i++) p.terms[0].pow[i] = 0;
    return p;
}

Poly poly_from_var(char v) {
    Poly p;
    p.term_count = 1;
    p.terms = calloc(1, sizeof(Term));
    p.terms[0].coef = make_fraction(1, 1);
    for (int i = 0; i < 26; i++) p.terms[0].pow[i] = 0;
    if (v >= 'a' && v <= 'z') {
        p.terms[0].pow[v - 'a'] = 1;
    }
    return p;
}
static int same_powers(int p1[26], int p2[26]) {
    for (int i = 0; i < 26; i++) {
        if (p1[i] != p2[i]) return 0;
    }
    return 1;
}

static int compare_terms(const void* a, const void* b) {
    const Term* t1 = (const Term*)a;
    const Term* t2 = (const Term*)b;

   
    for (int i = 25; i >= 0; i--) {
        if (t1->pow[i] != t2->pow[i])
            return t2->pow[i] - t1->pow[i]; 
    }
    return 0;
}

Poly poly_normalize(Poly p) {
    if (p.term_count == 0) return p;

   
    qsort(p.terms, p.term_count, sizeof(Term), compare_terms);

 
    Term* new_terms = calloc(p.term_count, sizeof(Term));
    int new_count = 0;

    for (int i = 0; i < p.term_count; i++) {
        if (i > 0 && same_powers(p.terms[i].pow, p.terms[i - 1].pow)) {
         
            Fraction sum = add_fractions(new_terms[new_count - 1].coef, p.terms[i].coef);
            new_terms[new_count - 1].coef = sum;
        } else {
        
            new_terms[new_count++] = p.terms[i];
        }
    }


    Term* final_terms = calloc(new_count, sizeof(Term));
    int final_count = 0;

    for (int i = 0; i < new_count; i++) {
        if (new_terms[i].coef.num != 0) {
            final_terms[final_count++] = new_terms[i];
        }
    }

    free(p.terms);
    free(new_terms);

    Poly result;
    result.term_count = final_count;
    result.terms = final_terms;

    return result;
}




Poly poly_add(Poly a, Poly b) {
    Poly p;
    p.term_count = a.term_count + b.term_count;
    p.terms = calloc(p.term_count, sizeof(Term));

    int idx = 0;
    for (int i = 0; i < a.term_count; i++) {
        p.terms[idx++] = a.terms[i];
    }
    for (int i = 0; i < b.term_count; i++) {
        p.terms[idx++] = b.terms[i];
    }

    

    return poly_normalize(p);
}

Poly poly_sub(Poly a, Poly b) {
    for (int i = 0; i < b.term_count; i++) {
        b.terms[i].coef = negate_fraction(b.terms[i].coef);
    }
    return poly_add(a, b);
}
Poly poly_mul(Poly a, Poly b) {
    if (a.term_count == 0 || b.term_count == 0) return poly_zero();

    Poly p;
    p.term_count = a.term_count * b.term_count;
    p.terms = calloc(p.term_count, sizeof(Term));

    int idx = 0;
    for (int i = 0; i < a.term_count; i++) {
        for (int j = 0; j < b.term_count; j++) {
            Term t;
        
            t.coef = mul_fractions(a.terms[i].coef, b.terms[j].coef);
        
            for (int k = 0; k < 26; k++) {
                t.pow[k] = a.terms[i].pow[k] + b.terms[j].pow[k];
            }
            p.terms[idx++] = t;
        }
    }
   
    return poly_normalize(p);
}
Poly poly_pow_int(Poly base, int e) {
    if (e == 0) return poly_from_int(1);
    if (e == 1) return base;

    Poly result = poly_from_int(1);
    Poly cur = base;
    int exp = e;

    while (exp > 0) {
        if (exp & 1) {
            result = poly_mul(result, cur);
        }
        if (exp > 1) {
            cur = poly_mul(cur, cur);
        }
        exp >>= 1;
    }
    return result;
}
Poly poly_derivative(Poly f, int var_idx) {
    if (f.term_count == 0) return poly_zero();

    Poly res;
    res.term_count = f.term_count;
    res.terms = calloc(res.term_count, sizeof(Term));

    int out = 0;
    for (int i = 0; i < f.term_count; i++) {
        int p = f.terms[i].pow[var_idx]; 
        if (p == 0) {
           
            continue;
        }

        Term t;
       
        Fraction p_frac = make_fraction(p, 1);
        t.coef = mul_fractions(f.terms[i].coef, p_frac);

       
        for (int k = 0; k < 26; k++) {
            t.pow[k] = f.terms[i].pow[k];
        }
        t.pow[var_idx] = p - 1;

        res.terms[out++] = t;
    }

    res.term_count = out;

    if (out == 0) {
        free(res.terms);
        return poly_zero();
    }

    return poly_normalize(res);
}
Poly poly_integral(Poly f, int var_idx) {
    if (f.term_count == 0) return poly_zero();

    Poly res;
    res.term_count = f.term_count;
    res.terms = calloc(res.term_count, sizeof(Term));

    for (int i = 0; i < f.term_count; i++) {
        Term t;
        int oldp = f.terms[i].pow[var_idx];
        int newp = oldp + 1;       
        
       
        Fraction inv = make_fraction(1, newp);
        t.coef = mul_fractions(f.terms[i].coef, inv);
        
       
        for (int k = 0; k < 26; k++) {
            t.pow[k] = f.terms[i].pow[k];
        }
        t.pow[var_idx] = newp;

        res.terms[i] = t;
    }
    char dbg[256];
    poly_to_string(res, dbg, sizeof(dbg));
    

    return poly_normalize(res);
}


Poly eval_poly(ASTNode* node, PolyEnv* env) {
    if (!node) return poly_zero();

    switch (node->type) {
        case AST_INT:
            return poly_from_int(node->value);

        case AST_VAR: {
            int idx = node->var - 'a';
            if (idx >= 0 && idx < 26 && env && env->has_mapping[idx]) {
                
                return env->mapping[idx];
            } else {
          
                return poly_from_var(node->var);
            }
        }

        case AST_ADD: {
            Poly L = eval_poly(node->left, env);
            Poly R = eval_poly(node->right, env);
            return poly_add(L, R);
        }

        case AST_SUB: {
            Poly L = eval_poly(node->left, env);
            Poly R = eval_poly(node->right, env);
            return poly_sub(L, R);
        }

        case AST_MUL: {
            Poly L = eval_poly(node->left, env);
            Poly R = eval_poly(node->right, env);
            return poly_mul(L, R);
        }

        case AST_EXP: {
            Poly base = eval_poly(node->left, env);
            Poly exp  = eval_poly(node->right, env);
            
            int e = (int)(exp.terms[0].coef.num / exp.terms[0].coef.den);
            return poly_pow_int(base, e);
        }

        case AST_FUNC_CALL:
            return eval_func_call_poly(node, env);

        case AST_DERIVATIVE:
            return eval_derivative_poly(node, env);

        case AST_INTEGRAL:
            return eval_integral_poly(node, env);
    }

    return poly_zero();
}
Poly eval_func_call_poly(ASTNode* call, PolyEnv* outer_env) {
    char f = call->func_name;
    int idx = f - 'a';
    FunctionInfo* fi = &functions[idx];

    PolyEnv local;
    memset(&local, 0, sizeof(local));


    for (int i = 0; i < fi->arity; i++) {
        char formal = fi->params[i];     
        int vidx = formal - 'a';
        




        Poly argpoly = eval_poly(call->args[i], outer_env);
        local.has_mapping[vidx] = 1;
        local.mapping[vidx] = argpoly;
        

    }
 
    return eval_poly(fi->body, &local);
}

Poly eval_derivative_poly(ASTNode* node, PolyEnv* env) {

    int var_idx = node->diff_var - 'a';
    int n = node->level;
    if (n <= 0) n = 1;


    Poly current = eval_poly(node->expr, env);


    for (int i = 0; i < n; i++) {
        current = poly_derivative(current, var_idx);
        current = poly_normalize(current); 
    }
    return current;
}

Poly eval_integral_poly(ASTNode* node, PolyEnv* env) {

    int var_idx = node->int_var - 'a';
    int n = node->level;
    if (n <= 0) n = 1;

    Poly current = eval_poly(node->expr, env);

    
    for (int i = 0; i < n; i++) {
        current = poly_integral(current, var_idx);
        current = poly_normalize(current); 
        
    }
    return current;
}

int herhangi_var_var_mi(Term t) {
    for (int i = 0; i < 26; i++)
        if (t.pow[i] != 0)
            return 1;
    return 0;
}

void poly_to_string(Poly p, char *buf, size_t size)
{
    buf[0] = '\0';


    if (p.term_count == 0)
    {
        snprintf(buf, size, "0");
        return;
    }


    Term *terms = malloc(sizeof(Term) * p.term_count);
    memcpy(terms, p.terms, sizeof(Term) * p.term_count);


    int cmp(const void *a, const void *b)
    {
        const Term *t1 = a;
        const Term *t2 = b;

        for (int i = 0; i < 26; i++)
        {
            if (t1->pow[i] != t2->pow[i])
                return t2->pow[i] - t1->pow[i];
        }
        return 0;
    }

    qsort(terms, p.term_count, sizeof(Term), cmp);

  
    char temp[1024];
    int first_written = 0;

    for (int i = 0; i < p.term_count; i++)
    {
        Term *t = &terms[i];


        if (t->coef.num == 0)
            continue;


        long long num = t->coef.num;
        long long den = t->coef.den;

        if (!first_written)
        {
            if (num < 0)
                snprintf(temp, sizeof(temp), "-");
            else
                strcpy(temp, "");
            first_written = 1;
        }
        else
        {
            if (num < 0)
                snprintf(temp, sizeof(temp), "-");
            else
                snprintf(temp, sizeof(temp), "+");
        }

        strcat(buf, temp);


        num = llabs(num);

   
        int has_variable = 0;
        for (int j = 0; j < 26; j++)
            if (t->pow[j] > 0)
                has_variable = 1;

        if (!has_variable)
        {
      
            if (den == 1)
                snprintf(temp, sizeof(temp), "%lld", num);
            else
                snprintf(temp, sizeof(temp), "%lld/%lld", num, den);
            strcat(buf, temp);
            continue;
        }
        else
        {
     
            if (!(num == 1 && den == 1))
            {
                if (den == 1)
                    snprintf(temp, sizeof(temp), "%lld", num);
                else
                    snprintf(temp, sizeof(temp), "%lld/%lld", num, den);
                strcat(buf, temp);
            }
        }


        for (int v = 0; v < 26; v++)
        {
            int pw = t->pow[v];
            if (pw == 0) continue;

            char var = 'a' + v;
            snprintf(temp, sizeof(temp), "%c", var);
            strcat(buf, temp);

   
            if (pw != 1)
            {
                snprintf(temp, sizeof(temp), "^%d", pw);
                strcat(buf, temp);
            }
        }
    }

    free(terms);


    if (buf[0] == '\0')
        snprintf(buf, size, "0");
}










#endif
#endif
