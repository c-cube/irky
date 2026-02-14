(lang dune 3.0)
(generate_opam_files true)
(name irky)
(license MIT)

(authors "john else" "simon cruanes")
(maintainers "simon cruanes")

(package
  (name irky)
  (synopsis "The Irky IRC client library")
  (depends
    (ocaml (>= 5.0))
    (base64 (>= 3.5))
    iostream
    logs
    (ounit2 :with-test))
  (depopts
    ssl))

(package
  (name irky-eio)
  (synopsis "IRC client library using Eio")
  (depends
    (ocaml (>= 5.0))
    (eio (>= 0.12))
    (eio-ssl (>= 0.3))
    (eio_main :with-test)
    (irky (= :version))
    logs
    (base64 (>= 3.5))))
