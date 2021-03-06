(** Evaluation in an abstract machine. *)

open Bindlib
open Pos
open Output
open Sorts
open Ast
open Eval

exception Erasure_error of string
let erasure_error : type a. string -> a =
  fun msg -> raise (Erasure_error msg)

let rec valu_erasure : valu -> e_vbox = fun v ->
  let v = Norm.whnf v in
  match v.elt with
  | Vari(_,x)   -> box_var (copy_var x mk_vvari (name_of x))
  | HApp(_)     -> erasure_error "not a normalisation value (value)"
  | HDef(_,d)   -> valu_erasure d.expr_def
  | LAbs(_,b)   -> let f x =
                     let x = copy_var x (mk_free V) (name_of x) in
                     term_erasure (bndr_subst b (mk_free V x))
                   in vlabs (binder_name (snd b)) f
  | Cons(c,v)   -> vcons c.elt (valu_erasure v)
  | Reco(m)     -> vreco (A.map (fun (_,v) -> valu_erasure v) m)
  | Scis        -> vscis
  | Goal(_,s)   -> vscis
  | VDef(d)     -> vvdef d
  | Coer(_,v,_) -> valu_erasure v
  | Such(_,_,r) -> valu_erasure (bseq_dummy r.binder)
  | PSet(_,_,v) -> valu_erasure v
  | VPtr(_)     -> erasure_error "a pool pointer cannot be erased (value)"
  | ITag(_)     -> erasure_error "a tag cannot be erased (value)"
  | Dumm(_)     -> erasure_error "a dummy value cannot be erased (value)"
  | VWit(_)     -> erasure_error "a witness cannot be erased (value)"
  | UWit(_)     -> erasure_error "a witness cannot be erased (value)"
  | EWit(_)     -> erasure_error "a witness cannot be erased (value)"
  | UVar(_)     -> erasure_error "unif. variables cannot be erased (value)"

and     term_erasure : term -> e_tbox = fun t ->
  let t = Norm.whnf t in
  match t.elt with
  | Vari(_,x)   -> box_var (copy_var x mk_tvari (name_of x))
  | HApp(_)     -> erasure_error "not a normalisation value (term)"
  | HDef(_,d)   -> term_erasure d.expr_def
  | Valu(v)     -> tvalu (valu_erasure v)
  | Appl(t,u)   -> tappl (term_erasure t) (term_erasure u)
  | FixY(_,b)   -> let f x =
                     let x = copy_var x (mk_free T) (name_of x) in
                     valu_erasure (bndr_subst b (mk_free T x))
                   in tfixy (binder_name (snd b)) f
  | MAbs(b)     -> let f x =
                     let x = copy_var x (mk_free S) (name_of x) in
                     term_erasure (bndr_subst b (mk_free S x))
                   in tmabs (binder_name (snd b)) f
  | Name(s,t)   -> tname (stac_erasure s) (term_erasure t)
  | Proj(v,l)   -> tproj (valu_erasure v) l.elt
  | Case(v,m)   -> let f (_,b) =
                     let f x =
                       let x = copy_var x (mk_free V) (name_of x) in
                       term_erasure (bndr_subst b (mk_free V x))
                     in (binder_name (snd b), f)
                   in tcase (valu_erasure v) (A.map f m)
  | Prnt(s)     -> tprnt s
  | Repl(t,_)   -> term_erasure t
  | Delm(t)     -> term_erasure t
  | Coer(_,t,_) -> term_erasure t
  | Such(_,_,r) -> term_erasure (bseq_dummy r.binder)
  | PSet(_,_,t) -> term_erasure t
  | TPtr(_)     -> erasure_error "a pool pointer cannot be erased (term)"
  | ITag(_)     -> erasure_error "a tag cannot be erased (term)"
  | Dumm(_)     -> erasure_error "a dummy value cannot be erased (term)"
  | UWit(_)     -> erasure_error "a witness cannot be erased (term)"
  | EWit(_)     -> erasure_error "a witness cannot be erased (term)"
  | UVar(_)     -> erasure_error "unif. variables cannot be erased (term)"
  | Goal(_)     -> erasure_error "a goal cannot be erased (term)"

and     stac_erasure : stac -> e_sbox = fun s ->
  let s = Norm.whnf s in
  match s.elt with
  | Vari(_,x) -> box_var (copy_var x mk_svari (name_of x))
  | HApp(_)   -> erasure_error "not a normalisation value (stack)"
  | HDef(_,d) -> stac_erasure d.expr_def
  | Goal(_)   -> sepsi
  | ITag(_)   -> erasure_error "a tag cannot be erased (stack)"
  | Dumm(_)   -> erasure_error "a dummy value cannot be erased (stack)"
  | SWit(_)   -> erasure_error "a witness cannot be erased (stack)"
  | UWit(_)   -> erasure_error "a witness cannot be erased (stack)"
  | EWit(_)   -> erasure_error "a witness cannot be erased (stack)"
  | UVar(_)   -> erasure_error "unif. variables cannot be erased (stack)"
  | Coer(_)   -> .
  | Such(_)   -> .
  | PSet(_)   -> .


let valu_erasure : valu -> e_valu =
  fun v -> unbox (valu_erasure v)

let term_erasure : term -> e_term =
  fun t -> unbox (term_erasure t)

let stac_erasure : stac -> e_stac =
  fun s -> unbox (stac_erasure s)

(* Conversion of erased expression to expression. *)

(** Evaluation in an abstract machine. *)
let rec to_valu : e_valu -> vbox = fun v ->
  match v with
  | VVari(x)   -> vari None (copy_var x (mk_free V) (name_of x))
  | VLAbs(b)   -> let f x =
                    let x = copy_var x mk_vvari (name_of x) in
                    to_term (subst b (mk_vvari x))
                  in labs None None (Pos.none (binder_name b)) f
  | VCons(c,v) -> cons None (Pos.none c) (to_valu v)
  | VReco(m)   -> reco None (A.map (fun v -> (None, to_valu v)) m)
  | VVdef(d)   -> box (Pos.none (VDef d))
  | VScis      -> scis None

and to_term : e_term -> tbox = fun t ->
  match t with
  | TVari(a)   -> vari None (copy_var a (mk_free T) (name_of a))
  | TValu(v)   -> valu None (to_valu v)
  | TAppl(t,u) -> appl None (to_term t) (to_term u)
  | TFixY(b)   -> let f x =
                    let x = copy_var x mk_tvari (name_of x) in
                    to_valu (subst b (mk_tvari x))
                  in
                  fixy None false (Pos.none (binder_name b)) f
  | TMAbs(b)   -> let f x =
                    let x = copy_var x mk_svari (name_of x) in
                    to_term (subst b (mk_svari x))
                  in mabs None (Pos.none (binder_name b)) f
  | TName(s,t) -> to_stac s (to_term t)
  | TProj(v,l) -> proj None (to_valu v) (Pos.none l)
  | TCase(v,m) -> let f b =
                    let f x =
                      let x = copy_var x mk_vvari (name_of x) in
                      to_term (subst b (mk_vvari x))
                    in (None, Pos.none (binder_name b), f)
                  in case None (to_valu v) (A.map f m)
  | TPrnt(s)   -> prnt None s

and to_stac : e_stac -> tbox -> tbox = fun s t ->
  let rec fn s t =
    match s with
    | SVari(a)   -> name None (vari None
                       (copy_var a (mk_free S) (name_of a))) t
    | SEpsi      -> t
    | SPush(v,s) -> fn s (appl None t (valu None (to_valu v)))
    | SFram(u,s) -> fn s (appl None (to_term u) t)
  in fn s t

let to_valu : e_valu -> valu =
  fun v -> unbox (to_valu v)

let to_term : e_term -> term =
  fun t -> unbox (to_term t)
