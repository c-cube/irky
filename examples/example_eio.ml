module C = Irky.Client
module M = Irky.Message
module Log = (val Logs.src_log (Logs.Src.create "irky-example"))

let host = ref "irc.libera.chat"
let port = ref 6667
let nick = ref "irkytest_eio"
let debug = ref false
let channel = ref "##demo_irc"

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
  let io = Irky_eio.io ~net ~clock ~sw in
  
  C.reconnect_loop ~io ~reconnect_delay:60.0
    ~connect:(fun () ->
      C.connect ~server:!host ~port:!port ~nick:!nick ~io ())
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
    "--chan", Arg.Set_string channel, " channel to join";
    "-d", Arg.Set debug, " enable debug";
  ]
  |> Arg.align

let () =
  Arg.parse options ignore "example_eio [options]";
  Logs.set_level ~all:true
    (Some
       (if !debug then
         Logs.Debug
       else
         Logs.Info));
  Logs.set_reporter @@ Logs.format_reporter ();
  main ()
