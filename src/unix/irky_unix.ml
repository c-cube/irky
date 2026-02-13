let rec write_ fd buf i len =
  match Unix.write fd buf i len with
  | n -> n
  | exception Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) ->
    ignore (Unix.select [] [ fd ] [] (-1.) : _ * _ * _);
    write_ fd buf i len

let ic_of_fd (fd : Unix.file_descr) : Iostream.In.t =
  Unix.set_nonblock fd;
  let close () = try Unix.close fd with _ -> () in
  let input buf off len =
    try Unix.read fd buf off len
    with Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) ->
      ignore (Unix.select [ fd ] [] [] (-1.) : _ * _ * _);
      Unix.read fd buf off len
  in
  Iostream.In.create ~close ~input ()

let oc_of_fd (fd : Unix.file_descr) : Iostream.Out.t =
  Unix.set_nonblock fd;
  object
    method close () = try Unix.close fd with _ -> ()

    method output buf off len =
      let rec loop off len =
        if len > 0 then (
          let n = write_ fd buf off len in
          loop (off + n) (len - n)
        )
      in
      loop off len
  end

let connect ~host ~port : Iostream.In.t * Iostream.Out.t =
  (* DNS resolution *)
  let addrs =
    try
      let entry = Unix.gethostbyname host in
      Array.to_list entry.Unix.h_addr_list
    with Not_found -> []
  in
  match addrs with
  | [] -> failwith (Printf.sprintf "Could not resolve %s" host)
  | addr :: _ ->
    let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
    let sockaddr = Unix.ADDR_INET (addr, port) in
    Unix.connect sock sockaddr;
    ic_of_fd sock, oc_of_fd sock

let sleep = Thread.delay
let time = Unix.gettimeofday

let with_timeout duration f =
  let result = ref None in
  let timed_out = ref false in
  let mutex = Mutex.create () in
  let cond = Condition.create () in

  let worker =
    Thread.create
      (fun () ->
        let r = try f () with e -> raise e in
        Mutex.lock mutex;
        if not !timed_out then result := Some r;
        Condition.signal cond;
        Mutex.unlock mutex)
      ()
  in

  let timeout_thread =
    Thread.create
      (fun () ->
        Thread.delay duration;
        Mutex.lock mutex;
        timed_out := true;
        Condition.signal cond;
        Mutex.unlock mutex)
      ()
  in

  Mutex.lock mutex;
  while !result = None && not !timed_out do
    Condition.wait cond mutex
  done;
  let res = !result in
  Mutex.unlock mutex;

  (* Clean up threads - best effort *)
  (try Thread.join worker with _ -> ());
  (try Thread.join timeout_thread with _ -> ());

  match res with
  | Some r -> r
  | None -> raise Irky.Io.Timeout

let io : Irky.Io.t = { connect; sleep; time; with_timeout }
