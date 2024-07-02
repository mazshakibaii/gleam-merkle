import gleam/bit_array
import gleam/crypto.{Sha256, hash}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import prng/random
import prng/seed
import simplifile

pub type AccountData {
  AccountData(account_number: String, balance: Float)
}

pub type MerkleNode {
  MerkleNode(
    hash: BitArray,
    left: Option(MerkleNode),
    right: Option(MerkleNode),
  )
}

pub fn generate_random_accounts(count: Int) -> List(AccountData) {
  list.range(1, count)
  |> list.map(fn(i) {
    let account_number = "ACC" <> string.pad_left(int.to_string(i), 3, "0")
    let generator = random.float(0.0, 1000.0)
    let balance = random.sample(generator, seed.random())
    AccountData(account_number, balance)
  })
}

pub fn process_accounts(accounts: List(AccountData)) {
  let result = create_merkle_tree(accounts)

  case result {
    Ok(#(root, _)) -> {
      // (root, leaf_nodes) 
      let root_hash = bit_array.base16_encode(root.hash)
      io.println("Merkle Root: " <> root_hash)
      // io.println("\nLeaf Hashes:")
      // print_leaf_hashes(leaf_nodes)

      case save_merkle_tree(root, "merkle_tree.txt") {
        Ok(_) -> io.println("\nMerkle tree saved to merkle_tree.txt")
        Error(err) -> io.println("\nError saving Merkle tree: " <> err)
      }

      Nil
    }
    Error(msg) -> {
      io.println("Error: " <> msg)
      Nil
    }
  }
}

fn save_merkle_tree(root: MerkleNode, filename: String) -> Result(Nil, String) {
  let serialized = serialize_merkle_node(root, 0)
  simplifile.write(filename, serialized)
  |> result.map_error(fn(err) {
    "Failed to write file: " <> string.inspect(err)
  })
}

fn serialize_merkle_node(node: MerkleNode, depth: Int) -> String {
  let indent = string.repeat(" ", depth * 2)
  let hash = bit_array.base16_encode(node.hash)
  let current = indent <> "Hash: " <> hash <> "\n"

  case node.left, node.right {
    None, None -> current
    Some(left), Some(right) -> {
      current
      <> indent
      <> "Left:\n"
      <> serialize_merkle_node(left, depth + 1)
      <> indent
      <> "Right:\n"
      <> serialize_merkle_node(right, depth + 1)
    }
    _, _ -> current <> indent <> "Error: Inconsistent tree structure\n"
  }
}

// fn print_leaf_hashes(leaf_nodes: List(MerkleNode)) {
//   list.index_map(leaf_nodes, fn(node, index) {
//     let hash = bit_array.base16_encode(node.hash)
//     io.println("Leaf " <> int.to_string(index + 1) <> ": " <> hash)
//   })
// }

fn create_merkle_tree(
  accounts: List(AccountData),
) -> Result(#(MerkleNode, List(MerkleNode)), String) {
  case accounts {
    [] -> Error("Cannot create a Merkle tree from an empty list of accounts")
    _ -> {
      let sorted_accounts =
        list.sort(accounts, fn(a, b) {
          string.compare(a.account_number, b.account_number)
        })

      let leaf_nodes =
        list.map(sorted_accounts, fn(account) {
          let data =
            account.account_number <> ":" <> float.to_string(account.balance)
          let hash = hash(Sha256, bit_array.from_string(data))
          MerkleNode(hash, None, None)
        })

      case build_tree(leaf_nodes) {
        Ok(root) -> Ok(#(root, leaf_nodes))
        Error(msg) -> Error(msg)
      }
    }
  }
}

fn build_tree(nodes: List(MerkleNode)) -> Result(MerkleNode, String) {
  case nodes {
    [] -> Error("Cannot build a tree from an empty list of nodes")
    [single] -> Ok(single)
    _ -> {
      let paired_nodes = list.sized_chunk(nodes, 2)
      let new_level =
        list.try_map(paired_nodes, fn(pair) {
          case pair {
            [] -> Error("Unexpected empty pair")
            [single] -> {
              // Duplicate the last node if odd number of nodes
              let combined_hash = bit_array.append(single.hash, single.hash)
              let parent_hash = hash(Sha256, combined_hash)
              Ok(MerkleNode(parent_hash, Some(single), Some(single)))
            }
            [left, right] -> {
              let combined_hash = bit_array.append(left.hash, right.hash)
              let parent_hash = hash(Sha256, combined_hash)
              Ok(MerkleNode(parent_hash, Some(left), Some(right)))
            }
            _ -> Error("Unexpected number of nodes in pair")
          }
        })

      case new_level {
        Ok(level) -> build_tree(level)
        Error(msg) -> Error(msg)
      }
    }
  }
}
