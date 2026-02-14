open Irky.Common_
module Log = (val Logs.src_log (Logs.Src.create "irky.eio.ssl"))

module Config = struct
  type t = {
    check_certificate: bool;
    proto: Ssl.protocol;
  }

  let make ?(check_certificate = true) ?(proto = Ssl.TLSv1_3) () : t =
    { check_certificate; proto }

  let default : t = make ()

  let show self : string =
    spf "{check_certificate=%b; proto=_}" self.check_certificate
end

let io ~(config : Config.t) ~net ~clock ~sw : Irky.Io.t =
  let connect ~host ~port =
    let addr = Util_.resolve_addr ~net host in
    let socket = Eio.Net.connect ~sw net (`Tcp (addr, port)) in

    (* Set up SSL context *)
    let ssl_ctx = Ssl.create_context config.proto Ssl.Client_context in
    if config.check_certificate then (
      Ssl.set_verify_depth ssl_ctx 3;
      Ssl.set_verify ssl_ctx [ Ssl.Verify_peer ]
        (Some Ssl.client_verify_callback);
      Ssl.set_client_verify_callback_verbose true
    );

    (* Wrap in SSL via eio-ssl *)
    Log.debug (fun k -> k "SSL handshake with %s:%d" host port);
    let ctx = Eio_ssl.Context.create ~ctx:ssl_ctx socket in
    let ssl_socket = Eio_ssl.connect ctx in

    (* Wrap in iostream *)
    let ic = Irky_eio__Iostream_eio.input_of_flow ssl_socket in
    let oc = Irky_eio__Iostream_eio.output_of_flow ssl_socket in
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
