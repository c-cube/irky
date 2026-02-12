(** IRC client library using Eio *)

val io :
  net:_ Eio.Net.t ->
  clock:_ Eio.Time.clock ->
  sw:Eio.Switch.t ->
  Irky.Io.t
(** Create an IO implementation using Eio.
    @param net Network interface for DNS and connections
    @param clock Clock for timing operations
    @param sw Switch for managing connection lifetimes *)
