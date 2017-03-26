module ListMap =
  struct
    type key = string

    type 'a t = (key * 'a) list

    let empty = []
    let singleton k v = [(k, v)]
    let add k v l = l @ [(k, v)]

    let mem = List.mem_assoc
    let find = List.assoc

    let map  f l = List.map (fun (k, v) -> (k, f v)) l
    let mapi f l = List.map (fun (k, v) -> (k, f k v)) l

    let bindings l = l

    let fold f l acc = List.fold_left (fun acc (k, v) -> f k v acc) acc l

    let iter f l = List.iter (fun (k, v) -> f k v) l

    let equal cmp l1 l2 =
      let kcmp (k1,_) (k2,_) = String.compare k1 k2 in
      let vcmp (_,v1) (_,v2) = cmp v1 v2 in
      let len = List.length l1 in
      if len <> List.length l2 then false else
      let k1 = List.sort_uniq kcmp l1 in
      let k2 = List.sort_uniq kcmp l2 in
      if List.length k1 <> len then false else
      if List.length k2 <> len then false else
      if List.map fst k1 <> List.map fst k2 then false else
      List.for_all2 vcmp k1 k2
  end

include ListMap

open Bindlib

let lift_box : 'a bindbox t -> 'a t bindbox =
  fun m -> let module B = Lift(ListMap) in B.f m

let map_box : ('b -> 'a bindbox) -> 'b t -> 'a t bindbox =
  fun f m -> lift_box (map f m)