(** Client *)

type t

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

val connect :
  ?username:string ->
  ?mode:int ->
  ?realname:string ->
  ?password:string ->
  ?sasl:bool ->
  addr:Io.inet_addr ->
  port:int ->
  nick:string ->
  io:Io.t ->
  unit ->
  t
(** Connect to an IRC server at address [addr]. The PASS command will be
    sent if [password] is not None and if [sasl] is [false].
    @param sasl if true, try to use SASL (plain) authentication with the server.
      This is an IRCv3 extension and might not be supported everywhere; it
      might also require a secure transport (see {!Irc_client_lwt_ssl}
      or {!Irc_client_tls} for example). This param exists @since 0.7.
  *)

val connect_by_name :
  ?username:string ->
  ?mode:int ->
  ?realname:string ->
  ?password:string ->
  ?sasl:bool ->
  server:string ->
  port:int ->
  nick:string ->
  io:Io.t ->
  unit ->
  t option
(** Try to resolve the [server] name using DNS, otherwise behaves like
    {!connect}. Returns [None] if no IP could be found for the given
    name. See {!connect} for more details. *)

val listen : ?timeout:float -> t -> (t -> Message.t -> unit) -> unit
(** [listen connection f] listens for incoming messages on
      [connection]. All server pings are handled internally; all other
      messages are passed, along with [connection], to [callback].
      @param timeout number of seconds without receiving a "ping"
      from the server, before which we consider we're disconnected. *)

exception Exit_reconnect_loop

val reconnect_loop :
  ?timeout:float ->
  ?reconnect:bool ->
  reconnect_delay:float ->
  io:Io.t ->
  connect:(unit -> t option) ->
  on_connect:(t -> unit) ->
  (t -> Message.t -> unit) ->
  unit
(** A combination of {!connect} and {!listen} that, every time
    the connection is terminated, tries to start a new one
    after [after] seconds. It stops reconnecting if the exception
    [Exit_reconnect_loop] is raised.
    @param reconnect_delay time in seconds before trying to reconnect
    @param connect how to reconnect
      (a closure over {!connect} or {!connect_by_name})
    @param on_connect is passed every new connection
    @param f the callback for {!listen}, given every received message.
*)

val shutdown : t -> unit
(** Shutdown client. It cannot be used again. *)
