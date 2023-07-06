module Config : sig
  type t = {
    check_certificate: bool;
    proto: Ssl.protocol;
  }

  val default : t
  val show : t -> string
end

val io : config:Config.t -> unit -> Irky.Io.t
