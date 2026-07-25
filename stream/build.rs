fn main() {
    prost_build::compile_protos(&["proto/transactions.proto"], &["proto/"]).unwrap();
}
