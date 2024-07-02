import gleam/int
import gleam/io
import argv
import merkle/internal

pub fn main() {
  let args = argv.load().arguments 

  case args {
    ["accounts", count_str] -> {
      case int.parse(count_str) {
        Ok(count) -> {
          let accounts = internal.generate_random_accounts(count)
          internal.process_accounts(accounts)
        }
        Error(_) -> io.println("Error: Invalid number of accounts. Please provide a valid integer.")
      }
    }
    _ -> io.println("Usage: gleam run -- accounts <number_of_accounts>")
  }
}

