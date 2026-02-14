module Iostream_eio = Iostream_eio
module Iostream_ssl = Iostream_ssl
module Ssl_config = Iostream_ssl.Config

let io ~net ~clock ~sw : Irky.Io.t =
  let connect ~host ~port =
    let addr = Util_.resolve_addr ~net host in
    let socket = Eio.Net.connect ~sw net (`Tcp (addr, port)) in
    let ic = Iostream_eio.input_of_flow socket in
    let oc = Iostream_eio.output_of_flow socket in
    ic, oc
  in

  let sleep duration = Eio.Time.sleep clock duration in
  let time () = Eio.Time.now clock in

  let with_timeout duration f =
    match Eio.Time.with_timeout clock duration (fun () -> Ok (f ())) with
    | Ok x -> x
    | Error `Timeout -> raise Irky.Io.Timeout
  in

  { Irky.Io.connect; sleep; time; with_timeout }

let io_ssl = Iostream_ssl.io
