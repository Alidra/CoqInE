(** Translation of Coq modules *)

open Declarations

let translate_constant_type out module_path env const_type =
  match const_type with
  | NonPolymorphicType(a) ->
      Terms.translate_types out env a
  | PolymorphicArity(rel_context, poly_arity) ->
      failwith "Not implemented: PolymorphicArity"

let translate_constant_body out module_path env label const =
  let label' = Name.translate_label label in
  (* TODO: Handle [constant_body.const_hyps] *)
  let const_type' = translate_constant_type out module_path env const.const_type in
  match const.const_body with
  | Undef(inline) ->
      Dedukti.print out (Dedukti.declaration label' const_type')
  | Def(constr_substituted) ->
      let constr' = Terms.translate_constr out env (Declarations.force constr_substituted) in
      Dedukti.print out (Dedukti.definition false label' const_type' constr')
  | OpaqueDef(lazy_constr) ->
      let constr' = Terms.translate_constr out env (Declarations.force_opaque lazy_constr) in
      Dedukti.print out (Dedukti.definition true label' const_type' constr')

let get_inductive_arity_sort ind_arity =
  match ind_arity with
  | Monomorphic(mono_ind_arity) -> mono_ind_arity.mind_sort
  | Polymorphic(poly_arity) -> Term.Type(poly_arity.poly_level)

(** Translate the i-th inductive body in [mind_body]. *)
let translate_one_inductive_body out module_path env label mind_body i =
  let ind_body = mind_body.mind_packets.(i) in
  let mind = Names.make_mind module_path Names.empty_dirpath label in
  let ind_term i = Term.mkInd(mind, i) in
  (* Constructor names start from 1. *)
  let cons_term i j = Term.mkConstruct((mind, i), j + 1) in
  (* Translate the inductive type. *)
  let name = ind_body.mind_typename in
  let arity_context = ind_body.mind_arity_ctxt in
  let arity_sort = get_inductive_arity_sort ind_body.mind_arity in
  let arity = Term.it_mkProd_or_LetIn (Term.mkSort arity_sort) arity_context in
  let name' = Name.translate_identifier name in
  let arity' = Terms.translate_types out env arity in
  Dedukti.print out (Dedukti.declaration name' arity');
  (* Translate the constructors. *)
  let m = Array.length ind_body.mind_consnames in
  let cons_names = ind_body.mind_consnames in
  (* Substitute the inductive types as specified in the Coq code. *)
  let ind_terms = Array.init mind_body.mind_ntypes ind_term in
  let cons_types = Array.map (Term.substl (Array.to_list ind_terms)) ind_body.mind_user_lc in
  for j = 0 to m - 1 do
    let cons_name' = Name.translate_identifier cons_names.(j) in
    let cons_type' = Terms.translate_types out env cons_types.(j) in
    Dedukti.print out (Dedukti.declaration cons_name' cons_type');
  done;
  (* Use the normalized types in the rest. *)
  let cons_types = Array.map (Term.substl (Array.to_list ind_terms)) ind_body.mind_nf_lc in
  (* Generate the match function. *)
  (* match_I : s : srt -> P : (|x1| : ||A1|| -> ... -> |xn| : ||An|| -> ||I x1 ... xn|| -> type s) ->
       case_c1 : (|y11| : ||B11|| -> ... -> |y1k1| : ||B1k1|| -> term s (P |u11| ... |u1n| (|c1 y11 ... y1k1|))) ->
       ...
       case_cm : (|ym1| : ||Bm1|| -> ... -> |ymk1| : ||Bmkm|| -> term s (P |um1| ... |umn| (|cm ym1 ... ymkm|))) ->
       |x1| : ||A1|| -> ... -> |xn| : ||An|| -> x : ||I x1 ... xn|| -> term s (P |x1| ... |xn| x) *)
  let match_function_name = Name.match_function name in
  let return_sort_name = Name.mangled_identifier [] "s" in
  let return_type_name = Name.mangled_identifier [] "return" in
  let matched_name = Name.mangled_identifier [] "as" in
  let arity_context = List.map (Terms.ensure_name ["var"]) arity_context in
  let ind_applied = Terms.apply_rel_context (ind_term i) arity_context in
  let match_function_name' = Name.translate_identifier match_function_name in
  let return_sort_name' = Name.translate_identifier return_sort_name in
  let return_type_name' = Name.translate_identifier return_type_name in
  let matched_name' = Name.translate_identifier matched_name in
  let return_sort' = Dedukti.var return_sort_name' in
  let return_type' = Dedukti.var return_type_name' in
  let matched' = Dedukti.var matched_name' in
  let arity_env, arity_context' = Terms.translate_rel_context out env arity_context in
  let ind_applied' = Terms.translate_types out arity_env ind_applied in
  let case' j =
    let case_name = Name.mangle_identifier ["case"] cons_names.(j) in
    let cons_context, cons_type = Term.decompose_prod_assum cons_types.(j) in
    let ind_args = Terms.inductive_args env cons_type in
    let cons_applied = Terms.apply_rel_context (cons_term i j) cons_context in
    let case_name' = Name.translate_identifier case_name in
    let cons_env, cons_context' = Terms.translate_rel_context out env cons_context in
    let ind_args' =  Array.to_list (Array.map (Terms.translate_constr out cons_env) ind_args) in
    let cons_applied' = Terms.translate_constr out cons_env cons_applied in
    (case_name', Dedukti.pies cons_context'
      (Terms.coq_term return_sort' (Dedukti.apps return_type' (ind_args' @ [cons_applied'])))) in
  Dedukti.print out (Dedukti.declaration match_function_name' (Dedukti.pies (
    (return_sort_name', Universes.coq_srt) ::
    (return_type_name', Dedukti.pies arity_context' (Dedukti.arr ind_applied' (Terms.coq_type return_sort'))) ::
    (arity_context') @
    (matched_name', ind_applied') ::
    Array.to_list (Array.init m case'))
    (Terms.coq_term return_sort' (Dedukti.apps return_type' (Dedukti.vars (fst (List.split arity_context')) @ [matched'])))))
    
  (* Generate the fix function. *)

(** Translate the body of mutual inductive definitions [mind]. *)
let translate_mutual_inductive_body out module_path env label mind_body =
  for i = 0 to mind_body.mind_ntypes - 1 do
    translate_one_inductive_body out module_path env label mind_body i
  done

let rec translate_module_body out module_path env mods =
  match mods.mod_expr with
  | Some(struct_expr) -> translate_struct_expr_body out module_path env struct_expr
  | None -> ()

and translate_struct_expr_body out module_path env struct_expr =
  match struct_expr with
  | SEBstruct(structs) -> translate_structure_body out module_path env structs
  | _ -> ()

and translate_structure_body out module_path env structure_body =
  List.iter (translate_structure_field_body out module_path env) structure_body

and translate_structure_field_body out module_path env (label, struct_field_body) =
  match struct_field_body with
  | SFBconst(const_body) -> translate_constant_body out module_path env label const_body
  | SFBmind(mind_body) -> translate_mutual_inductive_body out module_path env label mind_body
  | _ -> ()

