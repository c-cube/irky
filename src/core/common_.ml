module Fmt = Format

let spf = Printf.sprintf

type 'a or_error = ('a, string) result
