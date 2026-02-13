(** Iostream adapters for Eio *)

val input_of_flow : ?buf_size:int -> _ Eio.Flow.source -> Iostream.In.t
(** Wrap an Eio flow as an iostream input.
    @param buf_size Size of internal read buffer (default: 4096) *)

val output_of_flow : ?buf_size:int -> _ Eio.Flow.sink -> Iostream.Out.t
(** Wrap an Eio flow as an iostream output.
    @param buf_size
      Size of internal write buffer for small writes (default: 4096) *)
