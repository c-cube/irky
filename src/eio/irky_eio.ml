let io ~net ~clock ~sw : Irky.Io.t =
  let connect ~host ~port =
    (* Resolve hostname *)
    let addrs = Eio.Net.getaddrinfo_stream net host in
    let addr =
      match
        List.find_map
          (function
            | `Tcp (addr, _) -> Some addr
            | _ -> None)
          addrs
      with
      | Some a -> a
      | None -> failwith (Printf.sprintf "Could not resolve %s" host)
    in
    
    (* Connect *)
    let socket = Eio.Net.connect ~sw net (`Tcp (addr, port)) in
    
    (* Wrap in iostream *)
    let ic = Iostream_eio.input_of_flow socket in
    let oc = Iostream_eio.output_of_flow socket in
    (ic, oc)
  in
  
  let sleep duration = Eio.Time.sleep clock duration in
  let time () = Eio.Time.now clock in
  
  let with_timeout duration f =
    match Eio.Time.with_timeout clock duration (fun () -> Ok (f ())) with
    | Ok x -> x
    | Error `Timeout -> raise Irky.Io.Timeout
  in
  
  { Irky.Io.connect; sleep; time; with_timeout }
