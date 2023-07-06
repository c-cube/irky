open Irky.Common_
open Irky.Io
module Log = (val Logs.src_log (Logs.Src.create "irky.unix.ssl"))

module Config = struct
  type t = {
    check_certificate: bool;
    proto: Ssl.protocol;
  }

  let default = { check_certificate = false; proto = Ssl.TLSv1_3 }

  let show self : string =
    spf "{check_certificate=%b; proto=_}" self.check_certificate
end

let read_with_timeout timeout sslfd fd buf i len : _ result =
  (* retry loop *)
  let rec try_read () =
    match Ssl.read sslfd buf i len with
    | n -> Ok n
    | exception Ssl.Read_error Ssl.Error_want_read -> block ()
  and block () =
    match Unix.select [ fd ] [] [] timeout with
    | [ _fd ], _, _ -> try_read ()
    | [], _, _ -> Error `timeout
    | _ -> assert false
  in
  try_read ()

let rec write_ sslfd fd buf i len =
  match Ssl.write sslfd buf i len with
  | n -> n
  | exception Ssl.Write_error Ssl.Error_want_write ->
    ignore (Unix.select [] [ fd ] [] (-1.) : _ * _ * _);
    write_ sslfd fd buf i len

let ic_of_fd (sslfd : Ssl.socket) (fd : Unix.file_descr) : In_channel.t =
  Unix.set_nonblock fd;
  let close () =
    try
      ignore (Ssl.close_notify sslfd : bool);
      Unix.close fd
    with _ -> ()
  in
  let read buf i len =
    match read_with_timeout (-1.) sslfd fd buf i len with
    | Ok n -> n
    | Error `timeout -> assert false
  in

  let read_with_timeout timeout buf i len =
    read_with_timeout timeout sslfd fd buf i len
  in
  { In_channel.close; read; read_with_timeout }

let oc_of_fd sslfd (fd : Unix.file_descr) : Out_channel.t =
  Unix.set_nonblock fd;
  let close () = try Unix.close fd with _ -> () in
  let rec write buf i len : unit =
    if len > 0 then (
      let n = write_ sslfd fd buf i len in
      write buf (i + n) (len - n)
    )
  in
  { Out_channel.close; write; flush = ignore }

let connect ~(config : Config.t) addr port : In_channel.t * Out_channel.t =
  let ssl = Ssl.create_context config.proto Ssl.Client_context in
  if config.check_certificate then (
    (* from https://github.com/johnelse/ocaml-irc-client/pull/21 *)
    Ssl.set_verify_depth ssl 3;
    Ssl.set_verify ssl [ Ssl.Verify_peer ] (Some Ssl.client_verify_callback);
    Ssl.set_client_verify_callback_verbose true
  );
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  let sockaddr = Unix.ADDR_INET (addr, port) in
  Log.debug (fun k -> k "Unix.connect socket…");
  Unix.connect sock sockaddr;
  Log.debug (fun k -> k "Ssl.connect socket…");
  let sslsock = Ssl.embed_socket sock ssl in
  Ssl.connect sslsock;
  ic_of_fd sslsock sock, oc_of_fd sslsock sock

let gethostbyname = Irky_unix.io.gethostbyname
let time = Irky_unix.io.time
let spawn = Irky_unix.io.spawn
let sleep = Irky_unix.io.sleep

let io ~config () : t =
  { sleep; spawn; gethostbyname; connect = connect ~config; time }
