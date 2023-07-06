open OUnit2

let base_suite = "base_suite" >::: [ Test_utils.suite; Test_message.suite ]
let () = OUnit2.run_test_tt_main base_suite
