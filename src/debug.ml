
open Pp
open Format

let debug_out = ref std_formatter

let debug_to_file fn = debug_out := formatter_of_out_channel (open_out fn)

type 'a printer = formatter -> 'a -> unit

let debug_flag = ref false

let debug_start () = debug_flag := true
let debug_stop  () = debug_flag := false

let debug fmt =
  if !debug_flag
  then kfprintf (fun _ -> pp_print_newline !debug_out ()) !debug_out fmt
  else ifprintf err_formatter fmt


let string_of fp = Format.asprintf "%a" fp

let format_of_sep str fmt () : unit =
  Format.fprintf fmt "%s" str

let pp_list sep pp fmt l = Format.pp_print_list ~pp_sep:(format_of_sep sep) pp fmt l


let pp_std_ppcmds = pp_with

let printer_of_std_ppcmds f fmt x = fprintf fmt "%a" pp_std_ppcmds (f x)


let pp_coq_term  = printer_of_std_ppcmds Printer.safe_pr_constr
let pp_coq_type  = printer_of_std_ppcmds Printer.pr_type
let pp_coq_level = printer_of_std_ppcmds Univ.Level.pr
let pp_coq_univ  = printer_of_std_ppcmds Univ.Universe.pr
let pp_coq_inst  = printer_of_std_ppcmds (Univ.Instance.pr (Univ.Level.pr))
let pp_coq_id    = printer_of_std_ppcmds Names.Id.print

let pp_coq_name fmt = function
  | Names.Name.Anonymous -> fprintf fmt "_"
  | Names.Name.Name n    -> fprintf fmt "%a" pp_coq_id n

let pp_coq_sort fmt = function
  | Term.Prop Term.Null -> fprintf fmt "Set"
  | Term.Prop Term.Pos  -> fprintf fmt "Prop"
  | Term.Type i         -> fprintf fmt "Univ(%a)" pp_coq_univ i

let pp_coq_decl fmt = function
  | Context.Rel.Declaration.LocalAssum (name, t) ->
    fprintf fmt "%a = %a" pp_coq_name name pp_coq_term t
  | Context.Rel.Declaration.LocalDef (name, v, t) ->
    fprintf fmt "%a : %a = %a" pp_coq_name name pp_coq_term t pp_coq_term t

let pp_coq_named_decl fmt = function
  | Context.Named.Declaration.LocalAssum (id, t) ->
    fprintf fmt "%a = %a" pp_coq_id id pp_coq_term t
  | Context.Named.Declaration.LocalDef (id, v, t) ->
    fprintf fmt "%a : %a = %a" pp_coq_id id pp_coq_term t pp_coq_term t

let pp_coq_ctxt fmt ctxt =
  fprintf fmt "[\n  %a\n]" (pp_list "\n  " pp_coq_decl) ctxt

let pp_coq_named_ctxt fmt ctxt =
  fprintf fmt "[\n  %a\n]" (pp_list "\n  " pp_coq_named_decl) ctxt

let pp_coq_env fmt e =
  fprintf fmt "%a\n%a"
    pp_coq_ctxt       (Environ.rel_context e)
    pp_coq_named_ctxt (Environ.named_context e)
