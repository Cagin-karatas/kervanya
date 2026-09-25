class_name TileDefs
extends RefCounted
## Yol parçası tanımları ve yön bit maskeleri.
## Yönler: N=1, E=2, S=4, W=8. Döndürme her zaman saat yönünde 90 derecedir.

enum Type { STRAIGHT = 0, CORNER = 1 }

const N := 1
const E := 2
const S := 4
const W := 8
const ALL := 15
const DIRS: Array[int] = [N, E, S, W]

const BASE_MASK := {
	Type.STRAIGHT: N | S,
	Type.CORNER: N | E,
}

const TYPE_NAMES := {
	Type.STRAIGHT: "straight",
	Type.CORNER: "corner",
}


static func dir_offset(d: int) -> Vector2i:
	match d:
		N:
			return Vector2i(0, -1)
		E:
			return Vector2i(1, 0)
		S:
			return Vector2i(0, 1)
		W:
			return Vector2i(-1, 0)
	return Vector2i.ZERO


static func dir_between(from: Vector2i, to: Vector2i) -> int:
	var delta := to - from
	for d in DIRS:
		if dir_offset(d) == delta:
			return d
	return 0


static func rotate_mask(mask: int, steps: int) -> int:
	var m := mask
	for i in range(posmod(steps, 4)):
		m = ((m << 1) | (m >> 3)) & ALL
	return m


static func opposite(d: int) -> int:
	return rotate_mask(d, 2)


static func rotation_count(type: int) -> int:
	return 2 if type == Type.STRAIGHT else 4


static func mask_of(type: int, rot: int) -> int:
	return rotate_mask(BASE_MASK[type], rot)


static func rotation_for_mask(type: int, mask: int) -> int:
	for r in range(rotation_count(type)):
		if mask_of(type, r) == mask:
			return r
	return -1


static func type_for_mask(mask: int) -> int:
	if mask == (N | S) or mask == (E | W):
		return Type.STRAIGHT
	for r in range(4):
		if mask_of(Type.CORNER, r) == mask:
			return Type.CORNER
	return -1


static func type_from_name(type_name: String) -> int:
	for t in TYPE_NAMES:
		if TYPE_NAMES[t] == type_name:
			return t
	return -1
