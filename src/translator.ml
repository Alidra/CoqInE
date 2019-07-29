
open Dedukti
open Encoding

type cic_universe =
  | Prop
  | Set
  | LocalNamed of string
  | Local of int
  | Template of string
  | Global of string
  | Succ of cic_universe * int
  | Max of cic_universe list
  | Rule of cic_universe * cic_universe

(* Note:
  Succ(Prop,0) = Prop
  Succ(Prop,1) = Axiom(Prop) = Type_0
  ... *)
let mk_type i = Succ (Prop, i+1)


let add_prefix prefix name = Printf.sprintf "%s.%s" prefix name


let coq_var  x = Var (add_prefix (symb "system_module")   x)
let univ_var x = Var (add_prefix (symb "universe_module") x)

let coq_Sort () = coq_var (symb "Sort")

let coq_var_univ_name n = "s" ^ string_of_int n

let coq_univ_name s = String.concat "__" (String.split_on_char '.' s)

let coq_header () =
  [
    comment "This file was automatically generated by Coqine.";
    comment ("The encoding used was: \"" ^ (symb "encoding_name") ^ "\".");
    EmptyLine
  ]
let coq_footer = [ comment "End of translation." ]

module Std =
struct

  let coq_nat n = Utils.iterate n (app (coq_var "s")) (coq_var "z")

  let coq_prop ()    = coq_var "prop"
  let coq_set  ()    = coq_var "set"
  let coq_type i     = app (coq_var "type") (coq_nat i)

  let coq_proj i t   = app (app (coq_var "proj") (coq_nat i)) t

  let coq_axiom s    = app  (coq_var (symb "axiom")) s
  let coq_axioms s i = Utils.iterate i coq_axiom s
  let coq_rule s1 s2 = apps (coq_var (symb "rule")) [s1; s2]
  let rec coq_sup  = function
    | [] -> coq_prop ()
    | [u] -> u
    | (u :: u_list) -> apps (coq_var (symb "sup")) [u; coq_sup u_list]
  let rec cu = function
    | Succ (u   ,0) -> cu u
    | Succ (Succ(u,i), j) -> cu (Succ (u,i+j))
    | Prop          -> coq_prop ()
    | Set           -> coq_set ()
    | Succ (Set ,i) -> coq_type (i-1)
    | Succ (Prop,i) -> coq_type (i-1)
    | LocalNamed name -> var name
    | Local n       -> var ("s" ^ string_of_int n)
    | Template name -> var (coq_univ_name name)
    | Global name   -> univ_var (coq_univ_name name)
    | Succ (u,i)    -> coq_axioms (cu u) i
    | Max u_list    -> coq_sup (List.map cu u_list)
    | Rule (s1,s2)  -> coq_rule (cu s1) (cu s2)

  let rec cpu = function
    | Succ (u, 0)   -> cpu u
    | Succ (Succ(u,i), j) -> cpu (Succ (u,i+j))
    | Succ (u,i)    -> coq_axioms (cu u) i
    | Max u_list    -> coq_sup (List.map cpu u_list)
    | Rule (s1,s2)  -> coq_rule (cpu s1) (cpu s2)
    | u -> cu u
  let coq_pattern_universe u = cpu u

  let coq_U    s           = app  (coq_var (symb "Univ") ) (cu s)
  let coq_term s  a        = apps (coq_var (symb "Term") ) [cu s; a]

  let t_I () = coq_var (symb "I")
  let coq_sort cu s = apps (coq_var (symb "univ") )
      (if (flag "pred_univ")
       then [cu s; cu (Succ (s,1)); t_I()]
       else [cu s])
  let coq_prod cu s1 s2 a b   = apps (coq_var (symb "prod") )
      (if (flag "pred_prod")
       then [cu s1; cu s2; cu (Rule (s1,s2)); t_I(); a; b]
       else [cu s1; cu s2; a; b])
  let coq_cast cu s1 s2 a b t = apps (coq_var (symb "cast") )
      (if (flag "pred_cast")
       then [cu s1; cu s2; a; b; t_I(); t]
       else [cu s1; cu s2; a; b;        t])
  let coq_pcast cu s1 s2 a b t =
    if (flag "pred_cast")
    then apps (coq_var (symb "priv_cast")) [cu s1; cu s2; a; b;t]
    else coq_cast cu s1 s2 a b t
  let coq_lift cu s1 s2 t = apps (coq_var (symb "lift"))
      (if (flag "pred_lift")
       then [cu s1; cu s2; t_I(); t]
       else [cu s1; cu s2;        t])


  let cstr_le cu s1 s2 = apps (coq_var "Cumul") [cu s1            ; cu s2]
  let cstr_lt cu s1 s2 = apps (coq_var "Cumul") [coq_axiom (cu s1); cu s2]

end


(* ------------ Redefining all functions for readable translation ------- *)
module Short =
struct

  let nat_name u = "_n" ^ (string_of_int u)
  let nat_var  u = (var (nat_name u))

  let sort_name u = "_" ^ (string_of_int u)
  let sort_var  u = (var (sort_name u))

  let code_name u = "_u" ^ (string_of_int u)
  let code_var  u = (var (code_name u))

  let rec short_nat i =
    if i <= 9 then nat_var i else app (coq_var "s") (short_nat (i-1))

  let short_type i =
    if i <= 9 then sort_var i else app (coq_var "type") (short_nat i)

  let rec scu = function
    | Succ (u,0)    -> scu u
    | Succ (Succ(u,i), j) -> scu (Succ (u,i+j))
    | Succ (Set ,i) -> short_type (i-1)
    | Succ (Prop,i) -> short_type (i-1)
    | Succ (u,i)    -> Std.coq_axioms (scu u) i
    | Max u_list    -> Std.coq_sup (List.map scu u_list)
    | Rule (s1,s2)  -> Std.coq_rule (scu s1) (scu s2)
    | s -> Std.cu s

  let short_code i =
    if i <= 9 then code_var i else Std.coq_sort scu (Succ(Set,i+1))

  let short_U    s   = app  (coq_var (symb "Univ")) (scu s)
  let short_term s a = apps (coq_var (symb "Term")) [scu s; a]
  let rec short_sort = function
    | Succ (u   ,0) -> short_sort u
    | Succ (Succ(u,i), j) -> short_sort (Succ (u,i+j))
    | Max [] -> var "_prop"
    | Max [u] -> short_sort u
    | Succ (Set ,i) -> short_code (i-1)
    | Succ (Prop,i) -> short_code (i-1)
    | Set  -> var "_set"
    | Prop -> var "_prop"
    | u -> Std.coq_sort scu u

  let short_proj i t = app (app (coq_var "proj") (short_nat i)) t

  (* Redefining headers first then overriding previous definitions. *)
  let coq_header () =
    let res = ref [] in
    let add n t = res := (udefinition false n t) :: !res in
    add (nat_name 0) (coq_var "z");
    for i = 1 to 9 do add ( nat_name i) (app (coq_var "s"   ) (nat_var (i-1))) done;
    for i = 0 to 9 do add (sort_name i) (app (coq_var "type") (nat_var i    )) done;
    for i = 0 to 9 do add (code_name i) (Std.coq_sort scu (mk_type i)) done;
    add "_Set"  (Std.coq_U    Set );
    add "_Prop" (Std.coq_U    Prop);
    add "_set"  (Std.coq_sort scu Set );
    add "_prop" (Std.coq_sort scu Prop);
    coq_header () @
    (comment "------------  Short definitions  -----------") ::
    EmptyLine ::
    (List.rev !res) @
    EmptyLine ::
    (comment "--------  Begining of translation  ---------") ::
    EmptyLine :: []

end

module T =
struct

  let coq_Sort          = coq_Sort
  let coq_var_univ_name = coq_var_univ_name
  let coq_univ_name     = coq_univ_name
  let coq_global_univ   = univ_var

  let coq_pattern_universe = Std.coq_pattern_universe

  let a () = not (is_readable_on ())

  let coq_universe s = if a () then Std.cu       s else Short.scu        s
  let coq_U        s = if a () then Std.coq_U    s else Short.short_U    s
  let coq_term     s = if a () then Std.coq_term s else Short.short_term s
  let coq_sort     s = if a () then Std.coq_sort Std.cu s else Short.short_sort s

  let coq_prod     s = Std.coq_prod (if a () then Std.cu else Short.scu) s
  let coq_cast     s = Std.coq_cast (if a () then Std.cu else Short.scu) s
  let coq_pcast    s = Std.coq_pcast (if a () then Std.cu else Short.scu) s
  let coq_lift     s = Std.coq_lift (if a () then Std.cu else Short.scu) s
  let cstr_le      s = Std.cstr_le  (if a () then Std.cu else Short.scu) s
  let cstr_lt      s = Std.cstr_lt  (if a () then Std.cu else Short.scu) s

  let coq_pattern_lifted_from_sort s t =
    let univ s =
      if (flag "priv_univ_flag")
      then apps (coq_var (symb "priv_univ")) [var s; wildcard]
      else
        apps (coq_var (symb "univ"))
          (if (flag "pred_univ")
           then [var s; wildcard; wildcard]
           else [var s]) in
    match (symb "lifted_type_pattern") with
    | "lift" ->
      (if (flag "pred_lift")
         then apps (coq_var (symb "priv_lift")) [var s;wildcard;t]
         else apps (coq_var (symb "lift")     ) [var s;wildcard;t])
    | "cast" ->
      if (flag "priv_cast")
      then apps (coq_var (symb "priv_cast")) [wildcard;wildcard;univ s;wildcard;t]
      else
        let uwildcard =
          apps (coq_var (symb "univ")) (if (flag "pred_univ")
                                         then [wildcard]
                                         else [wildcard;wildcard;wildcard]) in
        apps (coq_var (symb "cast"))
          (if (flag "pred_cast")
           then [wildcard;wildcard;univ s;uwildcard;wildcard;t]
           else [wildcard;wildcard;univ s;uwildcard;t])
    | "uncodedcode" ->
      let c = coq_var (symb "priv_code") in
      let u = coq_var (symb "priv_uncode") in
      apps u [univ s;apps c [wildcard;t]]
    | s -> assert false

  let coq_proj     s = if a () then Std.coq_proj s else Short.short_proj s
  let coq_header   s = if a () then coq_header   s else Short.coq_header s
  let coq_footer  () = coq_footer

  let coq_fixpoint sort n arities bodies i =
    let coq_N n =
      assert (n >= 0);
      if n < 10 then coq_var (string_of_int n)
      else Utils.iterate n (app (coq_var (symb "S"))) (coq_var (symb "0")) in
    let coq_arity (k,a) =
      apps (coq_var (symb "SA")) [coq_N k; sort; a] in
    assert (Encoding.is_fixpoint_inlined ());
    assert (Array.length arities = n);
    assert (Array.length bodies = n);
    assert (i < n);
    let make_arities =
      ulam "c" (apps (var "c") (Array.to_list (Array.map coq_arity arities))) in
    let make_bodies =
      ulam "c" (apps (var "c") (Array.to_list bodies)) in
    apps
      (coq_var (symb "fix_oneline"))
      [ sort; coq_N n; make_arities; make_bodies; coq_N i]

  let coq_guarded consname args =
    let applied_cons = Utils.iterate args (fun x -> app x wildcard) (var consname) in
    let lhs = apps (coq_var (symb "guard")) [wildcard; wildcard; applied_cons] in
    let rhs = coq_var (symb "guarded") in
    rewrite ([],lhs,rhs)

end
