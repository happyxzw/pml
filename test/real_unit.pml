// Usual « unit » type (i.e. empty product).
def unit : ο = {}

// It is inhabited by the empty record.
val u : unit = {}

// It is in fact inhabited by any record...
val u_aux : unit = {l = {}}


// We can define a real (one element) « unit » type as follows.
def real_unit : ο = ∃ x:ι, (x ∈ {}) | x ≡ {} 

// It is still inhabited by the empty record.
val unit : real_unit = {}


// But any other record is not in this type.
// val unit_bad : real_unit = {l = {}}
