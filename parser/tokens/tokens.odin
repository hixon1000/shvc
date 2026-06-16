/*
   Copyright 2026 Shiver Contributors

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

package tokens

// operators
Eof :: struct {}
Colon :: struct {} // :
Arrow :: struct {} // ->
Caret :: struct {} // ^
Ampersand :: struct {} // &
Assign :: struct {} // =
Comma :: struct {} // ,
Semi_Colon :: struct {} // ;
Plus :: struct {} // +
Minus :: struct {} // -
Star :: struct {} // *
Slash :: struct {} // /
Equal :: struct {} // ==
Not_Equal :: struct {} // !=
Less :: struct {} // <
Greater :: struct {} // >
Plus_Assign :: struct {} // +=
Minus_Assign :: struct {} // -=
Question :: struct {} // ?
Dot :: struct {} // .

// brackets
Open_Paren :: struct {} // (
Close_Paren :: struct {} // )
Open_Bracket :: struct {} // {
Close_Bracket :: struct {} // }
Open_SB :: struct {} // [
Close_SB :: struct {} // ]


// identifiers
Val :: struct {}
Mut :: struct {}
Fn :: struct {}
Return :: struct {}
If :: struct {}
Do :: struct {}
Else :: struct {}
Struct :: struct {}
For :: struct {}
Defer :: struct {}
In :: struct {}
Break :: struct {}
Continue :: struct {}
As :: struct {}
As_Bang :: struct {}
Trait :: struct {}

Identifier :: struct {
	content: string, // distinct also works
}

// numebers
Int_Literal :: struct {
	content: i32,
} // TODO: consider

Float_Literal :: struct {
	content: f32,
} // TODO: also consider

// strings
String_Literal :: struct {
	content: string,
}

Token :: union {
	// end
	Eof,
	Colon,
	Arrow,
	Ampersand,
	Comma,
	Question,
	Dot,

	// unary
	Caret,
	Semi_Colon,
	Slash,

	// binary
	Assign,
	Plus,
	Minus,
	Star,
	Equal,
	Not_Equal,
	Less,
	Greater,
	Plus_Assign,
	Minus_Assign,

	// brackets
	Open_Paren,
	Close_Paren,
	Open_Bracket,
	Close_Bracket,
	Open_SB,
	Close_SB,

	// identifiers
	Val,
	Mut,
	Fn,
	Return,
	If,
	Else,
	Do,
	Struct,
	For,
	Identifier,
	Defer,
	In,
	Break,
	Continue,
	As,
	As_Bang,
	Trait,

	// numbers
	Int_Literal,
	Float_Literal,

	// strings
	String_Literal,
}

Span :: struct {
	start: int, // inclusive rune index
	end:   int, // exclusive rune index
}

Spanned_Token :: struct {
	kind: Token,
	span: Span,
}
