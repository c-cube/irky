module Make(Io: Irc_transport.IO) = struct
  type auth_t = {
    username: string;
    password: string;
  }

  type connection_t = {
    sock: Io.file_descr;
  }

  let send_raw connection data =
    Io.write connection.sock (Printf.sprintf "%s\r\n" data)

  let send_join connection channel =
    send_raw connection (Printf.sprintf "JOIN %s" channel)

  let send_nick connection nick =
    send_raw connection (Printf.sprintf "NICK %s" nick)

  let send_pass connection password =
    send_raw connection (Printf.sprintf "PASS %s" password)

  let send_pong connection message =
    send_raw connection (Printf.sprintf "PONG %s" message)

  let send_privmsg connection target message =
    send_raw connection (Printf.sprintf "PRIVMSG %s %s" target message)
end
