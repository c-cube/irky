module C = Irky.Client
module M = Irky.Message
module Log = (val Logs.src_log (Logs.Src.create "irky-example"))

let host = ref "irc.libera.chat"
let port = ref 6667
let nick = ref "irkytest"
let debug = ref false
let channel = ref "##demo_irc"

let on_msg client result =
  match result with
  | { M.command = M.Other _; _ } as msg ->
    Log.app (fun k -> k "got unknown message: %s" (M.show msg))
  | { M.command = M.PRIVMSG (target, data); _ } as msg ->
    Log.app (fun k -> k "PRIVMSG: %s" (M.show msg));
    C.send_privmsg client ~target ~message:("ack: " ^ data)
  | msg ->
    Log.app (fun k -> k "got other message: %s" (M.show msg));
    flush stdout

let io = Irky_unix.io

let main () : unit =
  C.reconnect_loop ~reconnect_delay:15. ~io
    ~connect:(fun () ->
      C.connect_by_name ~server:!host ~port:!port ~nick:!nick ~io ())
    ~on_connect:(fun client ->
      Log.info (fun k -> k "Connected");
      Log.app (fun k -> k "send join msg for `%s`" !channel);
      C.send_join client ~channel:!channel;
      C.send_privmsg client ~target:!channel ~message:"hello from irky!")
    on_msg

let options =
  Arg.align
    [
      "-h", Arg.Set_string host, " set remove server host name";
      "-p", Arg.Set_int port, " set remote server port";
      "--chan", Arg.Set_string channel, " channel to join";
      "-d", Arg.Set debug, " enable debug";
    ]

let () =
  Arg.parse options ignore "example [options]";
  Logs.set_level ~all:true
    (Some
       (if !debug then
         Logs.Debug
       else
         Logs.Info));
  Logs.set_reporter @@ Logs.format_reporter ();
  main ()
