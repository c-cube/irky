let input_of_flow ?(buf_size = 4096) flow : Iostream.In.t =
  let close () = () in
  (* Allocate a reusable buffer once *)
  let read_buf = Cstruct.create buf_size in
  let input buf off len =
    (* Read into our buffer *)
    let to_read = min len buf_size in
    let read_buf_slice = Cstruct.sub read_buf 0 to_read in
    let n = Eio.Flow.single_read flow read_buf_slice in
    (* Blit into the provided bytes *)
    Cstruct.blit_to_bytes read_buf_slice 0 buf off n;
    n
  in
  Iostream.In.create ~close ~input ()

let output_of_flow ?(buf_size = 4096) flow : Iostream.Out.t =
  (* Allocate a reusable buffer once *)
  let write_buf = Cstruct.create buf_size in
  object
    method close () = ()

    method output buf off len =
      (* For small writes, use our buffer to avoid allocating Cstruct *)
      if len <= buf_size then (
        Cstruct.blit_from_bytes buf off write_buf 0 len;
        let slice = Cstruct.sub write_buf 0 len in
        Eio.Flow.write flow [ slice ]
      ) else (
        (* For large writes, just wrap directly *)
        let cstruct = Cstruct.of_bytes ~off ~len buf in
        Eio.Flow.write flow [ cstruct ]
      )
  end
