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

package stock_types

// same as void in c
Unit :: struct {}

Bool :: struct {}

Integer :: struct {}
Integer8 :: struct {}
Integer32 :: struct {}
Integer64 :: struct {}

Float32 :: struct {}
Float64 :: struct {}

String :: struct {}

Array_Count_Kind :: enum {
	Fixed, // [3]i32
	Infer, // [?]i32
	Dynamic, // [dynamic]i32
	Slice, // []i32
}

Array :: struct {
	count_kind: Array_Count_Kind,
	// only care about this when it is .Fixed
	// otherwise this can just be 0
	count:      int,
	elem:       ^Types,
}

Pointer :: struct {
	elem: ^Types,
}

Custom_Type :: struct {
	name: string,
}

Types :: union {
	Unit,
	Bool,
	Integer,
	Integer8,
	Integer32,
	Integer64,
	Float32,
	Float64,
	String,
	Array,
	Pointer,
	Custom_Type,
}
