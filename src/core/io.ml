(** Underlying IOs *)

type inet_addr = Unix.inet_addr

module In_channel = struct
  class type t =
    object
      method input : bytes -> int -> int -> int

      method input_with_timeout :
        float -> bytes -> int -> int -> (int, [ `timeout ]) result

      method close : unit -> unit
    end
end

module Out_channel = struct
  class type t =
    object
      method output : bytes -> int -> int -> unit
      method flush : unit -> unit
      method close : unit -> unit
    end

  let write_all (self : #t) b : unit = self#output b 0 (Bytes.length b)

  let write_str (self : #t) str : unit =
    write_all self (Bytes.unsafe_of_string str)
end

module Task = struct
  type 'a t = { join: unit -> 'a } [@@unboxed]
end

type t = {
  connect: inet_addr -> int -> In_channel.t * Out_channel.t;
  gethostbyname: string -> inet_addr list;
  spawn: 'a. (unit -> 'a) -> 'a Task.t;
  sleep: float -> unit;
  time: unit -> float;
}
