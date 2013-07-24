(** Translation of Coq libraries *)

(* This makes this solution not portable.
   Change this to the magic number of the version you are using. *)
let vo_magic_number = ref 08400

let raw_intern_library =
  snd (System.raw_extern_intern !vo_magic_number ".vo")

type library_objects

type compilation_unit_name = Names.dir_path

type library_disk = {
  md_name : compilation_unit_name;
  md_compiled : Safe_typing.LightenLibrary.lightened_compiled_library;
  md_objects : library_objects;
  md_deps : (compilation_unit_name * Digest.t) list;
  md_imports : compilation_unit_name list }

let get_deps dir_path =
  let filename = Library.library_full_filename dir_path in
  let ch = raw_intern_library filename in
  let (md:library_disk) = System.marshal_in filename ch in
  close_in ch;
  fst (List.split md.md_deps)

let translate_dep out dep =
  Dedukti.print out (Dedukti.command "IMPORT" [Name.translate_dir_path dep])

let translate_library out dir_path =
  let deps = get_deps dir_path in
  let qualid = Libnames.qualid_of_dirpath dir_path in  
  let module_path = Nametab.locate_module qualid in
  let module_body = Global.lookup_module module_path in
  let env = Environment.init_env out dir_path in
  Dedukti.print out (Dedukti.comment "This file was automatically generated by Coqine.");
  Dedukti.print out (Dedukti.command "NAME" [Name.translate_dir_path dir_path]);
  Dedukti.print out (Dedukti.command "IMPORT" ["Coq"]);
  List.iter (translate_dep out) deps;
  Modules.translate_module_body env module_body;
  Dedukti.print out (Dedukti.comment "End of translation")

