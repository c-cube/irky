let resolve_addr ~net (host : string) : Eio.Net.Ipaddr.v4v6 =
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
  addr
