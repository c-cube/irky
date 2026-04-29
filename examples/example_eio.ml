module C = Irky.Client
module M = Irky.Message
module Log = (val Logs.src_log (Logs.Src.create "irky-example"))

let host = ref "irc.libera.chat"
let port = ref 6697 (* Standard IRC TLS port *)
let nick = ref "irkytest_eio"
let password = ref None
let debug = ref false
let channel = ref "##test123"
let check_cert = ref false
let ssl = ref true

let on_msg client msg =
  match msg with
  | { M.command = M.Other _; _ } as msg ->
    Log.app (fun k -> k "got unknown message: %s" (M.show msg))
  | { M.command = M.PRIVMSG (target, data); _ } as msg ->
    Log.app (fun k -> k "PRIVMSG: %s" (M.show msg));
    C.send_privmsg client ~target ~message:("ack: " ^ data)
  | msg ->
    Log.app (fun k -> k "got other message: %s" (M.show msg));
    flush stdout

let main () : unit =
  Eio_main.run @@ fun env ->
  let net = Eio.Stdenv.net env in
  let clock = Eio.Stdenv.clock env in

  Eio.Switch.run @@ fun sw ->
  let io =
    if !ssl then (
      let config = Irky_eio.Ssl_config.make ~check_certificate:!check_cert () in
      Irky_eio.io_ssl ~config ~net ~clock ~sw
    ) else
      Irky_eio.io ~net ~clock ~sw
  in

  let config =
    C.Config.make ~server:!host ~port:!port ~nick:!nick ?password:!password ()
  in
  C.reconnect_loop ~io ~reconnect_delay:60.0
    ~connect:(fun () -> C.connect ~config ~io ())
    ~on_connect:(fun client ->
      Log.info (fun k -> k "Connected");
      Log.app (fun k -> k "send join msg for `%s`" !channel);
      C.send_join client ~channel:!channel;
      C.send_privmsg client ~target:!channel ~message:"hello from irky-eio!")
    on_msg

let options =
  [
    "-h", Arg.Set_string host, " set remote server host name";
    "-p", Arg.Set_int port, " set remote server port";
    "-n", Arg.Set_string nick, " set nick";
    "--nick", Arg.Set_string nick, " set nick";
    ( "--password",
      Arg.String (fun s -> password := Some s),
      " set password (SASL)" );
    "--chan", Arg.Set_string channel, " channel to join";
    "-d", Arg.Set debug, " enable debug";
    "--ssl", Arg.Set ssl, " use ssl";
    "--no-ssl", Arg.Clear ssl, " do not use ssl";
    ( "--check-cert",
      Arg.Bool (( := ) check_cert),
      " do/do not check certificates" );
  ]
  |> Arg.align

let reporter () =
  let report _src level ~over k msgf =
    let k _ =
      over ();
      k ()
    in
    msgf @@ fun ?header ?tags:_ fmt ->
    let now = Unix.gettimeofday () in
    let tm = Unix.localtime now in
    let ppf =
      if level = Logs.App then
        Format.std_formatter
      else
        Format.err_formatter
    in
    Format.kfprintf k ppf
      ("[%02d:%02d:%02d] %a @[" ^^ fmt ^^ "@]@.")
      tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec Logs.pp_header
      (level, header)
  in
  { Logs.report }

let () =
  Arg.parse options ignore "example_eio [options]";
  Logs.set_level ~all:true
    (Some
       (if !debug then
          Logs.Debug
        else
          Logs.Info));
  Logs.set_reporter @@ reporter ();
  main ()
