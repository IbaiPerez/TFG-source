extends RefCounted
class_name Comparison

enum Type { GREATER, GREATER_EQUAL, LESS, LESS_EQUAL, EQUAL }

static func evaluate(a:float, op:Type, b:float) -> bool:
	match op:
		Type.GREATER: return a > b
		Type.GREATER_EQUAL: return a >= b
		Type.LESS: return a < b
		Type.LESS_EQUAL: return a <= b
		Type.EQUAL: return is_equal_approx(a, b)
	return false
