open Irky.Io

let read_with_timeout timeout fd buf i len : _ result =
  (* retry loop *)
  let rec try_read () =
    match Unix.read fd buf i len with
    | n -> Ok n
    | exception Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) ->
      block ()
  and block () =
    match Unix.select [ fd ] [] [] timeout with
    | [ _fd ], _, _ -> try_read ()
    | [], _, _ -> Error `timeout
    | _ -> assert false
  in
  try_read ()

let rec write_ fd buf i len =
  match Unix.write fd buf i len with
  | n -> n
  | exception Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) ->
    ignore (Unix.select [] [ fd ] [] (-1.) : _ * _ * _);
    write_ fd buf i len

let ic_of_fd (fd : Unix.file_descr) : In_channel.t =
  Unix.set_nonblock fd;
  let close () = try Unix.close fd with _ -> () in
  let read buf i len =
    match read_with_timeout (-1.) fd buf i len with
    | Ok n -> n
    | Error `timeout -> assert false
  in

  let read_with_timeout timeout buf i len =
    read_with_timeout timeout fd buf i len
  in
  { In_channel.close; read; read_with_timeout }

let oc_of_fd (fd : Unix.file_descr) : Out_channel.t =
  Unix.set_nonblock fd;
  let close () = try Unix.close fd with _ -> () in
  let rec write buf i len : unit =
    if len > 0 then (
      let n = write_ fd buf i len in
      write buf (i + n) (len - n)
    )
  in
  { Out_channel.close; write; flush = ignore }

let connect addr port : In_channel.t * Out_channel.t =
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  let sockaddr = Unix.ADDR_INET (addr, port) in
  Unix.connect sock sockaddr;
  ic_of_fd sock, oc_of_fd sock

let gethostbyname name =
  try
    let entry = Unix.gethostbyname name in
    Array.to_list entry.Unix.h_addr_list
  with Not_found -> []

let sleep = Thread.delay
let time = Unix.gettimeofday

let spawn f : _ Task.t =
  let q = Bqueue.create () in
  let _th =
    Thread.create
      (fun () ->
        let r =
          try Ok (f ())
          with e ->
            let bt = Printexc.get_raw_backtrace () in
            Error (e, bt)
        in
        Bqueue.push q r)
      ()
  in
  let join () =
    let r = Bqueue.pop q in
    Thread.join _th;
    match r with
    | Ok x -> x
    | Error (exn, bt) -> Printexc.raise_with_backtrace exn bt
  in
  { Task.join }

let io : t = { sleep; spawn; gethostbyname; connect; time }
