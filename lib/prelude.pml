// Unit type.
type unit = {}

// Booleans.
type bool = [Tru ; Fls]

val tru : bool = Tru[]
val fls : bool = Fls[]

def if<c:τ,t:τ,e:τ> : τ =
  case c of
  | Tru[] → t
  | Fls[] → e

val and : bool ⇒ bool ⇒ bool = fun a b → if<a, b, fls>

val or  : bool ⇒ bool ⇒ bool = fun a b → if<a, tru, b>

// Option type.
type option<a:ο> = [None ; Some of a]

val none : ∀a:ο, option<a> = None[{}]
val some : ∀a:ο, a ⇒ option<a> = fun e → Some[e]

val map_opt : ∀a b:ο, (a ⇒ b) ⇒ option<a> ⇒ option<b> = fun fn o →
  case o of
  | None[_] → none
  | Some[e] → some (fn e)
