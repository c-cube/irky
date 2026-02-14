(** IRC client library using Eio *)

module Iostream_eio = Iostream_eio
module Iostream_ssl = Iostream_ssl
module Ssl_config = Iostream_ssl.Config

val io :
  net:_ Eio.Net.t -> clock:_ Eio.Time.clock -> sw:Eio.Switch.t -> Irky.Io.t
(** Create an IO implementation using Eio.
    @param net Network interface for DNS and connections
    @param clock Clock for timing operations
    @param sw Switch for managing connection lifetimes *)

val io_ssl :
  config:Ssl_config.t ->
  net:Eio_unix.Net.t ->
  clock:_ Eio.Time.clock ->
  sw:Eio.Switch.t ->
  Irky.Io.t
