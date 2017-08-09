open Sorts
open Eval
open Ast
open Pos

type any_sort = Sort : 'a sort           -> any_sort
type any_expr = Expr : 'a sort * 'a expr -> any_expr

module SMap = Map.Make(String)

type env =
  { global_sorts  : any_sort SMap.t
  ; local_sorts   : any_sort SMap.t
  ; global_exprs  : any_expr SMap.t
  ; local_exprs   : any_expr SMap.t
  ; global_values : value SMap.t
  ; local_values  : value SMap.t }

let empty =
  { global_sorts  = SMap.empty
  ; local_sorts   = SMap.empty
  ; global_exprs  = SMap.empty
  ; local_exprs   = SMap.empty
  ; global_values = SMap.empty
  ; local_values  = SMap.empty }

let find_sort : string -> env -> any_sort =
  fun id env -> SMap.find id env.global_sorts

let find_expr : string -> env -> any_expr =
  fun id env -> SMap.find id env.global_exprs

let find_value : string -> env -> value =
  fun id env -> SMap.find id env.global_values

let add_sort : type a. string -> a sort -> env -> env =
  fun id s env ->
    let global_sorts = SMap.add id (Sort s) env.global_sorts in
    let local_sorts = SMap.add id (Sort s) env.local_sorts in
    {env with global_sorts; local_sorts}

let add_expr : type a. strloc -> a sort -> a box -> env -> env =
  fun expr_name s expr_box env ->
    let expr_def = Bindlib.unbox expr_box in
    let ex = Expr(s, {expr_name; expr_def}) in
    let global_exprs = SMap.add expr_name.elt ex env.global_exprs in
    let local_exprs = SMap.add expr_name.elt ex env.local_exprs in
    {env with global_exprs; local_exprs}

let add_value : strloc -> term -> prop -> e_valu -> env -> env =
  fun value_name value_orig value_type value_eval env ->
    let nv = {value_name; value_type; value_orig; value_eval} in
    let global_values = SMap.add value_name.elt nv env.global_values in
    let local_values = SMap.add value_name.elt nv env.local_values in
    {env with global_values; local_values}

let parents = ref []

let output_value ch v = Marshal.(to_channel ch v [Closures])
let input_value ch = Marshal.from_channel ch

let save_file : env -> string -> unit = fun env fn ->
  let cfn = Filename.chop_suffix fn ".pml" ^ ".pmi" in
  let ch = open_out cfn in
  let deps =
    match !parents with
    | []   -> assert false
    | _::l -> let deps = List.concat (List.map (!) !parents) in
              parents := l; List.sort_uniq String.compare deps
  in
  output_value ch deps;
  output_value ch (env.local_sorts, env.local_exprs, env.local_values);
  close_out ch

exception Compile

(* Test if a file is more recent than another file. *)
let more_recent source target =
  not (Sys.file_exists target) ||
  Unix.((stat source).st_mtime > (stat target).st_mtime)

let start fn =
  parents := ref [] :: !parents

let load_file : env -> string -> env = fun env fn ->
  let cfn = Filename.chop_suffix fn ".pml" ^ ".pmi" in
  begin
    match !parents with
    | [] -> ()
    | dep::_ -> dep := fn :: !dep
  end;
  if more_recent fn cfn then
    raise Compile
  else
    let ch = open_in cfn in
    let deps = input_value ch in
    if List.exists (fun source -> more_recent source cfn) deps then
      begin
        close_in ch;
        raise Compile;
      end
    else
      begin
        match !parents with
        | [] -> ()
        | dep::_ -> dep := deps @ !dep
      end;
    let (local_sorts, local_exprs, local_values) = input_value ch in
    close_in ch;
    let global_sorts  = SMap.fold SMap.add local_sorts env.global_sorts  in
    let global_exprs  = SMap.fold SMap.add local_exprs env.global_exprs  in
    let global_values = SMap.fold SMap.add local_values env.global_values in
    { env with global_sorts; global_exprs; global_values }
