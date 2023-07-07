(** An enriched representation of privmsg *)

type t = {
  nick: string;  (** author *)
  target: string;  (** target *)
  message: string;
}

val show : t -> string

val nick : t -> string
(** Author *)

val reply_to : t -> string
(** Whom to reply to? *)

val of_msg : Message.t -> t option

val of_msg_exn : Message.t -> t
(** @raise Failure if it's not a privmsg *)
