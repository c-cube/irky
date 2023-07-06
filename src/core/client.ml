open Common_
open Io
module Log = Utils.Log
module M = Message

type t = {
  io: Io.t;
  ic: In_channel.t;
  oc: Out_channel.t;
  buffer: Buffer.t;
  read_length: int;
  read_data: Bytes.t; (* for reading *)
  lines: string Queue.t; (* lines read so far *)
  active: bool Atomic.t; (* mutable bg: unit Io.Task.t; *)
}

let[@inline] terminated self : bool = not (Atomic.get self.active)

let shutdown self =
  if Atomic.exchange self.active false then (
    Log.info (fun k -> k "shutdown IRC client");
    (* FIXME: wait for bg thread to finish *)
    (* self.bg.join (); *)
    self.ic.close ();
    self.oc.close ()
  )

let send_raw (self : t) ~data =
  Log.debug (fun k -> k "send: %s" data);
  let data = spf "%s\r\n" data in
  Io.Out_channel.write_str self.oc data

let send (self : t) msg = send_raw (self : t) ~data:(M.to_string msg)

let send_join (self : t) ~channel =
  send (self : t) (M.join ~chans:[ channel ] ~keys:None)

let send_nick (self : t) ~nick = send (self : t) (M.nick nick)

let send_auth_sasl (self : t) ~user ~password =
  Log.debug (fun k -> k "login using SASL with user=%S" user);
  send_raw (self : t) ~data:"CAP REQ :sasl";
  send_raw (self : t) ~data:"AUTHENTICATE PLAIN";
  let b64_login =
    Base64.encode_string @@ spf "%s\x00%s\x00%s" user user password
  in
  let data = spf "AUTHENTICATE %s" b64_login in
  send_raw (self : t) ~data

let send_pass (self : t) ~password = send (self : t) (M.pass password)

let send_ping (self : t) ~message1 ~message2 =
  send (self : t) (M.ping ~message1 ~message2)

let send_pong (self : t) ~message1 ~message2 =
  send (self : t) (M.pong ~message1 ~message2)

let send_privmsg (self : t) ~target ~message =
  send (self : t) (M.privmsg ~target message)

let send_notice (self : t) ~target ~message =
  send (self : t) (M.notice ~target message)

let send_quit ?(msg = "") (self : t) () = send (self : t) (M.quit ~msg)

let send_user (self : t) ~username ~mode ~realname =
  let msg = M.user ~username ~mode ~realname in
  send (self : t) msg

let make_ io ic oc : t =
  let read_length = 1024 in
  {
    io;
    ic;
    oc;
    buffer = Buffer.create 128;
    read_length;
    read_data = Bytes.make read_length ' ';
    lines = Queue.create ();
    active = Atomic.make true;
  }

type 'a input_res =
  | Read of 'a
  | Timeout
  | End

let rec next_line_ ~timeout (self : t) : string input_res =
  if terminated self then
    End
  else if Queue.length self.lines > 0 then
    Read (Queue.pop self.lines)
  else (
    (* Read some data into our string. *)
    match
      self.ic.read_with_timeout timeout self.read_data 0 self.read_length
    with
    | Error `timeout -> Timeout
    | Ok 0 ->
      (* EOF from server - we have quit or been kicked. *)
      shutdown self;
      End
    | Ok len ->
      (* read some data, push lines into [c.lines] (if any) *)
      let input = Bytes.sub_string self.read_data 0 len in
      let lines = Utils.handle_input ~buffer:self.buffer ~input in
      List.iter (fun l -> Queue.push l self.lines) lines;
      next_line_ ~timeout self
  )

type nick_retry = {
  mutable nick: string;
  mutable tries: int;
}

let welcome_timeout = 30.
let max_nick_retries = 3

let wait_for_welcome ~start (self : t) ~nick =
  let nick_try = { nick; tries = 1 } in
  let rec loop () =
    let now = self.io.time () in
    let timeout = start +. welcome_timeout -. now in
    if timeout < 0.1 then
      ()
    else if nick_try.tries > max_nick_retries then
      ()
    else (
      (* wait a bit more *)
      assert (timeout > 0.);
      (* logf "wait for welcome message (%ds)" timeout >>= fun () -> *)
      match next_line_ ~timeout self with
      | Timeout | End -> ()
      | Read line ->
        Log.debug (fun k -> k "read: %s" line);
        (match M.parse line with
        | Result.Ok { M.command = M.Other ("001", _); _ } ->
          (* we received "RPL_WELCOME", i.e. 001 *)
          ()
        | Result.Ok { M.command = M.PING (message1, message2); _ } ->
          (* server may ask for ping at any time *)
          send_pong (self : t) ~message1 ~message2;
          loop ()
        | Result.Ok { M.command = M.Other ("433", _); _ } ->
          (* we received "ERR_NICKNAMEINUSE" *)
          nick_try.nick <- nick_try.nick ^ "_";
          nick_try.tries <- nick_try.tries + 1;
          Log.err (fun k ->
              k "Nick name already in use, trying %s" nick_try.nick);
          send_nick (self : t) ~nick:nick_try.nick;
          loop ()
        | _ -> loop ())
    )
  in
  loop ();
  Log.info (fun k -> k "finished waiting for welcome msg")

let connect ?username ?(mode = 0) ?(realname = "irc-client") ?password
    ?(sasl = true) ~addr ~port ~nick ~(io : Io.t) () =
  let ic, oc = io.connect addr port in
  let self = make_ io ic oc in

  let cap_end = ref false in
  (match username, password with
  | Some user, Some password when sasl ->
    cap_end := true;
    send_auth_sasl self ~user ~password
  | _, Some password -> send_pass self ~password
  | _ -> ());
  let username =
    match username with
    | Some u -> u
    | None -> "ocaml-irc-client"
  in
  send_nick self ~nick;
  send_user self ~username ~mode ~realname;
  if !cap_end then send_raw self ~data:"CAP END";
  wait_for_welcome ~start:(io.time ()) self ~nick;
  self

let connect_by_name ?(username = "irc-client") ?(mode = 0)
    ?(realname = "irc-client") ?password ?sasl ~server ~port ~nick ~io () =
  match io.gethostbyname server with
  | [] -> None
  | addr :: _ ->
    let conn =
      connect ~addr ~port ~username ~mode ~realname ~nick ?password ?sasl ~io ()
    in
    Some conn

let default_timeout = 80.

let listen ?timeout:(server_timeout = default_timeout) (self : t) f : unit =
  let last_seen = ref @@ self.io.time () in
  while not (terminated self) do
    let now = self.io.time () in
    let read_timeout = max 0. (!last_seen +. server_timeout -. now) in
    match next_line_ ~timeout:read_timeout self with
    | Timeout ->
      Log.info (fun k -> k "client timeout");
      shutdown self
    | End ->
      Log.info (fun k -> k "connection closed");
      shutdown self
    | Read line ->
      (* update "last_seen" field *)
      Log.debug (fun k -> k "read: %s" line);
      let now = self.io.time () in
      last_seen := max now !last_seen;
      (match M.parse line with
      | Ok { M.command = M.PING (message1, message2); _ } ->
        (* Handle pings without calling the callback. *)
        Log.debug (fun k -> k "reply pong to server");
        send_pong self ~message1 ~message2
      | Ok { M.command = M.PONG _; _ } -> () (* active response from server *)
      | Ok msg -> f self msg
      | Error err -> Log.err (fun k -> k "invalid message received: %s" err))
  done

exception Exit_reconnect_loop

let reconnect_loop ?timeout ?(reconnect = true) ~reconnect_delay ~io ~connect
    ~on_connect f : unit =
  let reconnect_delay = max reconnect_delay 2. in
  let continue = ref true in
  while !continue do
    (try
       match connect () with
       | None ->
         Log.info (fun k -> k "could not connect");
         if not reconnect then continue := false
       | Some connection ->
         on_connect connection;
         listen ?timeout connection f;
         Log.info (fun k -> k "connection terminated.");
         if not reconnect then continue := false
     with
    | Exit_reconnect_loop ->
      Log.info (fun k -> k "exiting reconnection loop");
      continue := false
    | exn ->
      Log.err (fun k ->
          k "reconnect_loop: exception %s" (Printexc.to_string exn)));

    if !continue then (
      io.sleep reconnect_delay;
      Log.info (fun k -> k "try to reconnect...")
    )
  done
