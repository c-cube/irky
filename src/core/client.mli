(** Main client module.

    See {!reconnect_loop} for the real entrypoint. *)

module Config = Config

type t
(** The client. Stateful. *)

val send : t -> Message.t -> unit
(** Send the given message *)

val send_join : t -> channel:string -> unit
(** Send the JOIN command. *)

val send_nick : t -> nick:string -> unit
(** Send the NICK command. *)

val send_pass : t -> password:string -> unit
(** Send the PASS command. *)

val send_ping : t -> message1:string -> message2:string -> unit
(** Send the PING command. *)

val send_pong : t -> message1:string -> message2:string -> unit
(** Send the PONG command. *)

val send_privmsg : t -> target:string -> message:string -> unit
(** Send the PRIVMSG command. *)

val send_notice : t -> target:string -> message:string -> unit
(** Send the NOTICE command. *)

val send_part : t -> channels:string list -> message:string -> unit

val send_quit : ?msg:string -> t -> unit -> unit
(** Send the QUIT command. *)

val send_user : t -> username:string -> mode:int -> realname:string -> unit
(** Send the USER command. *)

val connect_exn : config:Config.t -> io:Io.t -> unit -> t
(** Connect to an IRC server at hostname [host].
    @raise Failure if DNS resolution fails or connection fails.
    @param sasl
      if true, try to use SASL (plain) authentication with the server. This is
      an IRCv3 extension and might not be supported everywhere; it might also
      require a secure transport. *)

val connect : config:Config.t -> io:Io.t -> unit -> (t, string) result
(** Try to resolve the [server] name using DNS and connect to an IRC server.
    Returns [Error msg] if DNS resolution fails or connection fails. See
    {!connect_exn} for more details. *)

val listen : ?timeout:float -> t -> (t -> Message.t -> unit) -> unit
(** [listen connection f] listens for incoming messages on [connection]. All
    server pings are handled internally; all other messages are passed, along
    with [connection], to [callback].
    @param timeout
      number of seconds without receiving a "ping" from the server, before which
      we consider we're disconnected. *)

exception Exit_reconnect_loop

val reconnect_loop :
  ?timeout:float ->
  ?reconnect:bool ->
  reconnect_delay:float ->
  io:Io.t ->
  connect:(unit -> (t, string) result) ->
  on_connect:(t -> unit) ->
  (t -> Message.t -> unit) ->
  unit
(** The main entrypoint for a client that automatically reconnects.

    This function handles the complete lifecycle of an IRC connection: it
    connects to the server, runs your connection initialization code, listens
    for messages using your callback, and automatically reconnects if the
    connection is lost.

    {b Simple example:}
    {v
    let config = Config.make ~server:"irc.libera.chat" ~port:6667 ~nick:"mybot" () in
    C.reconnect_loop ~reconnect_delay:15. ~io
      ~connect:(fun () -> C.connect ~config ~io ())
      ~on_connect:(fun client ->
        C.send_join client ~channel:"##mychannel";
        C.send_privmsg client ~target:"##mychannel" ~message:"Hello!")
      (fun client msg ->
        match msg.Message.command with
        | Message.PRIVMSG (target, text) ->
            (* handle messages *)
            ()
        | _ -> ())
    v}

    The loop continues indefinitely until either [reconnect=false] is set, or
    the {!Exit_reconnect_loop} exception is raised from within the callback.

    @param timeout
      seconds without server ping before considering us disconnected
    @param reconnect
      if [false], stops after first disconnection (default: [true])
    @param reconnect_delay minimum seconds to wait before reconnecting
    @param connect
      a function that attempts to establish a new connection, typically a
      closure over {!connect} with your {!Config.t}
    @param on_connect
      called immediately after each successful connection, useful for joining
      channels, sending initial messages, etc.
    @param f
      callback invoked for every message received from the server; raising
      {!Exit_reconnect_loop} here will exit the loop *)

val shutdown : t -> unit
(** Shutdown client. It cannot be used again. *)
