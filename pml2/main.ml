open Bindlib
open Blank
open Parser
open Pos
open Raw
open Typing
open Output
open Eval
open Config

let _ = Printexc.record_backtrace true
let _ = Sys.catch_break true

(* Command line argument parsing. *)
let files =
  let files = ref [] in

  let anon_fun fn = files := fn :: !files in
  let usage_msg =
    Printf.sprintf "Usage: %s [args] [f1.pml] ... [fn.pml]" Sys.argv.(0)
  in

  let r_spec = ref [] in
  let help f =
    let act () = raise (Arg.Help (Arg.usage_string !r_spec usage_msg)) in
    (f, Arg.Unit(act), " Show this usage message.")
  in

  let spec =
    [ ( "--log-file"
      , Arg.String(Log.with_file)
      , "file Write logs to the provided file." )
    ; ( "--log"
      , Arg.String(Log.set_enabled)
      , Printf.sprintf "str Enable the provided logs. Available options:\n%s."
          (Log.opts_to_string ((String.make 20 ' ') ^ "- ")) )
    ; ( "--full-compare"
      , Arg.Set Compare.full_eq
      , " Show all the steps when comparing expressions.")
    ; ( "--always-colors"
      , Arg.Set Output.always_colors
      , " Always use colors.")
    ; ( "--timed"
      , Arg.Tuple [Arg.Set timed; Arg.Set recompile]
      , " Display a timing report after the execution.")
    ; ( "--recompile"
      , Arg.Set recompile
      , " Force compilation of files given on command line.")
    ; ( "--quiet"
      , Arg.Clear verbose
      , " Disables the printing definition data.")
    ] @ List.map help ["--help" ; "-help" ; "-h" ]
  in
  let spec = Arg.align spec in
  r_spec := spec;

  (* Run checks on files. *)
  Arg.parse spec anon_fun usage_msg;
  let files = List.rev !files in

  let check_ext fn =
    if not (Filename.check_suffix fn ".pml") then
      begin
        err_msg "File \"%s\" does not have the \".pml\" extension." fn;
        exit 1
      end
  in
  List.iter check_ext files;
  let check_exists fn =
    if not (Sys.file_exists fn) then
      begin
        err_msg "File \"%s\" does not exist." fn;
        exit 1
      end;
    if Sys.is_directory fn then
      begin
        err_msg "\"%s\" is not a file, but a directory." fn;
        exit 1
      end
  in
  List.iter check_exists files;
  files

let _ =
  let rec print_exn = function
  | Type_error(E(_,t),c,exc) ->
      begin
        match t.pos with
        | None   -> err_msg "Type error:\n%a : %a"
                      Print.ex t Print.ex c
        | Some p -> err_msg "Type error %a:\n%a : %a"
                      Pos.print_short_pos p Print.ex t Print.ex c;
                    Quote.quote_file stderr p
     end; print_exn exc
  | Typing.Subtype_error(t,a,b,e) ->
      begin
        match t.pos with
        | None   -> err_msg "Subtype error:\n%a ∈ %a ⊂ %a"
                      Print.ex t Print.ex a Print.ex b
        | Some p -> err_msg "SubType error %a:\n  %a ∈ %a ⊂ %a"
                      Pos.print_short_pos p Print.ex t Print.ex a Print.ex b;
                    Quote.quote_file stderr p
      end; print_exn e
  | Typing.Loops(t) ->
      begin
        match t.pos with
        | None   -> err_msg "Cannot prove termination of\n  %a" Print.ex t
        | Some p -> err_msg "Cannot prove termination.";
                    Quote.quote_file stderr p
      end
  | Typing.Subtype_msg(p,msg) ->
      begin
        match p with
        | None   -> err_msg "Subtype error:\n%s." msg
        | Some p -> err_msg "Subtype error %a:\n%s."
                      Pos.print_short_pos p msg;
                    Quote.quote_file stderr p
      end
  | Typing.Cannot_unify(a,b) ->
      err_msg "Unable to unify %a and %a." Print.ex a Print.ex b
  | Typing.Reachable            ->
      err_msg "Reachable scissors"
  | Equiv.Failed_to_prove(rel,_)  ->
      err_msg "Failed to prove an equational relation.";
      err_msg "  %a" Print.rel rel
  | Check_failed(a,n,b) ->
      let (l,r) = if n then ("","") else ("¬(",")") in
      err_msg "Failed to prove a subtyping relation.";
      begin
        let pp = Pos.print_short_pos in
        match (a.pos, b.pos) with
        | (Some pa, Some pb) -> err_msg "  %s(%a) ⊂ (%a)%s" l pp pa pp pb r
        | (_      , _      ) -> ()
      end;
      err_msg "  %s%a ⊂ %a%s" l Print.ex a Print.ex b r
  | No_typing_IH(id)             ->
      begin
        err_msg "No typing induction hypothesis applies for %S." id.elt;
        match id.pos with
        | None   -> ()
        | Some p -> Quote.quote_file stderr p
      end
  | e ->
      err_msg "Unexpected exception [%s]." (Printexc.to_string e);
      err_msg "%t" Printexc.print_backtrace;
  in
  try List.iter (handle_file true) files with
  | e -> print_exn e; exit 1


let _ =
  let total = ref 0.0 in
  if !timed then
    begin
      Printf.eprintf   "%10s   %8s  %8s %8s\n" "name" "self" "cumul" "count";
      let f name time cumul c =
        total := !total +. time;
        Printf.eprintf "%10s: %8.2fs %8.2fs %8d\n" name time cumul c
      in
      Chrono.iter f;
      Printf.eprintf "%10s: %8.2fs\n" "total" !total
    end
