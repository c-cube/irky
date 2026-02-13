(lang dune 2.0)
(generate_opam_files true)
(name irky)
(license MIT)

(authors "john else" "simon cruanes")
(maintainers "simon cruanes")

(package
  (name irky)
  (synopsis "The Irky IRC client library")
  (depends
    (ocaml (>= 4.12))
    (base64 (>= 3.5))
    logs
    fuseau
    (ounit2 :with-test))
  (depopts
    ssl))
