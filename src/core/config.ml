type t = {
  username: string option;
  mode: int;
  realname: string;
  password: string option; [@opaque]
  sasl: bool;
  server: string;
  port: int;
  nick: string;
}
(** Configuration for a client. *)

let make ?username ?(mode = 0) ?(realname = "irky") ?password ?(sasl = true)
    ~server ~port ~nick () : t =
  { username; mode; realname; password; sasl; server; port; nick }

let to_string (self : t) : string =
  let string_opt = function
    | None -> "None"
    | Some s -> Printf.sprintf "Some %S" s
  in
  Printf.sprintf
    "{ username = %s; mode = %d; realname = %S; password = <opaque>; sasl = \
     %b; server = %S; port = %d; nick = %S; }"
    (string_opt self.username) self.mode self.realname self.sasl self.server
    self.port self.nick

let pp out self = Format.pp_print_string out (to_string self)
