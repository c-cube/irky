(** Blocking Queue *)

type 'a t

val create : unit -> _ t

val push : 'a t -> 'a -> unit
(** [push q x] pushes [x] into [q], and returns [()]. *)

val pop : 'a t -> 'a
(** [pop q] pops the next element in [q]. It might block until an element comes.
*)
