(** IO abstraction using iostream *)

type input = Iostream.In.t
type output = Iostream.Out.t

exception Timeout

type t = {
  connect: host:string -> port:int -> input * output;
  sleep: float -> unit;
  time: unit -> float;
  with_timeout: 'a. float -> (unit -> 'a) -> 'a;
      (** [with_timeout duration f] runs [f()] with a timeout.
          @raise Timeout if the timeout expires *)
}
