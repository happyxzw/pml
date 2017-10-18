open Ast
open Compare
open Uvars
open Sorts
open Pos

let owmu_counter = ref (-1)
let ownu_counter = ref (-1)
let osch_counter = ref (-1)

module VWitHash = Hashtbl.Make(VWit)
let vwit_hash    = VWitHash.create 256

module QWitHash = Hashtbl.Make(QWit)
type aqwit = Q : 'a qwit eps -> aqwit
let qwit_hash    = QWitHash.create 256

module OWitHash = Hashtbl.Make(OWit)
let owit_hash    = OWitHash.create 256

let swit_counter = ref (-1)

let reset_counters : unit -> unit = fun () ->
  osch_counter := (-1); swit_counter := (-1)

let osch : ordi option -> int -> schema -> ordi =
  fun o i s -> incr osch_counter; Pos.none (OSch(!osch_counter, (o,i,s)))

let vwit : (v,t) bndr -> prop -> prop -> valu =
  fun f a b ->
    let valu = (f,a,b) in
    let w =
      try VWitHash.find vwit_hash valu
      with Not_found ->
        let rec refr ?(force=false) w =
          if force || exists_set !(w.vars) then
            begin
              let oldvars = !(w.vars) in
              Timed.(w.vars := VWit.vars valu);
              Timed.(w.hash := VWit.hash valu);
              List.iter (fun (U(_,v)) ->
                  let same (U(_,w)) = v.uvar_key = w.uvar_key in
                  if not (List.exists same oldvars)
                  then uvar_hook v (fun () -> refr w)) !(w.vars);
              try
                let w' = VWitHash.find vwit_hash valu in
                (*Printf.eprintf "merge vwit\n%!";*)
                Timed.(w.valu := !(w'.valu))
              with Not_found ->
                VWitHash.add vwit_hash valu w
            end
        in
        let rec w = { vars = ref []
                    ; hash = ref 0
                    ; refr = (fun () -> refr w)
                    ; valu = ref valu}
        in
        refr ~force:true w;
        w
    in
    Pos.none (VWit(w))

let qwit : type a. a sort -> term -> (a,p) bndr -> a qwit eps =
  fun s t b ->
    let valu = (s,t,b) in
    let key = QWit.Q(valu) in
    try
      let Q(w) = QWitHash.find qwit_hash key in
      let (s',_,_) = !(w.valu) in
      match eq_sort s s' with
      | Eq.Eq -> w
      | _ -> assert false
    with Not_found ->
      let rec refr ?(force=false) w =
        if force || exists_set !(w.vars) then
          begin
            let oldvars = !(w.vars) in
            Timed.(w.vars := QWit.vars key);
            Timed.(w.hash := QWit.hash key);
            List.iter (fun (U(_,v)) ->
                let same (U(_,w)) = v.uvar_key = w.uvar_key in
                if not (List.exists same oldvars)
                then uvar_hook v (fun () -> refr w)) !(w.vars);
            try
              let Q(w') = QWitHash.find qwit_hash key in
              (*Printf.eprintf "merge qwit\n%!";*)
              let (s',_,_) = !(w'.valu) in
              match eq_sort s s' with
              | Eq.Eq -> Timed.(w.valu := Obj.magic !(w'.valu))
              | _ -> assert false
            with Not_found ->
              QWitHash.add qwit_hash key (Q w)
          end
      in
      let rec w = { vars = ref []
                  ; hash = ref 0
                  ; refr = (fun () -> refr w)
                  ; valu = ref valu}
      in
      refr ~force:true w;
      w

let owit : ordi -> term -> (o,p) bndr -> owit eps =
  fun o a b ->
    let valu = (o,a,b) in
    try OWitHash.find owit_hash valu
    with Not_found ->
      let rec refr ?(force=false) w =
        if force || exists_set !(w.vars) then
          begin
            let oldvars = !(w.vars) in
            Timed.(w.vars := OWit.vars valu);
            Timed.(w.hash := OWit.hash valu);
            List.iter (fun (U(_,v)) ->
                let same (U(_,w)) = v.uvar_key = w.uvar_key in
                if not (List.exists same oldvars)
                then uvar_hook v (fun () -> refr w)) !(w.vars);
            try
              let w' = OWitHash.find owit_hash valu in
              (*Printf.eprintf "merge owit\n%!";*)
              Timed.(w.valu := !(w'.valu))
            with Not_found ->
              OWitHash.add owit_hash valu w
          end
      in
      let rec w = { vars = ref []
                  ; hash = ref 0
                  ; refr = (fun () -> refr w)
                  ; valu = ref valu}
      in
      refr ~force:true w;
      w

let uwit : type a. a sort -> term -> (a,p) bndr -> a ex loc =
  fun s t f -> Pos.none (UWit(qwit s t f))

let ewit : type a. a sort -> term -> (a,p) bndr -> a ex loc =
  fun s t f -> Pos.none (EWit(qwit s t f))

let owmu : ordi -> term -> (o, p) bndr -> ordi =
  fun o t b -> Pos.none (OWMu(owit o t b))

let ownu : ordi -> term -> (o, p) bndr -> ordi =
  fun o t b -> Pos.none (OWNu(owit o t b))


let swit : (s,t) bndr -> prop -> stac =
  fun f a -> incr swit_counter; Pos.none (SWit(!swit_counter, (f,a)))
