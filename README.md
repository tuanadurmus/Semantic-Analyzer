# Flex/Bison Symbolic Polynomial Engine

This project implements a small expression language using **Flex** and **Bison**,
builds an **AST (Abstract Syntax Tree)**, and evaluates expressions into a
**normalized polynomial representation** (with rational coefficients).

It supports:
- Function definitions (single-letter names)
- `calculate ...;` statements that print normalized polynomial results
- Symbolic **derivation** `D(f, v, n)` and **integration** `I(f, v, n)` over polynomials

---

## Language Summary

### Tokens (Lexer)
The lexer recognizes:
- Operators: `+ - * ^`
- Parentheses: `( )`
- Assignment: `=`
- Separators: `, ;`
- Keywords: `calculate`, `D` (derivative), `I` (integral)
- Identifiers: single lowercase letters `[a-z]`
- Integers: `[1-9][0-9]*`
- Comments:
  - `// ...` (single-line)
  - `/* ... */` (nested block comments supported)

---

## Parsing & Semantics (Bison)

### Program Structure
A program may contain:
- Function definitions
- `calculate` commands
- Both, or be empty

### Function Definitions
Functions are single-letter and can have 0 or more parameters:

- `f(x,y)= <expr>;`
- `f()= <expr>;`

Semantic checks:
- Redefinition: `_REDEFINED_FUNCTION_(f)`
- Usage of variables not listed as parameters:
  `_UNDEFINED_FUNCTION_PARAMETER_(x)` (reported with the correct line number)

### Expressions
The grammar supports:
- Addition/Subtraction: `+`, `-`
- Multiplication: explicit `*` and implicit adjacency (e.g., `ab` → `a*b`)
- Exponentiation: `^` (right-associative)
- Parenthesized expressions

### Function Calls
Function calls are detected in parsing when an identifier is followed by a
parenthesized argument list (e.g., `f(a,b)`), with checks for:
- Undefined function: `_UNDEFINED_FUNCTION_(f)`
- Arity mismatch: `_ARITY_CONTRADICTION_(f)`
- Missing function name: `_MISSING_FUNCTION_NAME`

### Derivative & Integral Operators
Special forms:
- `D(f, v, n)` → nth derivative of function `f` w.r.t. variable `v`
- `I(f, v, n)` → nth integral of function `f` w.r.t. variable `v`

Semantic checks:
- `_UNDEFINED_FUNCTION_FOR_DERIVATION_(f)` / `_UNDEFINED_FUNCTION_FOR_INTEGRATION_(f)`
- `_UNDEFINED_VARIABLE_FOR_DERIVATION_(v)` / `_UNDEFINED_VARIABLE_FOR_INTEGRATION_(v)`

---

## AST Design (`ast.h`)

The AST supports node types:
- Literals: `AST_INT`, `AST_VAR`
- Binary ops: `AST_ADD`, `AST_SUB`, `AST_MUL`, `AST_EXP`
- Calls: `AST_FUNC_CALL`
- Symbolic ops: `AST_DERIVATIVE`, `AST_INTEGRAL`

AST nodes are constructed via factory functions such as:
`make_add`, `make_mul`, `make_exp`, `make_func_call`, `make_derivative`, `make_integral`.

---

## Polynomial Engine (`ast.h`)

Expressions are evaluated into a polynomial form:

- `Term = (Fraction coef, int pow[26])`
- `Poly = list of terms`

Key operations:
- Normalization: sorting, merging like terms, removing zero-coefficient terms
- `poly_add`, `poly_sub`, `poly_mul`
- `poly_pow_int` (fast exponentiation)
- `poly_derivative`, `poly_integral` (symbolic calculus on polynomials)
- `poly_to_string` for normalized output formatting

Coefficients are represented as **fractions** (`Fraction {num, den}`) with GCD-based simplification.

---

## Execution Model

`calculate <expr>;` lines:
1. Parse `<expr>` into an AST
2. Evaluate the AST into a normalized polynomial (`eval_poly`)
3. Print: `<raw_expr>=<normalized_polynomial>`

---

## Repository Contents

- `flex.flx` — Flex lexer (tokens + comment handling + line tracking)
- `bison.y` — Bison grammar + semantic validation + calculate evaluation pipeline
- `ast.h` — AST definitions + polynomial engine (fraction arithmetic, normalization, calculus)
- `helper.h` — Shared parsing structs (expression info, errors, calculation results)

---

