open Common_

let bpf = Printf.bprintf

type command =
  | PASS of string
  | NICK of string
  | USER of string list  (** see rfc *)
  | OPER of string * string  (** name * password *)
  | MODE of string * string  (** nick * mode string *)
  | QUIT of string  (** quit message *)
  | SQUIT of string * string  (** server * comment *)
  | JOIN of string list * string list  (** channels * key list *)
  | JOIN0  (** join 0 (parts all channels) *)
  | PART of string list * string  (** channels * comment *)
  | TOPIC of string * string  (** chan * topic *)
  | NAMES of string list  (** channels *)
  | LIST of string list  (** channels *)
  | INVITE of string * string  (** nick * chan *)
  | KICK of string list * string * string  (** channels * nick * comment *)
  | PRIVMSG of string * string  (** target * message *)
  | NOTICE of string * string  (** target * message *)
  | PING of string * string
  | PONG of string * string
  | Other of string * string list  (** command name * parameters *)

type t = {
  prefix: string option;
  command: command;
}

let make_ cmd = { prefix = None; command = cmd }
let make_other_ cmd params = { prefix = None; command = Other (cmd, params) }

let unwrap_ or_ = function
  | None -> or_
  | Some s -> s

let pass s = make_ (PASS s)
let nick s = make_ (NICK s)

let user ~username ~mode ~realname =
  make_ (USER [ username; string_of_int mode; "*"; realname ])

let oper ~name ~pass = make_ (OPER (name, pass))
let mode ~nick ~mode = make_ (MODE (nick, mode))
let quit ~msg = make_ (QUIT msg)
let join ~chans ~keys = make_ (JOIN (chans, unwrap_ [] keys))
let join0 = make_ JOIN0
let part ~chans ~comment = make_ (PART (chans, unwrap_ "" comment))
let topic ~chan ~topic = make_ (TOPIC (chan, unwrap_ "" topic))
let names ~chans = make_ (NAMES chans)
let list ~chans = make_ (LIST chans)
let invite ~nick ~chan = make_ (INVITE (nick, chan))
let kick ~chans ~nick ~comment = make_ (KICK (chans, nick, unwrap_ "" comment))
let privmsg ~target msg = make_ (PRIVMSG (target, msg))
let notice ~target msg = make_ (NOTICE (target, msg))
let ping ~message1 ~message2 = make_ (PING (message1, message2))
let pong ~message1 ~message2 = make_ (PONG (message1, message2))
let other ~cmd ~params = make_other_ cmd params

type parse_result = t or_error

let extract_prefix str =
  if str <> "" && str.[0] = ':' then (
    let prefix_length = String.index str ' ' - 1 in
    assert (prefix_length >= 0);
    ( Some (String.sub str 1 prefix_length),
      String.sub str (prefix_length + 2)
        (String.length str - (prefix_length + 2)) )
  ) else
    None, str

let extract_trail str =
  try
    let trail_start = String.index str ':' + 1 in
    let trail_length = String.length str - trail_start in
    let rest =
      if trail_start > 2 then
        String.sub str 0 (trail_start - 2)
      else
        ""
    in
    rest, Some (String.sub str trail_start trail_length)
  with Not_found -> str, None

exception ParseError of string * string

let split_spaces str = String.split_on_char ' ' str
let split_comma str = String.split_on_char ',' str
let split_space1 str = Utils.split1_exn ~str ~c:' '

(** split parameters into tokens separated by spaces. If a trail, prefixed
   by ':', exists, it is the last token *)
let split_params params =
  let s, trail = extract_trail params in
  let tokens =
    split_spaces s |> List.map String.trim |> List.filter (fun s -> s <> "")
  in
  match trail with
  | None -> tokens
  | Some trail -> tokens @ [ trail ]

let fail_ msg err = raise (ParseError (msg, err))

(** expect exactly one word *)
let expect1 msg = function
  | [ x ] -> x
  | _ -> fail_ msg "expected one parameter"

and expect2 msg = function
  | [ x; y ] -> x, y
  | _ -> fail_ msg "expected two parameters"

and expect1or2 msg = function
  | [ x ] -> x, ""
  | [ x; y ] -> x, y
  | _ -> fail_ msg "expected one or two parameters"

and expect2or3 msg = function
  | [ x; y ] -> x, y, ""
  | [ x; y; z ] -> x, y, z
  | _ -> fail_ msg "expected one or two parameters"

let parse_exn msg =
  if String.length msg = 0 then
    fail_ msg "Zero-length message"
  else (
    let prefix, rest = extract_prefix msg in
    let command_name, params = split_space1 rest in
    let params = split_params params in
    let command =
      match command_name with
      | "PASS" -> PASS (expect1 msg params)
      | "NICK" -> NICK (expect1 msg params)
      | "USER" -> USER (split_spaces (expect1 msg params))
      | "OPER" ->
        let name, pass = expect2 msg params in
        OPER (name, pass)
      | "MODE" ->
        let nick, mode = expect2 msg params in
        MODE (nick, mode)
      | "QUIT" -> QUIT (expect1 msg params)
      | "JOIN" ->
        (match params with
        | [ "0" ] -> JOIN0
        | [ chans ] -> JOIN (split_comma chans, [])
        | [ chans; keys ] -> JOIN (split_comma chans, split_comma keys)
        | _ -> fail_ msg "expected one or two parameters to JOIN")
      | "PART" ->
        let chans, msg = expect1or2 msg params in
        PART (split_comma chans, msg)
      | "TOPIC" ->
        let chan, topic = expect1or2 msg params in
        TOPIC (chan, topic)
      | "NAMES" -> NAMES (split_comma (expect1 msg params))
      | "LIST" -> LIST (split_params (expect1 msg params))
      | "INVITE" ->
        let nick, chan = expect2 msg params in
        INVITE (nick, chan)
      | "KICK" ->
        let chans, nick, c = expect2or3 msg params in
        KICK (split_comma chans, nick, c)
      | "PRIVMSG" ->
        let target, msg = expect2 msg params in
        PRIVMSG (target, msg)
      | "NOTICE" ->
        let target, msg = expect2 msg params in
        NOTICE (target, msg)
      | "PING" ->
        let middle, trailer = expect1or2 msg params in
        PING (middle, trailer)
      | "PONG" ->
        let middle, trailer = expect1or2 msg params in
        PONG (middle, trailer)
      | other -> Other (other, params)
    in
    { prefix; command }
  )

let parse s =
  try Result.Ok (parse_exn s) with
  | ParseError (m, e) ->
    Result.Error (spf "failed to parse \"%s\" because: %s" m e)
  | e ->
    Result.Error
      (spf "unexpected error trying to parse \"%s\": %s" s
         (Printexc.to_string e))

(* write [s] into [buf], possibly as a ':'-prefixed trail *)
let write_trail buf s =
  if String.contains s ' ' || (String.length s > 0 && s.[0] = ':') then
    Buffer.add_char buf ':';
  Buffer.add_string buf s

(* output list to buffer *)
let write_list ?(trail = false) sep buf l =
  let rec iter = function
    | [] -> ()
    | [ s ] when trail -> write_trail buf s
    | [ s ] -> Buffer.add_string buf s
    | s :: (_ :: _ as tail) ->
      Buffer.add_string buf s;
      Buffer.add_char buf sep;
      iter tail
  in
  iter l

let write_cmd_buf (buf : Buffer.t) (self : command) : unit =
  match self with
  | PASS s -> bpf buf "PASS %s" s
  | NICK s -> bpf buf "NICK %s" s
  | USER s -> bpf buf "USER %a" (write_list ~trail:true ' ') s
  | OPER (a, b) -> bpf buf "OPER %s %s" a b
  | MODE (a, b) -> bpf buf "MODE %s %s" a b
  | QUIT s -> bpf buf "QUIT %a" write_trail s
  | SQUIT (a, b) -> bpf buf "SQUIT %s %a" a write_trail b
  | JOIN (a, b) -> bpf buf "JOIN %a %a" (write_list ',') a (write_list ',') b
  | JOIN0 -> bpf buf "JOIN 0"
  | PART (a, b) -> bpf buf "PART %a :%s" (write_list ',') a b
  | TOPIC (a, b) -> bpf buf "TOPIC %s %a" a write_trail b
  | NAMES l -> bpf buf "NAMES %a" (write_list ',') l
  | LIST l -> bpf buf "LIST %a" (write_list ',') l
  | INVITE (a, b) -> bpf buf "INVITE %s %s" a b
  | KICK (l, nick, c) ->
    bpf buf "KICK %a %s %a" (write_list ',') l nick write_trail c
  | PRIVMSG (a, b) -> bpf buf "PRIVMSG %s %a" a write_trail b
  | NOTICE (a, b) -> bpf buf "NOTICE %s %a" a write_trail b
  | PING (a, b) -> bpf buf "PING %s %a" a write_trail b
  | PONG (a, b) -> bpf buf "PONG %s %a" a write_trail b
  | Other (command_name, params) ->
    Printf.bprintf buf "%s %a" command_name (write_list ~trail:true ' ') params

let write_buf buf (self : t) : unit =
  (match self.prefix with
  | None -> ()
  | Some s -> Printf.bprintf buf ":%s " s);
  write_cmd_buf buf self.command;
  ()

let output ?(buf = Buffer.create 64) oc t =
  Buffer.clear buf;
  write_buf buf t;
  Buffer.output_buffer oc buf

let to_string ?(buf = Buffer.create 64) t =
  Buffer.clear buf;
  write_buf buf t;
  Buffer.contents buf

let show (self : t) : string =
  let buf = Buffer.create 64 in
  let pre buf =
    match self.prefix with
    | None -> bpf buf "None"
    | Some p -> bpf buf "Some %S" p
  in
  bpf buf "{prefix=%t, cmd=%a}" pre write_cmd_buf self.command;
  Buffer.contents buf
