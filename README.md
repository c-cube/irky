# Irky

A fork of [irc-client](https://github.com/johnelse/ocaml-irc-client) focused on
direct style IOs (unix and Eio).

[![Build status](https://github.com/c-cube/irky/actions/workflows/workflow.yml/badge.svg)](https://github.com/c-cube/irky/actions)

## License

MIT

## Usage

Simple bot which connects to a channel, sends a message, and then logs all
messages in that channel to stdout:

```ocaml
module C = Irky.Client

let host = ref "irc.libera.chat"
let port = ref 6667
let nick = ref "irkytest"
let channel = ref "##demo_irc"

let on_msg _client msg =
  Printf.printf "Got message: %s\n%!" (Irky.Message.to_string msg)

let() =
  let io = Irky_unix.io in
  C.reconnect_loop ~reconnect_delay:15. ~io
    ~connect:(fun () ->
      C.connect_by_name ~server:!host ~port:!port ~nick:!nick ~io ())
    ~on_connect:(fun client ->
      Printf.printf "Connected, sending join for %S\n%!" !channel;
      C.send_join client ~channel:!channel;
      C.send_privmsg client ~target:!channel ~message:"hello from irky!")
    on_msg
```

Compile the above with:

```
ocamlfind ocamlopt -package irky -package irky.unix -linkpkg code.ml
```

Alternatively, you can find an extended version of this example in `examples/example.ml`;
run it using `dune exec -- examples/example.exe`.
