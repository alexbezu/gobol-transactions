// Copyright 2013 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This is an example of a goyacc program.
// To build it:
// goyacc -p "expr" expr.y (produces y.go)
// go build -o expr y.go
// expr
// > <type an expression>

%{

package expr

import (
	"bytes"
	"errors"
	"math/big"
	"unicode/utf8"
)

func Calc(line string) (string, error) {
	prsIO := exprLex{line: []byte(line)}
	if exprParse(&prsIO) == 0 {
		return prsIO.res, nil
	}
	return "", errors.New(prsIO.err)
}

%}

//...SymType (exprSymType)
%union {
	num *big.Rat
}

// specify type for expr expr1 expr2 expr3 
// type determined from num type
%type	<num>	expr expr1 expr2 expr3

%token '+' '-' '*' '/' '(' ')'

%token	<num>	NUM

%%

top:
	expr
	{
		if $1.IsInt() {
			exprlex.(*exprLex).res = $1.Num().String()
		} else {
			exprlex.(*exprLex).res = $1.String()
		}
	}

expr:
	expr1
|	'+' expr
	{
		$$ = $2
	}
|	'-' expr
	{
		$$ = $2.Neg($2)
	}

expr1:
	expr2
|	expr1 '+' expr2
	{
		$$ = $1.Add($1, $3)
	}
|	expr1 '-' expr2
	{
		$$ = $1.Sub($1, $3)
	}

expr2:
	expr3
|	expr2 '*' expr3
	{
		$$ = $1.Mul($1, $3)
	}
|	expr2 '/' expr3
	{
		$$ = $1.Quo($1, $3)
	}

expr3:
	NUM
|	'(' expr ')'
	{
		$$ = $2
	}


%%

// The parser expects the lexer to return 0 on EOF.  Give it a name
// for clarity.
const eof = 0

// The parser uses the type <prefix>Lex as a lexer. It must provide
// the methods Lex(*<prefix>SymType) int and Error(string).
type exprLex struct {
	line []byte
	peek rune
	res string
	err string
}

// The parser calls this method to get each new token. This
// implementation returns operators and NUM.
func (x *exprLex) Lex(yylval *exprSymType) int {
	for {
		c := x.next()
		switch c {
		case eof:
			return eof
		case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
			return x.num(c, yylval)
		case '+', '-', '*', '/', '(', ')':
			return int(c)

		// Recognize Unicode multiplication and division
		// symbols, returning what the parser expects.
		case '×':
			return '*'
		case '÷':
			return '/'

		case ' ', '\t', '\n', '\r':
		default:
			x.err = x.err + "unrecognized char: " + string(c) + "; "
		}
	}
}

// Lex a number.
func (x *exprLex) num(c rune, yylval *exprSymType) int {
	add := func(b *bytes.Buffer, c rune) {
		if _, err := b.WriteRune(c); err != nil {
			x.err = err.Error()
		}
	}
	var b bytes.Buffer
	add(&b, c)
	L: for {
		c = x.next()
		switch c {
		case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', 'e', 'E':
			add(&b, c)
		default:
			break L
		}
	}
	if c != eof {
		x.peek = c
	}
	yylval.num = &big.Rat{}
	_, ok := yylval.num.SetString(b.String())
	if !ok {
		x.Error("bad number"+b.String())
		return eof
	}
	return NUM
}

// Return the next rune for the lexer.
func (x *exprLex) next() rune {
	if x.peek != eof {
		r := x.peek
		x.peek = eof
		return r
	}
	if len(x.line) == 0 {
		return eof
	}
	c, size := utf8.DecodeRune(x.line)
	x.line = x.line[size:]
	if c == utf8.RuneError && size == 1 {
		return x.next()
	}
	return c
}

// The parser calls this method on a parse error.
func (x *exprLex) Error(s string) {
	x.err = x.err + "parse error: " + s + "; "
}

