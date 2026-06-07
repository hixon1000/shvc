package stock_types

// same as void in c
Unit :: struct {}

Bool :: struct {}

Integer :: struct {}
Integer8 :: struct {}
Integer32 :: struct {}
Integer64 :: struct {}

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
	String,
	Array,
	Pointer,
	Custom_Type,
}
