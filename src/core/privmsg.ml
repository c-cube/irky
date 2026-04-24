type t = {
  nick: string; (* author *)
  target: string; (* target *)
  message: string;
}

let show msg =
  Printf.sprintf "{nick:%S; target:%S; msg: %S}" msg.nick msg.target msg.message

let is_chan s =
  (not (String.equal s ""))
  && Char.equal s.[0] '#'
  && not (String.contains s ' ')

let nick msg = msg.nick

let reply_to msg =
  if is_chan msg.target then
    (* reply on same channel *)
    msg.target
  else
    (* in private *)
    msg.nick

let get_nick str = Utils.split1_exn ~c:'!' ~str |> fst

let of_msg (msg : Message.t) =
  match msg.command with
  | PRIVMSG (target, message) ->
    (match msg.prefix with
    | None -> None
    | Some prefix -> Some { nick = get_nick prefix; target; message })
  | _ -> None

let of_msg_exn msg =
  match of_msg msg with
  | Some m -> m
  | None -> failwith "not a privmsg"
