(** SSL support for Irky using Eio and OpenSSL. Similar to {!Irky_unix_ssl} but
    for Eio. *)

module Config : sig
  type t = {
    check_certificate: bool;
    proto: Ssl.protocol;
  }

  val make : ?check_certificate:bool -> ?proto:Ssl.protocol -> unit -> t

  val default : t
  (** Default config: no certificate validation, TLS 1.3. *)

  val show : t -> string
end

val io :
  config:Config.t ->
  net:Eio_unix.Net.t ->
  clock:_ Eio.Time.clock ->
  sw:Eio.Switch.t ->
  Irky.Io.t
(** Create an IO implementation using Eio with SSL support.
    @param config SSL configuration (protocol, certificate checking)
    @param net Network interface for DNS and connections
    @param clock Clock for timing operations
    @param sw Switch for managing connection lifetimes *)
