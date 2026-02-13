open Irky.Common_
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

let read_blocking sslfd fd buf off len =
  let rec try_read () =
    match Ssl.read sslfd buf off len with
    | n -> n
    | exception Ssl.Read_error Ssl.Error_want_read ->
      ignore (Unix.select [ fd ] [] [] (-1.) : _ * _ * _);
      try_read ()
  in
  try_read ()

let rec write_ sslfd fd buf off len =
  match Ssl.write sslfd buf off len with
  | n -> n
  | exception Ssl.Write_error Ssl.Error_want_write ->
    ignore (Unix.select [] [ fd ] [] (-1.) : _ * _ * _);
    write_ sslfd fd buf off len

let ic_of_fd (sslfd : Ssl.socket) (fd : Unix.file_descr) : Iostream.In.t =
  Unix.set_nonblock fd;
  let close () =
    try
      ignore (Ssl.close_notify sslfd : bool);
      Unix.close fd
    with _ -> ()
  in
  let input buf off len = read_blocking sslfd fd buf off len in
  Iostream.In.create ~close ~input ()

let oc_of_fd sslfd (fd : Unix.file_descr) : Iostream.Out.t =
  Unix.set_nonblock fd;
  object
    method close () = try Unix.close fd with _ -> ()

    method output buf off len =
      let rec loop off len =
        if len > 0 then (
          let n = write_ sslfd fd buf off len in
          loop (off + n) (len - n)
        )
      in
      loop off len
  end

let connect ~(config : Config.t) ~host ~port : Iostream.In.t * Iostream.Out.t =
  (* DNS resolution *)
  let addrs =
    try
      let entry = Unix.gethostbyname host in
      Array.to_list entry.Unix.h_addr_list
    with Not_found -> []
  in
  let addr =
    match addrs with
    | [] -> failwith (Printf.sprintf "Could not resolve %s" host)
    | addr :: _ -> addr
  in
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

let time = Irky_unix.io.time
let sleep = Irky_unix.io.sleep
let with_timeout = Irky_unix.io.with_timeout

let io ~config () : Irky.Io.t =
  { connect = connect ~config; sleep; time; with_timeout }
