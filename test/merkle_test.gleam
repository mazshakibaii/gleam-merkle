import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  1
  |> should.equal(1)
}

// pub fn format_pair_test() {
//   internal.format_pair("hello", "world") |> should.equal("h1ello=world")
// }
