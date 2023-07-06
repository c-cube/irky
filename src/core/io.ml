(** Underlying IOs *)

type inet_addr = Unix.inet_addr

module In_channel = struct
  type t = {
    read: bytes -> int -> int -> int;
    read_with_timeout:
      float -> bytes -> int -> int -> (int, [ `timeout ]) result;
    close: unit -> unit;
  }
end

module Out_channel = struct
  type t = {
    write: bytes -> int -> int -> unit;
    flush: unit -> unit;
    close: unit -> unit;
  }

  let write_all (self : t) b : unit = self.write b 0 (Bytes.length b)

  let write_str (self : t) str : unit =
    write_all self (Bytes.unsafe_of_string str)
end

module Task = struct
  type 'a t = { join: unit -> 'a }
end

type t = {
  connect: inet_addr -> int -> In_channel.t * Out_channel.t;
  gethostbyname: string -> inet_addr list;
  spawn: 'a. (unit -> 'a) -> 'a Task.t;
  sleep: float -> unit;
  time: unit -> float;
}
