package stock_types

// same as void in c
Unit :: struct {}

Bool :: struct {}

Integer :: struct {}
Integer8 :: struct {}
Integer32 :: struct {}
Integer64 :: struct {}

String :: struct {}

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
	Pointer,
	Custom_Type,
}
